<#
.SYNOPSIS
    NCCE Prerequisites Setup - Creates a service principal with custom roles for Azure management.
.DESCRIPTION
    Dieses Skript legt alle benötigten Azure AD Applications, Service Principals und Custom Roles
    an oder verwendet bereits vorhandene Ressourcen.
.NOTES
    Version:        1.8
    Author:         Timo Haldi
    Creation Date:  May 7, 2025
    Last Updated:   May 20, 2025
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

# Ensure required modules for Azure and Microsoft Graph
EnsureModule -ModuleName "Az.Accounts"
EnsureModule -ModuleName "Az.Resources"
EnsureModule -ModuleName "Microsoft.Graph.Authentication"
EnsureModule -ModuleName "Microsoft.Graph.Applications"
EnsureModule -ModuleName "Microsoft.Graph.Identity.DirectoryManagement"

# Step 1: Login to both Azure and Microsoft Entra ID
Show-Progress "Logging in to Azure and Microsoft Entra ID" 1 13
Write-ColorOutput "Please authenticate via device code..." "Magenta"

# Login to Azure
$ctx = Get-AzContext -ErrorAction SilentlyContinue
if (-not $ctx) {
    Connect-AzAccount -UseDeviceAuthentication
    $ctx = Get-AzContext
    if (-not $ctx) { Write-Error "Azure Authentication failed"; exit 1 }
}
$tenant = $ctx.Tenant.Id
$subId  = $ctx.Subscription.Id
Write-Success "Logged in to Azure tenant: $tenant"

# Login to Microsoft Graph
Write-ColorOutput "Now connecting to Microsoft Graph..." "Magenta"
Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null

# Connect with appropriate scopes for API permissions management
$graphScopes = @(
    "Application.ReadWrite.All",
    "Directory.ReadWrite.All",
    "AppRoleAssignment.ReadWrite.All",
    "RoleManagement.ReadWrite.Directory"
)

try {
    Connect-MgGraph -Scopes $graphScopes -UseDeviceAuthentication
    Write-Success "Connected to Microsoft Graph"
}
catch {
    Write-Error "Microsoft Graph authentication failed: $($_.Exception.Message)"
    Write-Warning "Some script functionality may be limited"
}

# Common domain lookup
$domain = (Get-AzTenant -TenantId $tenant).Domains[0]

# === SP1: sp-ncce-global-provisioner ===
# Step 2: Application
Show-Progress "Ensure App sp-ncce-global-provisioner" 2 13
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
Show-Progress "Ensure SP for sp-ncce-global-provisioner" 3 13
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
Show-Progress "Ensure credential for SP1" 4 13
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
Show-Progress "Ensure App sp-ncce-token-rotator" 5 13
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
Show-Progress "Ensure SP for sp-ncce-token-rotator" 6 13
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
Show-Progress "Ensure credential for Token Rotator" 7 13
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

# Output Service Principal information before Entra operations
Write-Separator
Write-ColorOutput "📋 Service Principal Information (Save these credentials)" "Yellow"
Write-ColorOutput "App Name: $appName" "Cyan"
Write-ColorOutput "Service Principal Object ID: $($sp.Id)" "Cyan"
Write-ColorOutput "Service Principal Client ID: $($app.AppId)" "Cyan"
if ($plainPassword) {
    Write-ColorOutput "Service Principal Client Secret: $plainPassword" "Red"
} else {
    Write-ColorOutput "Service Principal Client Secret: [Using existing credential]" "Red"
}
Write-ColorOutput " "
Write-ColorOutput "App Name: $trAppName" "Cyan"
Write-ColorOutput "Token Rotator Object ID: $($trSp.Id)" "Cyan"
Write-ColorOutput "Token Rotator Client ID: $($trApp.AppId)" "Cyan"
if ($trPassword) {
    Write-ColorOutput "Token Rotator Client Secret: $trPassword" "Red"
} else {
    Write-ColorOutput "Token Rotator Client Secret: [Using existing credential]" "Red"
}
Write-Separator

# Step 8: Add Microsoft.Directory.ReadWrite.All permission to SP1
Show-Progress "Adding Microsoft.Directory.ReadWrite.All permission to SP1" 8 13
Write-ColorOutput "Adding Microsoft.Directory.ReadWrite.All API permission to $appName..." "Magenta"

