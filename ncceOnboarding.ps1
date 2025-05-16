<#
.SYNOPSIS
    NCCE Prerequisites Setup - Creates a service principal with custom roles for Azure management.
.DESCRIPTION
    Dieses Skript legt alle benötigten Azure AD Applications, Service Principals und Custom Roles
    an oder verwendet bereits vorhandene Ressourcen.
.NOTES
    Version:        1.6
    Author:         Timo Haldi
    Creation Date:  May 7, 2025
    Last Updated:   May 14, 2025
#>

function Write-ColorOutput {
    param(
        [Parameter(Mandatory=$true)][AllowEmptyString()][string]$Message,
        [Parameter()][string]$ForegroundColor = "White"
    )
    $orig = $host.UI.RawUI.ForegroundColor
    $host.UI.RawUI.ForegroundColor = $ForegroundColor
    Write-Output $Message
    $host.UI.RawUI.ForegroundColor = $orig
}

function Show-Banner {
    Clear-Host
    $banner = @"
╔══════════════════════════════════════════════════════════════╗
║                                                              ║
║                    NCCE PREREQUISITES SETUP                  ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
"@
    Write-ColorOutput $banner "Cyan"
    Write-ColorOutput ""
}

function Show-Progress {
    param([string]$Step, [int]$Current, [int]$Total)
    $pct = [math]::Floor(($Current/$Total)*100)
    $width = 10
    $filled = [math]::Floor($pct/(100/$width))
    $empty = $width - $filled
    $bar = "[" + ("■"* $filled) + (" "* $empty) + "]"
    Write-ColorOutput "$bar $pct% - $Step" "Yellow"
}

function Write-Success   { param($m) Write-ColorOutput "✓ $m" "Green" }
function Write-Warning   { param($m) Write-ColorOutput "⚠️ $m" "Yellow" }
function Write-Error     { param($m) Write-ColorOutput "! $m" "Red" }
function Write-Separator { Write-ColorOutput "─────────────────────────────────────────────────────────────────" "Gray" }

function EnsureModule {
    param([string]$ModuleName)
    try {
        if (-not (Get-Module -Name $ModuleName -ListAvailable)) {
            Write-ColorOutput "$ModuleName module not found. Installing..." "Magenta"
            Install-Module -Name $ModuleName -Force -Scope CurrentUser -AllowClobber
            Write-Success "$ModuleName installed"
        } else {
            Write-Success "$ModuleName already present"
        }
        return $true
    } catch {
        Write-Error "Failed to install ${ModuleName}: $($_.Exception.Message)"
        return $false
    }
}

# === Main ===
Show-Banner
Write-ColorOutput "Starting Azure Service Principal setup..." "Green"
Write-Separator

EnsureModule -ModuleName "Az.Accounts"
EnsureModule -ModuleName "Az.Resources"

# Step 1: Login
Show-Progress "Logging in to Azure" 1 9
Write-ColorOutput "Please authenticate via device code..." "Magenta"
$ctx = Get-AzContext -ErrorAction SilentlyContinue
if (-not $ctx) {
    Connect-AzAccount -UseDeviceAuthentication
    $ctx = Get-AzContext
    if (-not $ctx) { Write-Error "Authentication failed"; exit 1 }
}
$tenant = $ctx.Tenant.Id
$subId  = $ctx.Subscription.Id
Write-Success "Logged in to tenant: $tenant"

# Common domain lookup
$domain = (Get-AzTenant -TenantId $tenant).Domains[0]

# === SP1: sp-ncce-global-provisioner ===
# Step 2: Application
Show-Progress "Ensure App sp-ncce-global-provisioner" 2 9
$appName = "sp-ncce-global-provisioner"
$app = Get-AzADApplication -DisplayName $appName -ErrorAction SilentlyContinue
if ($app) {
    Write-Success "Found existing App: $appName (AppId: $($app.AppId))"
} else {
    Write-ColorOutput "Creating App: $appName" "Magenta"
    $app = New-AzADApplication -DisplayName $appName `
                               -IdentifierUris "https://$domain/$appName" `
                               -SignInAudience AzureADMyOrg
    Write-Success "App created (AppId: $($app.AppId))"
}
Start-Sleep 5

# Step 3: Service Principal
Show-Progress "Ensure SP for sp-ncce-global-provisioner" 3 9
$sp = Get-AzADServicePrincipal -ApplicationId $app.AppId -ErrorAction SilentlyContinue
if ($sp) {
    Write-Success "Found existing SP (ObjectId: $($sp.Id))"
} else {
    Write-ColorOutput "Creating Service Principal for AppId $($app.AppId)" "Magenta"
    $sp = New-AzADServicePrincipal -ApplicationId $app.AppId
    Write-Success "SP created (ObjectId: $($sp.Id))"
}
Start-Sleep 5

# Step 4: Credential
Show-Progress "Ensure credential for SP1" 4 9
$creds = Get-AzADAppCredential -ApplicationId $app.AppId -ErrorAction SilentlyContinue
if ($creds -and $creds.Count -gt 0) {
    Write-Success "Existing credential(s) found; skipping creation"
    $plainPassword = $null
} else {
    Write-ColorOutput "Creating new secret via Az PowerShell..." "Magenta"
    $endDate = (Get-Date).AddYears(1)
    $pwdCred = New-AzADAppCredential -ApplicationId $app.AppId -EndDate $endDate
    $plainPassword = $pwdCred.SecretText
    Write-Success "Secret created"
    Write-Warning "SP1 Secret: $plainPassword"
}


