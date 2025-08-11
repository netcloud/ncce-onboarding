<# 
  Initialize-NCCE.ps1 – NCCE PREREQUISITES SETUP (final)
  - Clean outputs (Client IDs & Secret)
  - FIC step skips with warning when UAMI missing
  - Fixed step summary padding
  - Identifier URI + redirect fix for token-rotator
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string]$CompanyCode,
    [string]$UamiClientId      = '',
    [string]$UamiPrincipalId   = '',
    [string]$UamiResourceId    = ''
)

$ErrorActionPreference = 'Stop'

# Hard-coded target subscription name
$TargetSubscriptionName = "sub-$CompanyCode-ncce-plf-p"

# --------------------------- Banner ---------------------------
function Show-Banner {
    $banner = @"
╔══════════════════════════════════════════════════════════════╗
║                                                              ║
║                    NCCE PREREQUISITES SETUP                  ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
"@
    Write-Host $banner -ForegroundColor Cyan
    Write-Host "`t`t`tRelease: Wandering Crimson Kraken 🐙`n" -ForegroundColor Magenta
}

# ------------- Artefacts collected during run -------------
# (Single canonical object; do NOT redefine elsewhere.)
$global:Artefacts = [pscustomobject]@{
    ProvisionerClientId      = $null
    ProvisionerClientSecret  = $null
    TokenRotatorClientId     = $null
}

# --------------------------- Globals ---------------------------
$global:stepResults    = @()
$global:contexts       = $null
$global:tenantId       = $null
$global:domain         = $null
$global:app1Name       = $null
$global:app1           = $null
$global:sp1            = $null
$global:plainPassword1 = $null
$global:app2Name       = 'sp-ncce-token-rotator'
$global:app2           = $null
$global:sp2            = $null

# --------------------------- Helper Pin Az/Graph Context ---------------------------
function Use-AzureTenantSub {
    param([string]$TenantId,[string]$SubscriptionId)
    Connect-AzAccount -Tenant $TenantId -UseDeviceAuthentication -ErrorAction Stop | Out-Null
    if ($SubscriptionId) {
        Select-AzSubscription -SubscriptionId $SubscriptionId -TenantId $TenantId -ErrorAction Stop | Out-Null
    }
}
function Use-GraphTenant { param([string]$TenantId) Connect-MgGraph -TenantId $TenantId -NoWelcome -ErrorAction Stop | Out-Null }

function TaskSelectTargetSubscription {
    Write-Host "`t📌 [Task] Switch Az context to '$TargetSubscriptionName'…" -ForegroundColor Magenta

    $sub = Get-AzSubscription -SubscriptionName $TargetSubscriptionName -ErrorAction SilentlyContinue
    if (-not $sub) {
        throw "Subscription '$TargetSubscriptionName' not found or not accessible for this account."
    }

    Select-AzSubscription -SubscriptionId $sub.Id -TenantId $sub.TenantId -ErrorAction Stop | Out-Null
    Write-Host "`t`t→ Context set to SubscriptionId $($sub.Id)`n" -ForegroundColor Green
    $global:stepResults += @{ Name = "Select Subscription"; Info = $sub.Id }
}

function Get-MgApplicationEventually {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$ObjectId,  # Graph objectId (GUID)
        [Parameter(Mandatory)][string]$AppId,     # ClientId
        [int]$TimeoutSeconds = 90
    )

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    $attempt  = 0
    do {
        $attempt++
        try {
            # First try by ObjectId (fast path)
            $app = Get-MgApplication -ApplicationId $ObjectId -ErrorAction Stop
            if ($app) { return $app }
        } catch {
            # Fall through to filter approach
        }

        try {
            # Fallback: filter by appId (some tenants surface this earlier)
            $app = Get-MgApplication -Filter "appId eq '$AppId'"
            if ($app) { return $app }
        } catch {
            # ignore; we'll retry
        }

        $sleep = [Math]::Min(2 * $attempt, 8)  # 2,4,6,8…
        Write-Host ("`t`t→ Graph not consistent yet (try {0}) – waiting {1}s…" -f $attempt,$sleep) -ForegroundColor Yellow
        Start-Sleep -Seconds $sleep
    } while ((Get-Date) -lt $deadline)

    throw "Application not visible in Microsoft Graph after $TimeoutSeconds seconds (objectId=$ObjectId, appId=$AppId)."
}