try {
    # Get the Microsoft Graph resource
    $graphServicePrincipal = Get-MgServicePrincipal -Filter "AppId eq '00000003-0000-0000-c000-000000000000'"
    
    if ($graphServicePrincipal) {
        # Find the Directory.ReadWrite.All permission
        $permissionName = "Directory.ReadWrite.All"
        $appRole = $graphServicePrincipal.AppRoles | Where-Object { $_.Value -eq $permissionName }
        
        if ($appRole) {
            # Get the application using Microsoft Graph
            $mgApp = Get-MgApplication -Filter "AppId eq '$($app.AppId)'"
            
            # Check if the permission is already assigned
            $requiredResourceAccess = $mgApp.RequiredResourceAccess | Where-Object { $_.ResourceAppId -eq $graphServicePrincipal.AppId }
            $permissionAlreadyAdded = $false
            
            if ($requiredResourceAccess) {
                $permissionAlreadyAdded = $requiredResourceAccess.ResourceAccess | 
                    Where-Object { $_.Id -eq $appRole.Id -and $_.Type -eq "Role" }
            }
            
            if ($permissionAlreadyAdded) {
                Write-Success "Microsoft.Directory.ReadWrite.All permission already added to the application"
            } else {
                # Add the permission
                if (-not $requiredResourceAccess) {
                    # Create new required resource access for Microsoft Graph
                    $requiredResourceAccess = @{
                        ResourceAppId = $graphServicePrincipal.AppId
                        ResourceAccess = @(
                            @{
                                Id = $appRole.Id
                                Type = "Role"
                            }
                        )
                    }
                    
                    # If app already has some permissions, preserve them
                    $existingRequiredResourceAccess = $mgApp.RequiredResourceAccess
                    if ($existingRequiredResourceAccess) {
                        $updatedRequiredResourceAccess = $existingRequiredResourceAccess + @($requiredResourceAccess)
                    } else {
                        $updatedRequiredResourceAccess = @($requiredResourceAccess)
                    }
                } else {
                    # Add the new permission to the existing resource access collection
                    $updatedResourceAccess = $requiredResourceAccess.ResourceAccess + @(
                        @{
                            Id = $appRole.Id
                            Type = "Role"
                        }
                    )
                    
                    # Update the required resource access for Microsoft Graph
                    $updatedRequiredResourceAccess = $mgApp.RequiredResourceAccess | ForEach-Object {
                        if ($_.ResourceAppId -eq $graphServicePrincipal.AppId) {
                            @{
                                ResourceAppId = $_.ResourceAppId
                                ResourceAccess = $updatedResourceAccess
                            }
                        } else {
                            $_
                        }
                    }
                }
                
                # Update the application with the new permissions
                Update-MgApplication -ApplicationId $mgApp.Id -RequiredResourceAccess $updatedRequiredResourceAccess
                Write-Success "Microsoft.Directory.ReadWrite.All permission added to the application"
                
                # Grant admin consent
                Write-ColorOutput "Attempting to grant admin consent for the permission..." "Magenta"
                try {
                    # Get service principal using Microsoft Graph
                    $mgSp = Get-MgServicePrincipal -Filter "AppId eq '$($app.AppId)'"
                    
                    # Create app role assignment
                    $params = @{
                        PrincipalId = $mgSp.Id
                        ResourceId = $graphServicePrincipal.Id
                        AppRoleId = $appRole.Id
                    }
                    
                    New-MgServicePrincipalAppRoleAssignment -ServicePrincipalId $mgSp.Id -BodyParameter $params
                    Write-Success "Admin consent granted for Microsoft.Directory.ReadWrite.All"
                }
                catch {
                    if ($_.Exception.Message -like "*already exists*") {
                        Write-Success "Admin consent already granted"
                    } else {
                        Write-Warning "Could not grant admin consent automatically: $($_.Exception.Message)"
                        Write-ColorOutput "To grant admin consent manually:" "Yellow"
                        Write-ColorOutput "1. Go to Azure Portal -> Microsoft Entra ID -> App Registrations" "Yellow"
                        Write-ColorOutput "2. Find '$appName' and select API permissions" "Yellow"
                        Write-ColorOutput "3. Click 'Grant admin consent for [tenant]'" "Yellow"
                    }
                }
            }
        } else {
            Write-Error "Could not find Directory.ReadWrite.All permission in Microsoft Graph"
        }
    } else {
        Write-Error "Could not find Microsoft Graph Service Principal"
    }
}
catch {
    Write-Error "Failed to add Microsoft.Directory.ReadWrite.All permission: $($_.Exception.Message)"
    Write-ColorOutput "To add the permission manually:" "Yellow"
    Write-ColorOutput "1. Go to Azure Portal -> Microsoft Entra ID -> App Registrations" "Yellow"
    Write-ColorOutput "2. Find '$appName' and select API permissions" "Yellow"
    Write-ColorOutput "3. Add a permission -> Microsoft Graph -> Application permissions" "Yellow"
    Write-ColorOutput "4. Select Directory.ReadWrite.All and save" "Yellow"
    Write-ColorOutput "5. Click 'Grant admin consent for [tenant]'" "Yellow"
}