# === SP2: sp-ncce-token-rotator (no roles) ===
# Step 5: Application
Show-Progress "Ensure App sp-ncce-token-rotator" 5 9
$trAppName = "sp-ncce-token-rotator"
$trApp = Get-AzADApplication -DisplayName $trAppName -ErrorAction SilentlyContinue
if ($trApp) {
    Write-Success "Found existing App: $trAppName (AppId: $($trApp.AppId))"
} else {
    Write-ColorOutput "Creating App: $trAppName" "Magenta"
    $trApp = New-AzADApplication -DisplayName $trAppName `
                                 -IdentifierUris "https://$domain/$trAppName" `
                                 -SignInAudience AzureADMyOrg
    Write-Success "App created (AppId: $($trApp.AppId))"
}
Start-Sleep 5

# Step 6: Service Principal
Show-Progress "Ensure SP for sp-ncce-token-rotator" 6 9
$trSp = Get-AzADServicePrincipal -ApplicationId $trApp.AppId -ErrorAction SilentlyContinue
if ($trSp) {
    Write-Success "Found existing SP (ObjectId: $($trSp.Id))"
} else {
    Write-ColorOutput "Creating Service Principal for AppId $($trApp.AppId)" "Magenta"
    $trSp = New-AzADServicePrincipal -ApplicationId $trApp.AppId
    Write-Success "SP created (ObjectId: $($trSp.Id))"
}
Start-Sleep 5

# Step 7: Credential
Show-Progress "Ensure credential for Token Rotator" 7 9
$trCreds = Get-AzADAppCredential -ApplicationId $trApp.AppId -ErrorAction SilentlyContinue
if ($trCreds -and $trCreds.Count -gt 0) {
    Write-Success "Existing token-rotator credential(s) found; skipping creation"
    $trPassword = $null
} else {
    Write-ColorOutput "Creating token-rotator secret via Az PowerShell..." "Magenta"
    $endDate = (Get-Date).AddYears(1)
    $trPwdCred = New-AzADAppCredential -ApplicationId $trApp.AppId -EndDate $endDate
    $trPassword = $trPwdCred.SecretText
    Write-Success "Token-Rotator secret created"
    Write-Warning "Token-Rotator Secret: $trPassword"
}

# === SP1 Role Assignments & Custom Roles ===
# Step 8: Owner at Subscription
Show-Progress "Ensure Owner role on subscription for SP1" 8 9
$assign = Get-AzRoleAssignment -ObjectId $sp.Id `
    -Scope "/subscriptions/$subId" `
    -RoleDefinitionName "Owner" -ErrorAction SilentlyContinue
if ($assign) {
    Write-Success "SP1 already has Owner role on subscription"
} else {
    Write-ColorOutput "Assigning Owner role to SP1..." "Magenta"
    New-AzRoleAssignment -ObjectId $sp.Id -RoleDefinitionName "Owner" -Scope "/subscriptions/$subId" | Out-Null
    Write-Success "Owner role assigned to SP1"
}

# Step 9: Custom Roles at ManagementGroup
Show-Progress "Ensure custom role cr-subscription-provisioner" 9 9
$roleName = "cr-subscription-provisioner"
$existingRole = Get-AzRoleDefinition -Name $roleName -ErrorAction SilentlyContinue
if ($existingRole) {
    Write-Success "Custom role $roleName already exists"
} else {
    Write-ColorOutput "Creating custom role $roleName..." "Magenta"
    $json = @"
{
  "Name": "$roleName",
  "Description": "Custom role used in the Subscription Orchestrator for resource provisioning.",
  "Actions": [
    "Microsoft.Authorization/*/read",
    "Microsoft.Authorization/roleAssignments/write",
    "Microsoft.Authorization/roleAssignments/read",
    "Microsoft.Authorization/roleAssignments/delete",
    "Microsoft.Authorization/roleDefinitions/write",
    "Microsoft.Authorization/roleDefinitions/read",
    "Microsoft.Authorization/roleDefinitions/delete",
    "Microsoft.Storage/storageAccounts/*",
    "Microsoft.Storage/storageAccounts/blobServices/containers/*",
    "Microsoft.Storage/storageAccounts/blobServices/generateUserDelegationKey/action",
    "Microsoft.Resources/subscriptions/resourceGroups/*",
    "Microsoft.Resources/deployments/*",
    "Microsoft.Resources/tags/*"
  ],
  "AssignableScopes": [
    "/providers/Microsoft.Management/managementGroups/$tenant"
  ]
}
"@
    $tmp = [IO.Path]::GetTempFileName() + ".json"
    $json | Out-File -FilePath $tmp -Encoding utf8
    New-AzRoleDefinition -InputFile $tmp | Out-Null
    Remove-Item $tmp -ErrorAction SilentlyContinue
    Write-Success "Created custom role $roleName"
}

Write-Separator
Write-ColorOutput "✅ Service Principal setup complete!" "Green"
Write-ColorOutput "App Name: $appName" "Cyan"
Write-ColorOutput "Service Principal Object ID: $($sp.Id)" "Cyan"
Write-ColorOutput "Service Principal Client ID: $($app.AppId)" "Cyan"
Write-ColorOutput "Service Principal Client Secret: $plainPassword" "Red"
Write-ColorOutput " "
Write-ColorOutput "App Name: $trAppName" "Cyan"
Write-ColorOutput "Token Rotator Object ID: $($trSp.Id)" "Cyan"
Write-ColorOutput "Token Rotator Client ID: $($trApp.AppId)" "Cyan"
Write-ColorOutput "Token Rotator Client Secret: $trPassword" "Red"
Write-ColorOutput " "
Write-ColorOutput "📋 Important: Copy and save the passwords displayed above in a secure location." "Yellow"
Write-ColorOutput "The passwords will not be shown again!" "Red"
Write-ColorOutput "Setup completed at $(Get-Date)" "Green"