# --------------------------- Credential Summary Output ---------------------------
function Write-CredentialSummary {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][pscustomobject]$Data,
        [string]$Path = "$PSScriptRoot/NCCE_Credentials.json"
    )

    $line = ('═' * 65)
    Write-Host "`n$line" -ForegroundColor Cyan
    Write-Host "   NCCE – Service-Principal Credentials" -ForegroundColor White
    Write-Host $line -ForegroundColor Cyan

    $props = $Data.PSObject.Properties | Where-Object { $_.Value -ne $null -and $_.Value -ne '' }
    $pad   = ($props | ForEach-Object { $_.Name.Length } | Measure-Object -Maximum).Maximum
    foreach ($p in $props) {
        "{0} : {1}" -f $p.Name.PadRight($pad), $p.Value | Write-Host -ForegroundColor Green
    }

    Write-Host $line -ForegroundColor Cyan
    $Data | ConvertTo-Json -Depth 3 | Set-Content -Path $Path -Encoding utf8
    Write-Host "   → JSON copy written to $Path`n" -ForegroundColor Yellow
}

# --------------------------- Create or Reuse UAMI ---------------------------
function TaskCreateOrUseUami {
    Write-Host "`t⚙️ [Task] Ensure UAMI '$UamiName' in '$UamiResourceGroup'…" -ForegroundColor Magenta

    $subId = (Get-AzContext).Subscription.Id
    if (-not $subId) { throw "No Azure context – run TaskInitAuth first." }

    # RG
    $rg = Get-AzResourceGroup -Name $UamiResourceGroup -ErrorAction SilentlyContinue
    if (-not $rg) {
        $rg = New-AzResourceGroup -Name $UamiResourceGroup -Location $UamiLocation
        Write-Host "`t`t→ Created RG $UamiResourceGroup" -ForegroundColor Green
    }

    # UAMI
    $uami = Get-AzUserAssignedIdentity -ResourceGroupName $UamiResourceGroup -Name $UamiName -ErrorAction SilentlyContinue
    if (-not $uami) {
        $uami = New-AzUserAssignedIdentity -ResourceGroupName $UamiResourceGroup -Name $UamiName -Location $rg.Location
        Write-Host "`t`t→ Created UAMI" -ForegroundColor Green
    } else {
        Write-Host "`t`t→ Reusing existing UAMI" -ForegroundColor Green
    }

    $script:UamiClientId    = $uami.ClientId
    $script:UamiPrincipalId = $uami.PrincipalId
    $script:UamiResourceId  = $uami.Id

    $global:stepResults += @{ Name = "Create/Use UAMI"; Info = "clientId=$($uami.ClientId)" }
}

# --------------------------- Environment Setup ---------------------------
function SetupEnvironment {
    Write-Host "`t🔧 [Env] Preparing PowerShell module environment..." -ForegroundColor Magenta
    Import-Module "$PSScriptRoot/Modules/ModuleVenvHelper.psm1" -Force -ErrorAction Stop
    Enable-ModuleVenv

    Write-Host "`t✅ [Env] Module environment ready.`n" -ForegroundColor Green
    $global:stepResults += @{ Name = "Setup Environment"; Info = "Module environment ready" }
}