# === SP1 Role Assignments & Custom Roles ===
# Step 9: Owner at Subscription
Show-Progress "Ensure Owner role on subscription for SP1" 9 13
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

# Step 10: Custom Roles at ManagementGroup - Subscription Provisioner
Show-Progress "Ensure custom role cr-subscription-provisioner" 10 13
$roleName = "cr-subscription-provisioner"
$existingRole = Get-AzRoleDefinition -Name $roleName -ErrorAction SilentlyContinue
if ($existingRole) {
    Write-Success "Custom role $roleName already exists"
    Write-ColorOutput "Existing role scopes: $($existingRole.AssignableScopes -join ', ')" "White"
} else {
    Write-ColorOutput "Creating custom role $roleName at Tenant Root Group level..." "Magenta"
    
    # Check if user has access to the Management Group
    $mgmtGroupAccess = $false
    try {
        Get-AzManagementGroup -GroupId $tenant -ErrorAction Stop | Out-Null
        $mgmtGroupAccess = $true
        Write-Success "Access to Tenant Root Management Group confirmed"
    }
    catch {
        Write-Warning "Cannot access Tenant Root Management Group: $($_.Exception.Message)"
        Write-ColorOutput "Will attempt to create role but it may fail" "Yellow"
    }
    
    $mgScope = "/providers/Microsoft.Management/managementGroups/$tenant"
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
    "$mgScope"
  ]
}
"@
    $tmp = [IO.Path]::GetTempFileName() + ".json"
    $json | Out-File -FilePath $tmp -Encoding utf8
    
    try {
        $newRole = New-AzRoleDefinition -InputFile $tmp -ErrorAction Stop
        Write-Success "Created custom role $roleName at Tenant Root Group level"
    }
    catch {
        Write-Error "Failed to create role at Tenant Root Group: $($_.Exception.Message)"
        Write-ColorOutput "To create the role manually with Tenant Root Group scope:" "Yellow"
        Write-ColorOutput "1. Save this JSON to a file:" "Yellow"
        Write-ColorOutput $json "White"
        Write-ColorOutput "2. Run: New-AzRoleDefinition -InputFile <path-to-file>" "Yellow"
    }
    finally {
        Remove-Item $tmp -ErrorAction SilentlyContinue
    }
}

# Step 11: Custom Roles at ManagementGroup - Management Administrator
Show-Progress "Ensure custom role cr-management-administrator" 11 13
$roleNameMgmt = "cr-management-administrator"
$existingRoleMgmt = Get-AzRoleDefinition -Name $roleNameMgmt -ErrorAction SilentlyContinue
if ($existingRoleMgmt) {
    Write-Success "Custom role $roleNameMgmt already exists"
    Write-ColorOutput "Existing role scopes: $($existingRoleMgmt.AssignableScopes -join ', ')" "White"
} else {
    Write-ColorOutput "Creating custom role $roleNameMgmt at Tenant Root Group level..." "Magenta"
    
    # Check if user has access to the Management Group
    $mgmtGroupAccess = $false
    try {
        Get-AzManagementGroup -GroupId $tenant -ErrorAction Stop | Out-Null
        $mgmtGroupAccess = $true
        Write-Success "Access to Tenant Root Management Group confirmed"
    }
    catch {
        Write-Warning "Cannot access Tenant Root Management Group: $($_.Exception.Message)"
        Write-ColorOutput "Will attempt to create role but it may fail" "Yellow"
    }
    
    $mgScope = "/providers/Microsoft.Management/managementGroups/$tenant"
    $jsonMgmt = @"
{
  "Name": "$roleNameMgmt",
  "Description": "Custom role for managing Management Groups, Custom Groups and Policies.",
  "Actions": [
    "Microsoft.Management/managementGroups/read",
    "Microsoft.Management/managementGroups/write",
    "Microsoft.Management/managementGroups/delete",
    "Microsoft.Management/managementGroups/descendants/read",
    "Microsoft.Management/managementGroups/subscriptions/write",
    "Microsoft.Management/managementGroups/settings/read",
    "Microsoft.Management/managementGroups/settings/write",
    "Microsoft.Authorization/policyDefinitions/read",
    "Microsoft.Authorization/policyDefinitions/write",
    "Microsoft.Authorization/policyDefinitions/delete",
    "Microsoft.Authorization/policySetDefinitions/read",
    "Microsoft.Authorization/policySetDefinitions/write",
    "Microsoft.Authorization/policySetDefinitions/delete",
    "Microsoft.Authorization/policyAssignments/read",
    "Microsoft.Authorization/policyAssignments/write",
    "Microsoft.Authorization/policyAssignments/delete",
    "Microsoft.Resources/subscriptions/resourceGroups/read",
    "Microsoft.Resources/subscriptions/resourceGroups/write",
    "Microsoft.Resources/subscriptions/resourceGroups/delete",
    "Microsoft.Management/register/action",
    "Microsoft.Resources/subscriptions/read"
  ],
  "AssignableScopes": [
    "$mgScope"
  ]
}
"@
    $tmpMgmt = [IO.Path]::GetTempFileName() + ".json"
    $jsonMgmt | Out-File -FilePath $tmpMgmt -Encoding utf8
    
    try {
        $newRoleMgmt = New-AzRoleDefinition -InputFile $tmpMgmt -ErrorAction Stop
        Write-Success "Created custom role $roleNameMgmt at Tenant Root Group level"
    }
    catch {
        Write-Error "Failed to create role at Tenant Root Group: $($_.Exception.Message)"
        Write-ColorOutput "To create the role manually with Tenant Root Group scope:" "Yellow"
        Write-ColorOutput "1. Save this JSON to a file:" "Yellow"
        Write-ColorOutput $jsonMgmt "White"
        Write-ColorOutput "2. Run: New-AzRoleDefinition -InputFile <path-to-file>" "Yellow"
    }
    finally {
        Remove-Item $tmpMgmt -ErrorAction SilentlyContinue
    }
}

# Step 12: Assign custom role to SP at Tenant Root Group level
Show-Progress "Assign custom role to SP at Tenant Root Group" 12 13
$mgScope = "/providers/Microsoft.Management/managementGroups/$tenant"
$customRoleAssign = Get-AzRoleAssignment -ObjectId $sp.Id `
    -Scope $mgScope `
    -RoleDefinitionName $roleName -ErrorAction SilentlyContinue
if ($customRoleAssign) {
    Write-Success "SP1 already has $roleName role at Tenant Root Group level"
} else {
    Write-ColorOutput "Assigning $roleName role to SP1 at Tenant Root Group level..." "Magenta"
    try {
        New-AzRoleAssignment -ObjectId $sp.Id -RoleDefinitionName $roleName -Scope $mgScope -ErrorAction Stop | Out-Null
        Write-Success "$roleName role assigned to SP1 at Tenant Root Group level"
    }
    catch {
        Write-Error "Failed to assign $roleName at Tenant Root Group level: $($_.Exception.Message)"
        Write-ColorOutput "To assign the role manually:" "Yellow"
        Write-ColorOutput "1. Navigate to Azure Portal -> Management Groups -> $tenant" "Yellow"
        Write-ColorOutput "2. Select 'Access control (IAM)' -> 'Add role assignment'" "Yellow"
        Write-ColorOutput "3. Select role '$roleName', assign to '$appName'" "Yellow"
    }
}

# Step 13: Assign Application Administrator role to SP using Microsoft Graph
Show-Progress "Assign Application Administrator role to SP" 13 13
Write-ColorOutput "Assigning Application Administrator role to $appName via Microsoft Graph..." "Magenta"