# --------------------------- Authentication ---------------------------
function TaskInitAuth {
    Write-Host "`t🔑 [Task] Authenticating to Azure + Microsoft Graph..." -ForegroundColor Magenta

    Import-Module "$PSScriptRoot/Modules/AuthHelper.psm1" -Force -ErrorAction Stop
    Write-Host "`t⏻ Disconnecting existing Azure and Graph sessions..." -ForegroundColor Green
    try { Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null } catch {}
    try { Disconnect-AzAccount -ErrorAction SilentlyContinue | Out-Null } catch {}

    # Interactive login (Azure + Graph) with required scopes
    $global:contexts = Initialize-AuthContexts

    $global:tenantId = $contexts.Azure.Tenant.Id
    $global:domain   = (Get-AzTenant -TenantId $tenantId).Domains[0]

    Write-Host "`n`t📄 [Summary] Authentication Details:" -ForegroundColor Cyan
    Write-Host "`t`t• Azure Tenant ID   : $($contexts.Azure.Tenant.Id)" -ForegroundColor Green
    Write-Host "`t`t• Azure Tenant Name : $($contexts.Azure.Tenant.Name)" -ForegroundColor Green
    Write-Host "`t`t• Graph User        : $($contexts.Graph.Account)`n" -ForegroundColor Green

    $info = "Tenant: $($contexts.Azure.Tenant.Name); Graph User: $($contexts.Graph.Account)"
    $global:stepResults += @{ Name = "Authenticate"; Info = $info }
}

# --------------------------- SP1: sp-ncce-global-provisioner ---------------------------
function TaskSP1CreateApp {
    Write-Host "`t⚙️ [Task] SP1 – Ensure App 'sp-ncce-global-provisioner' exists..." -ForegroundColor Magenta

    Import-Module "$PSScriptRoot/Modules/AzureSpHelper.psm1" -Force -ErrorAction Stop -DisableNameChecking

    $global:app1Name = "sp-ncce-global-provisioner"
    $global:app1 = Get-OrCreate-AzApp -DisplayName $app1Name -IdentifierUriBase "https://$domain"

    $info = "AppName: $app1Name; Service Principal Client ID: $($app1.AppId)"
    Write-Host "`t`t→ $info`n" -ForegroundColor Green
    $global:stepResults += @{ Name = "SP1: Create App"; Info = $info }

    $global:Artefacts.ProvisionerClientId = $global:app1.AppId
}

function TaskSP1CreateSP {
    Write-Host "`t⚙️ [Task] SP1 – Ensure Service Principal exists for App1..." -ForegroundColor Magenta

    Import-Module "$PSScriptRoot/Modules/AzureSpHelper.psm1" -Force -ErrorAction Stop -DisableNameChecking

    $global:sp1 = Get-OrCreate-AzServicePrincipal -AppId $global:app1.AppId

    $info = "AppName: $app1Name; ObjectId: $($sp1.Id)"
    Write-Host "`t`t→ $info`n" -ForegroundColor Green
    $global:stepResults += @{ Name = "SP1: Create Service Principal"; Info = $info }
}

function TaskSP1CreateCredential {
    Write-Host "`t⚙️ [Task] SP1 – Ensure client secret exists for App1..." -ForegroundColor Magenta

    Import-Module "$PSScriptRoot/Modules/AzureSpHelper.psm1" -Force -ErrorAction Stop -DisableNameChecking

    $credInfo1 = Get-OrCreate-AzAppCredential -AppId $global:app1.AppId
    $global:plainPassword1 = $credInfo1.SecretText

    if ($plainPassword1) {
        $info = "AppName: $app1Name; New secret: $plainPassword1"
        Write-Host "`t`t→ $info`n" -ForegroundColor Red
    } else {
        $info = "AppName: $app1Name; Existing secret reused"
        Write-Host "`t`t→ $info`n" -ForegroundColor Green
    }

    $global:stepResults += @{ Name = "SP1: Create Credential"; Info = $info }

    $global:Artefacts.ProvisionerClientSecret = $global:plainPassword1
}