try {
    # Check if we're already connected to Microsoft Graph
    try {
        Get-MgContext -ErrorAction Stop | Out-Null
    }
    catch {
        # Reconnect if needed
        Write-ColorOutput "Reconnecting to Microsoft Graph..." "Magenta"
        Connect-MgGraph -Scopes $graphScopes -UseDeviceAuthentication
    }
    
    # Step 1: Get all directory roles and find Application Administrator by name
    Write-ColorOutput "Finding Application Administrator role..." "Magenta"
    $allRoles = Get-MgDirectoryRole
    $appAdminRole = $allRoles | Where-Object { $_.DisplayName -eq "Application Administrator" }
    
    # If role not found, try to activate it
    if (-not $appAdminRole) {
        Write-ColorOutput "Application Administrator role not found, trying to activate it..." "Yellow"
        
        # Get the role template
        $roleTemplates = Get-MgDirectoryRoleTemplate
        $appAdminTemplate = $roleTemplates | Where-Object { $_.DisplayName -eq "Application Administrator" }
        
        if ($appAdminTemplate) {
            try {
                # Try to activate the role
                $params = @{
                    "roleTemplateId" = $appAdminTemplate.Id
                }
                
                Write-ColorOutput "Activating Application Administrator role..." "Magenta"
                $newRole = New-MgDirectoryRole -BodyParameter $params -ErrorAction Stop
                Write-Success "Application Administrator role activated"
                $appAdminRole = $newRole
            }
            catch {
                # If we get a conflict, the role is already active but not being returned properly
                # Re-query all roles
                if ($_.Exception.Message -like "*A conflicting object*") {
                    Write-ColorOutput "Role already exists. Re-checking roles..." "Yellow"
                    Start-Sleep -Seconds 2  # Brief pause to allow for any replication
                    $allRoles = Get-MgDirectoryRole
                    $appAdminRole = $allRoles | Where-Object { $_.DisplayName -eq "Application Administrator" }
                }
                else {
                    throw $_
                }
            }
        }
        else {
            throw "Could not find Application Administrator role template"
        }
    }
    
    # Check if we now have a valid role
    if ($appAdminRole -and $appAdminRole.Id) {
        Write-Success "Found Application Administrator role with ID: $($appAdminRole.Id)"
        
        # Check if SP is already a member
        Write-ColorOutput "Checking existing role members..." "Magenta"
        $members = Get-MgDirectoryRoleMember -DirectoryRoleId $appAdminRole.Id
        $spIsMember = $members | Where-Object { $_.Id -eq $sp.Id }
        
        if ($spIsMember) {
            Write-Success "Service Principal is already a member of the Application Administrator role"
        }
        else {
            # Add the service principal to the role
            Write-ColorOutput "Adding service principal to Application Administrator role..." "Magenta"
            try {
                $params = @{
                    "@odata.id" = "https://graph.microsoft.com/v1.0/directoryObjects/$($sp.Id)"
                }
                
                New-MgDirectoryRoleMemberByRef -DirectoryRoleId $appAdminRole.Id -BodyParameter $params
                Write-Success "Service Principal assigned to Application Administrator role"
            }
            catch {
                # If the error is that the member already exists, consider it a success
                if ($_.Exception.Message -like "*One or more added object references already exist*") {
                    Write-Success "Service Principal is already a member of the Application Administrator role"
                }
                else {
                    # For other errors, rethrow
                    throw $_
                }
            }
        }
    }
    else {
        throw "Could not find or activate Application Administrator role"
    }
}
catch {
    Write-Error "Failed to assign Application Administrator role: $($_.Exception.Message)"
    Write-ColorOutput "For manual assignment:" "Yellow"
    Write-ColorOutput "1. Navigate to Azure Portal -> Microsoft Entra ID -> Roles and administrators" "Yellow"
    Write-ColorOutput "2. Find and select 'Application Administrator'" "Yellow"
    Write-ColorOutput "3. Click 'Add assignments' and search for '$appName'" "Yellow"
}

# Disconnect from Microsoft Graph
Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null
Write-Success "Disconnected from Microsoft Graph"

Write-Separator
Write-ColorOutput "✅ Service Principal setup complete!" "Green"
Write-ColorOutput "App Name: $appName" "Cyan"
Write-ColorOutput "Service Principal Object ID: $($sp.Id)" "Cyan"
Write-ColorOutput "Service Principal Client ID: $($app.AppId)" "Cyan"
if ($plainPassword) {
    Write-ColorOutput "Service Principal Client Secret: $plainPassword" "Red"
}
Write-ColorOutput " "
Write-ColorOutput "App Name: $trAppName" "Cyan"
Write-ColorOutput "Token Rotator Object ID: $($trSp.Id)" "Cyan"
Write-ColorOutput "Token Rotator Client ID: $($trApp.AppId)" "Cyan"
if ($trPassword) {
    Write-ColorOutput "Token Rotator Client Secret: $trPassword" "Red"
}
Write-ColorOutput " "
Write-ColorOutput "📋 Important: Copy and save the passwords displayed above in a secure location." "Yellow"
Write-ColorOutput "The passwords will not be shown again!" "Red"
Write-ColorOutput "Setup completed at $(Get-Date)" "Green"