# --------------------------- SP2: sp-ncce-token-rotator ---------------------------
function TaskSP2CreateApp {
    Write-Host "`t⚙️ [Task] SP2 – Ensure multi-tenant app '$app2Name'…" -ForegroundColor Magenta
    Import-Module "$PSScriptRoot/Modules/AzureSpHelper.psm1" -Force -DisableNameChecking

    # Create the multi-tenant app WITHOUT IdentifierUris; api:// must equal the final AppId
    $global:app2 = Get-OrCreate-AzApp `
                     -DisplayName $global:app2Name `
                     -Audience    'AzureADMultipleOrgs'

    # Switch Graph to the right tenant
    Use-GraphTenant -TenantId $global:tenantId

    # Wait for Graph consistency, then set identifier URI = api://{appId}
    $mgApp = Get-MgApplicationEventually -ObjectId $global:app2.Id -AppId $global:app2.AppId
    $desiredIdUri = "api://$($global:app2.AppId)"

    if (-not ($mgApp.IdentifierUris -contains $desiredIdUri)) {
        Update-MgApplication -ApplicationId $mgApp.Id -IdentifierUris @($desiredIdUri) | Out-Null
        Write-Host "`t`t→ Identifier URI set to $desiredIdUri" -ForegroundColor Green
    } else {
        Write-Host "`t`t→ Identifier URI already $desiredIdUri" -ForegroundColor Green
    }

    $info = "App multi-tenant; clientId=$($mgApp.AppId)"
    Write-Host "`t`t→ $info`n" -ForegroundColor Green
    $global:stepResults += @{ Name = "SP2: Create/Update App"; Info = $info }

    $global:Artefacts.TokenRotatorClientId = $global:app2.AppId
}


function TaskSP2CreateSP {
    Write-Host "`t⚙️ [Task] SP2 – Ensure Service Principal exists for App2..." -ForegroundColor Magenta

    Import-Module "$PSScriptRoot/Modules/AzureSpHelper.psm1" -Force -ErrorAction Stop -DisableNameChecking

    $global:sp2 = Get-OrCreate-AzServicePrincipal -AppId $global:app2.AppId

    $info = "AppName: $app2Name; Token Rotator Object ID: $($sp2.Id)"
    Write-Host "`t`t→ $info`n" -ForegroundColor Green
    $global:stepResults += @{ Name = "SP2: Create Service Principal"; Info = $info }
}

function TaskSP2AddFic {
    Write-Host "`t🔗 [Task] SP2 – Ensure FIC for UAMI…" -ForegroundColor Magenta

    # If UAMI wasn’t supplied, warn + skip
    if (-not $script:UamiPrincipalId) {
        Write-Warning "UAMI not configured – skipping FIC creation for Token-Rotator."
        $global:stepResults += @{ Name = "SP2: Add FIC"; Info = "Skipped (no UAMI)" }
        return
    }

    # Make sure we’re on the right tenant and the app is visible in Graph
    Use-GraphTenant -TenantId $global:tenantId
    $null = Get-MgApplicationEventually -ObjectId $global:app2.Id -AppId $global:app2.AppId

    $issuer  = "https://login.microsoftonline.com/$($global:tenantId)/v2.0"
    $subject = $script:UamiPrincipalId
    $ficName = "uami-fic"

    # Check if an identical FIC already exists
    $existing = Get-MgApplicationFederatedIdentityCredential `
                  -ApplicationId $global:app2.Id `
                  -ErrorAction SilentlyContinue |
                Where-Object {
                    $_.Name -eq $ficName -and $_.Issuer -eq $issuer -and $_.Subject -eq $subject
                }

    if ($existing) {
        Write-Host "`t`t→ FIC already exists" -ForegroundColor Green
        $global:stepResults += @{ Name = "SP2: Add FIC"; Info = "issuer=$issuer; name=$ficName (exists)" }
        return
    }

    try {
        New-MgApplicationFederatedIdentityCredential `
            -ApplicationId $global:app2.Id `
            -BodyParameter @{
                name      = $ficName
                issuer    = $issuer
                subject   = $subject
                audiences = @('api://AzureADTokenExchange')
            } `
            -ErrorAction Stop | Out-Null

        Write-Host "`t`t→ FIC created" -ForegroundColor Green
        $global:stepResults += @{ Name = "SP2: Add FIC"; Info = "issuer=$issuer; name=$ficName (created)" }
    }
    catch {
        $status = $_.Exception.Response.StatusCode.Value__ 2>$null
        if ($status -eq 409 -or $_.Exception.Message -match 'already exists') {
            Write-Host "`t`t→ FIC already exists (409 conflict)" -ForegroundColor Yellow
            $global:stepResults += @{ Name = "SP2: Add FIC"; Info = "issuer=$issuer; name=$ficName (exists)" }
        } else {
            throw
        }
    }
}


# --------------------------- SP1: Graph Permissions ---------------------------
function TaskSP1GraphPermission {
    Write-Host "`t🔐 [Task] SP1 – Grant Directory.ReadWrite.All via Graph..." -ForegroundColor Yellow

    Import-Module "$PSScriptRoot/Modules/GraphPermissionHelper.psm1" -Force -ErrorAction Stop -DisableNameChecking

    Add-GraphAppPermission `
        -AppObjectId     $global:app1.Id `
        -GraphAppId      '00000003-0000-0000-c000-000000000000' `
        -PermissionValue 'Directory.ReadWrite.All'

    $info = "AppName: $app1Name; Permission Directory.ReadWrite.All granted"
    Write-Host "`t`t→ $info`n" -ForegroundColor Green

    $global:stepResults += @{ Name = "SP1: Grant Graph Permission"; Info = $info }
}

# --------------------------- SP1: RBAC – Owner ---------------------------
function TaskSP1RBACOwner {
    Write-Host "`t🔒 [Task] SP1 – Assign 'Owner' role at subscription scope..." -ForegroundColor Magenta

    Import-Module "$PSScriptRoot/Modules/AzureRbacHelper.psm1" -Force -ErrorAction Stop -DisableNameChecking

    $subId = $global:contexts.Azure.Subscription.Id

    Add-AzRoleAssignment `
        -ObjectId           $global:sp1.Id `
        -RoleDefinitionName "Owner" `
        -Scope              "/subscriptions/$subId"

    $info = "AppName: $app1Name; Owner role on subscription $subId"
    Write-Host "`t`t→ $info`n" -ForegroundColor Green
    $global:stepResults += @{ Name = "SP1: Assign RBAC Owner"; Info = $info }
}

# --------------------------- SP1: RBAC – Custom Role 1 ---------------------------
function TaskSP1RBACCustomRole1 {
    Write-Host "`t🎨 [Task] SP1 – Ensure custom role 'cr-subscription-provisioner' and assign it..." -ForegroundColor Magenta

    Import-Module "$PSScriptRoot/Modules/AzureRbacHelper.psm1" -Force -ErrorAction Stop -DisableNameChecking

    $roleName1 = "cr-subscription-provisioner"
    $mgScope   = "/providers/Microsoft.Management/managementGroups/$($global:tenantId)"

    $json1 = @"
{
  "Name": "$roleName1",
  "Description": "Custom role for subscription provisioning",
  "Actions": [
    "Microsoft.Authorization/*/read",
    "Microsoft.Authorization/roleAssignments/write",
    "Microsoft.Authorization/roleAssignments/read",
    "Microsoft.Authorization/roleAssignments/delete",
    "Microsoft.Authorization/roleDefinitions/write",
    "Microsoft.Authorization/roleDefinitions/read",
    "Microsoft.Authorization/roleDefinitions/delete",
    "Microsoft.Storage/storageAccounts/*",
    "Microsoft.Resources/subscriptions/resourceGroups/*",
    "Microsoft.Resources/deployments/*",
    "Microsoft.Resources/tags/*",
    "Microsoft.Network/networkSecurityGroups/*",
    "Microsoft.Network/virtualNetworks/*",
    "Microsoft.Network/networkInterfaces/*",
    "Microsoft.Network/publicIPAddresses/*",
    "Microsoft.Network/register/action",
    "Microsoft.Network/virtualNetworks/subnets/*",
    "Microsoft.Compute/register/action",
    "Microsoft.Compute/virtualMachineScaleSets/*",
    "Microsoft.Compute/virtualMachines/*",
    "Microsoft.Compute/availabilitySets/*",
    "Microsoft.Compute/disks/*",
    "Microsoft.Compute/images/*",
    "Microsoft.ManagedIdentity/userAssignedIdentities/*",
    "Microsoft.Insights/metricDefinitions/read",
    "Microsoft.Insights/diagnosticSettings/*",
    "Microsoft.KeyVault/vaults/*",
    "Microsoft.KeyVault/register/action",
    "Microsoft.Insights/diagnosticSettings/*"
  ],
  "AssignableScopes": [
    "$mgScope"
  ]
}
"@

    # Temporarily ensure SP1 has Owner permissions on the management group for role operations
    Write-Host "`t`t→ Temporarily assigning Owner role to SP1 on mgScope" -ForegroundColor Yellow
    Add-AzRoleAssignment -ObjectId $global:sp1.Id -RoleDefinitionName "Owner" -Scope $mgScope

    Add-AzCustomRole     -RoleName       $roleName1 `
                         -TenantId       $global:tenantId `
                         -JsonDefinition $json1

    Add-CustomRoleAssignment `
        -ObjectId $global:sp1.Id `
        -RoleName $roleName1 `
        -Scope    $mgScope

    # Remove temporary Owner role assignment
    Write-Host "`t`t→ Removing temporary Owner role from SP1 on mgScope" -ForegroundColor Yellow
    Remove-AzRoleAssignment -ObjectId $global:sp1.Id -RoleDefinitionName "Owner" -Scope $mgScope -ErrorAction SilentlyContinue | Out-Null

    $info = "AppName: $app1Name; Custom role '$roleName1' created & assigned"
    Write-Host "`t`t→ $info`n" -ForegroundColor Green
    $global:stepResults += @{ Name = "SP1: Ensure Custom Role1 & Assign"; Info = $info }
}

# --------------------------- SP1: RBAC – Custom Role 2 ---------------------------
function TaskSP1RBACCustomRole2 {
    Write-Host "`t🎨 [Task] SP1 – Ensure custom role 'cr-management-administrator' and assign it..." -ForegroundColor Magenta

    Import-Module "$PSScriptRoot/Modules/AzureRbacHelper.psm1" -Force -ErrorAction Stop -DisableNameChecking

    $roleName2 = "cr-management-administrator"
    $mgScope   = "/providers/Microsoft.Management/managementGroups/$($global:tenantId)"

    $json2 = @"
{
  "Name": "$roleName2",
  "Description": "Custom role for management administrators",
  "Actions": [
    "Microsoft.Management/managementGroups/read",
    "Microsoft.Management/managementGroups/write",
    "Microsoft.Management/managementGroups/delete",
    "Microsoft.Management/managementGroups/subscriptions/read",
    "Microsoft.Management/managementGroups/subscriptions/write",
    "Microsoft.Authorization/policyDefinitions/read",
    "Microsoft.Authorization/policyDefinitions/write",
    "Microsoft.Authorization/policyDefinitions/delete",
    "Microsoft.Resources/subscriptions/resourceGroups/read",
    "Microsoft.Resources/subscriptions/resourceGroups/write",
    "Microsoft.Resources/subscriptions/resourceGroups/delete",
    "Microsoft.Authorization/roleDefinitions/write",
    "Microsoft.Authorization/roleDefinitions/read",
    "Microsoft.Management/managementGroups/subscriptions/delete",
    "Microsoft.Authorization/roleAssignments/read",
    "Microsoft.Authorization/roleAssignments/write",
    "Microsoft.Authorization/roleAssignments/delete"
  ],
  "AssignableScopes": [
    "$mgScope"
  ]
}
"@

    Add-AzCustomRole     -RoleName       $roleName2 `
                         -TenantId       $global:tenantId `
                         -JsonDefinition $json2

    Add-CustomRoleAssignment `
        -ObjectId $global:sp1.Id `
        -RoleName $roleName2 `
        -Scope    $mgScope

    $info = "AppName: $app1Name; Custom role '$roleName2' created & assigned"
    Write-Host "`t`t→ $info`n" -ForegroundColor Green
    $global:stepResults += @{ Name = "SP1: Ensure Custom Role2 & Assign"; Info = $info }
}

# --------------------------- SP1: Graph Directory Role ---------------------------
function TaskSP1GraphDirRole {
    Write-Host "`t🔗 [Task] SP1 – Assign 'Application Administrator' directory role via Graph..." -ForegroundColor Magenta

    Import-Module "$PSScriptRoot/Modules/GraphDirectoryRoleHelper.psm1" -Force -ErrorAction Stop -DisableNameChecking
    
    # Ensure the app exists in Graph
    $mgApp1 = Get-MgApplication -Filter "appId eq '$($global:app1.AppId)'"
    if (-not $mgApp1) {
        throw "[Task] ERROR: Cannot find Graph Application with appId = '$($global:app1.AppId)'."
    }

    Add-GraphDirectoryRoleAssignment `
        -RoleDisplayName     "Application Administrator" `
        -ServicePrincipalId  $global:sp1.Id

    $info = "AppName: $app1Name; Application Administrator role assigned"
    Write-Host "`t`t→ $info`n" -ForegroundColor Green
    $global:stepResults += @{ Name = "SP1: Assign Graph Dir Role (App Admin)"; Info = $info }
}

# --------------------------- Confluence Export ---------------------------
function TaskExportConfluenceDoc {
    Write-Host "`t📄 [Task] Exporting Confluence documentation..." -ForegroundColor Magenta

    $modulePath = Join-Path $PSScriptRoot 'Modules/ConfluenceDoc.generated.psm1'
    $outputFile = Join-Path $PSScriptRoot 'NCCE_Confluence_Documentation.md'

    if (-not (Test-Path $modulePath)) {
        Write-Warning "Confluence module not found at $modulePath – skipping export."
        $global:stepResults += @{ Name = "Export Confluence Doc"; Info = "Skipped (module missing)" }
        return
    }

    try {
        Import-Module $modulePath -Force -ErrorAction Stop
    }
    catch {
        Write-Warning "Failed to load Confluence module: $($_.Exception.Message)"
        $global:stepResults += @{ Name = "Export Confluence Doc"; Info = "Skipped (module load failed)" }
        return
    }

    try {
        Export-NcceConfluenceConfiguration -TenantName $global:contexts.Azure.Tenant.Name -OutputFile $outputFile
        Write-Host "`t✅ [Task] Confluence doc exported to: $outputFile`n" -ForegroundColor Green
        $global:stepResults += @{ Name = "Export Confluence Doc"; Info = "Documentation exported to $outputFile" }
    }
    catch {
        Write-Warning "Confluence export failed: $($_.Exception.Message)"
        $global:stepResults += @{ Name = "Export Confluence Doc"; Info = "Failed ($($_.Exception.Message))" }
    }
}


# --------------------------- Main Execution & Workflow ---------------------------
Show-Banner

# Resolve UAMI up-front (create or reuse only if inputs are provided)
if ($UamiClientId -and $UamiPrincipalId -and $UamiResourceId) {
  Write-Host "✔️  UAMI configured; will use:"
  Write-Host "     ClientId   = $UamiClientId"
  Write-Host "     PrincipalId= $UamiPrincipalId"
  Write-Host "     ResourceId = $UamiResourceId"
  $script:UamiClientId    = $UamiClientId
  $script:UamiPrincipalId = $UamiPrincipalId
  $script:UamiResourceId  = $UamiResourceId
}
else {
  Write-Host "⚠️  No UAMI configuration provided; skipping UAMI creation and any UAMI-dependent steps." -ForegroundColor Yellow
}

$steps = @(
    @{ Name = "Prepare Environment";                                            Action = { SetupEnvironment             } },
    @{ Name = "Login to Azure & Microsoft Graph";                               Action = { TaskInitAuth                 } },
    @{ Name = "Select Target Subscription";                                     Action = { TaskSelectTargetSubscription } },                     
    @{ Name = "Provisioner App: Create Application";                            Action = { TaskSP1CreateApp             } },
    @{ Name = "Provisioner App: Create Service Principal";                      Action = { TaskSP1CreateSP              } },
    @{ Name = "Provisioner App: Create Client Secret";                          Action = { TaskSP1CreateCredential      } },
    @{ Name = "Token Rotator App: Create Application";                          Action = { TaskSP2CreateApp             } },
    @{ Name = "Token Rotator App: Create Service Principal";                    Action = { TaskSP2CreateSP              } },
    @{ Name = "Token Rotator App: Add FIC";                                     Action = { TaskSP2AddFic                } },
    @{ Name = "Provisioner: Grant Directory.ReadWrite.All Permission";          Action = { TaskSP1GraphPermission       } },
    @{ Name = "Provisioner: Assign Owner Role to Subscription";                 Action = { TaskSP1RBACOwner             } },
    @{ Name = "Provisioner: Create & Assign 'Subscription Provisioner' Role";   Action = { TaskSP1RBACCustomRole1       } },
    @{ Name = "Provisioner: Create & Assign 'Management Administrator' Role";   Action = { TaskSP1RBACCustomRole2       } },
    @{ Name = "Provisioner: Assign 'Application Administrator' Directory Role"; Action = { TaskSP1GraphDirRole          } },
    @{ Name = "Export Confluence Documentation";                                Action = { TaskExportConfluenceDoc      } },
    @{ Name = "Disconnect from Graph for your Safety";                          Action = { Disconnect-MgGraph           } }
)

$total = $steps.Count
for ($i = 0; $i -lt $total; $i++) {
    $stepIndex   = $i + 1
    $currentStep = $steps[$i].Name
    $percent     = [int]($stepIndex / $total * 100)

    Write-Progress -Id 1 -Activity "Cloud Engine Setup Progress: $percent% Complete" -Status "Step $stepIndex/$total – $currentStep" -PercentComplete $percent

    Write-Host "🎬 [Workflow] Starting: $currentStep" -ForegroundColor Cyan
    & $steps[$i].Action
    Write-Host "✅ [Workflow] Completed: $currentStep`n" -ForegroundColor Cyan
}

Write-Progress -Id 1 -Activity "☁️ NCCE Setup Progress" -Completed

# --------------------------- Summary ---------------------------
Write-Host "`n📑  Step Summary:" -ForegroundColor Cyan

# Determine padding based on the longest step name (by length, not value)
$maxNameLength = ($global:stepResults | ForEach-Object { $_.Name.Length } | Measure-Object -Maximum).Maximum

foreach ($entry in $global:stepResults) {
    $paddedName = $entry.Name.PadRight($maxNameLength)
    Write-Host "  ✅ " -NoNewline -ForegroundColor Green
    Write-Host $paddedName -NoNewline -ForegroundColor White
    Write-Host " : " -NoNewline -ForegroundColor Gray
    Write-Host $entry.Info -ForegroundColor Cyan
}
Write-Host ""

# --------------------------- Output Parameters ---------------------------
Write-CredentialSummary -Data $global:Artefacts

# Return outputs for programmatic consumption (CI/CD etc.)
return $global:Artefacts
