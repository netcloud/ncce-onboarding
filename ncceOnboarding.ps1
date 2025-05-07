<#
.SYNOPSIS
    NCCE Prerequisites Setup - Creates a service principal with custom roles for Azure management.
.DESCRIPTION
    This script creates an Azure AD application, service principal and assigns custom roles
    at the tenant root management group level for managing Azure resources.
.NOTES
    Version:        1.5
    Author:         Timo Haldi
    Creation Date:  May 7, 2025
    Last Updated:   May 7, 2025
#>

# Function to show colorful status messages
function Write-ColorOutput {
    param(
        [Parameter(Mandatory=$true)]
        [AllowEmptyString()]
        [string]$Message,
        [Parameter(Mandatory=$false)]
        [string]$ForegroundColor = "White"
    )
    
    $originalFgColor = $host.UI.RawUI.ForegroundColor
    $host.UI.RawUI.ForegroundColor = $ForegroundColor
    Write-Output $Message
    $host.UI.RawUI.ForegroundColor = $originalFgColor
}

function Show-Banner {
    Clear-Host
    $bannerText = @"
╔══════════════════════════════════════════════════════════════╗
║                                                              ║
║                    NCCE PREREQUISITES SETUP                  ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
"@
    Write-ColorOutput $bannerText "Cyan"
    Write-ColorOutput " "
}

function Show-Progress {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Step,
        [Parameter(Mandatory=$true)]
        [int]$Current,
        [Parameter(Mandatory=$true)]
        [int]$Total
    )
    
    $percentComplete = [math]::Floor(($Current / $Total) * 100)
    $progressBarWidth = 10
    $filledWidth = [math]::Floor($percentComplete / (100 / $progressBarWidth))
    $emptyWidth = $progressBarWidth - $filledWidth
    $progressBar = "[" + ("■" * $filledWidth) + (" " * $emptyWidth) + "]"
    
    Write-ColorOutput "$progressBar $percentComplete% - $Step" "Yellow"
}

function Write-Success {
    param([string]$Message)
    Write-ColorOutput "✓ $Message" "Green"
}

function Write-Warning {
    param([string]$Message)
    Write-ColorOutput "⚠️ $Message" "Yellow"
}

function Write-Error {
    param([string]$Message)
    Write-ColorOutput "! $Message" "Red"
}

function Write-Separator {
    Write-ColorOutput "─────────────────────────────────────────────────────────────────" "Gray"
}

# Check if required modules are available and install if necessary
function EnsureModule {
    param(
        [Parameter(Mandatory=$true)]
        [string]$ModuleName
    )
    
    try {
        $module = Get-Module -Name $ModuleName -ListAvailable
        
        if ($null -eq $module) {
            Write-ColorOutput "$ModuleName module not found. Attempting to install..." "Magenta"
            Install-Module -Name $ModuleName -Force -Scope CurrentUser -AllowClobber
            Write-Success "$ModuleName module installed successfully"
        } else {
            Write-Success "$ModuleName module is already installed"
        }
        
        return $true
    }
    catch {
        Write-Error "Failed to install $ModuleName module: $($_.Exception.Message)"
        return $false
    }
}

# Main script
Show-Banner

Write-ColorOutput "Starting Azure Service Principal setup..." "Green"
Write-ColorOutput "This script will create a service principal with custom roles." "Green"
Write-Separator

# Check for required modules
EnsureModule -ModuleName "Az.Accounts"
EnsureModule -ModuleName "Az.Resources"

# Step 1: Login
Show-Progress -Step "Logging in to Azure" -Current 1 -Total 7
Write-ColorOutput "Initiating device code authentication. Please authenticate when prompted..." "Magenta"

# Check if already logged in
$context = Get-AzContext -ErrorAction SilentlyContinue
if (-not $context) {
    Connect-AzAccount -UseDeviceAuthentication
    $context = Get-AzContext
    if (-not $context) {
        Write-Error "Failed to authenticate to Azure. Exiting."
        exit 1
    }
}

$tenant = $context.Tenant.Id
$subId = $context.Subscription.Id
Write-Success "Successfully logged in to tenant: $tenant"

# Step 2: Create Application
Show-Progress -Step "Creating Azure AD Application" -Current 2 -Total 7
$appName = "sp-ncce-global-provisioner"
$domain = (Get-AzTenant -TenantId $tenant).Domains[0]
Write-ColorOutput "Creating application '$appName' with verified domain: $domain" "Magenta"

try {
    $app = New-AzADApplication -DisplayName $appName `
                              -IdentifierUris "https://$domain/$appName" `
                              -SignInAudience AzureADMyOrg
    
    Write-Success "Application created with ID: $($app.Id)"
    Write-Success "Application AppId: $($app.AppId)"
    
    # Pause briefly to ensure application is fully created before continuing
    Start-Sleep -Seconds 5
}
catch {
    Write-Error "Fatal error creating application: $($_.Exception.Message)"
    exit 1
}

# Step 3: Create Service Principal
Show-Progress -Step "Creating Service Principal" -Current 3 -Total 7
Write-ColorOutput "Creating service principal for application..." "Magenta"
try {
    $sp = New-AzADServicePrincipal -ApplicationId $app.AppId
    
    Write-Success "Service Principal created with Object ID: $($sp.Id)"
    Start-Sleep -Seconds 5  # Brief pause for consistency
}
catch {
    Write-Error "Fatal error creating service principal: $($_.Exception.Message)"
    exit 1
}

# Step 4: Create Application Credential
Show-Progress -Step "Creating Service Principal Credential" -Current 4 -Total 7
Write-ColorOutput "Creating credential for service principal..." "Magenta"

$credentialCreated = $false
$plainPassword = $null

# Try with Azure CLI - most reliable method
try {
    # Check if Azure CLI is installed
    $azCliInstalled = $null -ne (Get-Command az -ErrorAction SilentlyContinue)
    
    if ($azCliInstalled) {
        Write-ColorOutput "Using Azure CLI to create application credential..." "Magenta"
        
        # Execute Azure CLI command targeting APPLICATION
        $azCliCommand = "az ad app credential reset --id $($app.AppId) --append --years 1"
        Write-ColorOutput "Running: $azCliCommand" "Gray"
        
        $result = Invoke-Expression $azCliCommand
        if ($result) {
            $jsonResult = $result | ConvertFrom-Json
            $plainPassword = $jsonResult.password
            Write-Success "Credential created successfully on application using Azure CLI"
            $credentialCreated = $true
            
            Write-Warning "Store this secret in a secure location:"
            Write-ColorOutput "$plainPassword" "Red"
        }
    } else {
        Write-Warning "Azure CLI not found. Please install Azure CLI or use Azure Portal to create credentials."
    }
}
catch {
    Write-Error "Azure CLI application method failed: $($_.Exception.Message)"
}

if (-not $credentialCreated) {
    Write-Error "Could not create credential automatically"
    Write-Warning "Please create a credential manually in the Azure portal"
}

# Step 5: Grant Microsoft Graph Permissions
Show-Progress -Step "Granting application roles" -Current 5 -Total 7
Write-ColorOutput "Assigning Owner role at subscription level..." "Magenta"

try {
    # Give Owner role at subscription level
    $roleAssignment = New-AzRoleAssignment -ObjectId $sp.Id -RoleDefinitionName "Owner" -Scope "/subscriptions/$subId"
    
    Write-Success "Assigned Owner role to service principal"
    Write-Warning "Note: For Graph API permissions, manual consent in Azure Portal is required"
    Write-Warning "Visit the Azure Portal > App Registrations > $appName > API Permissions"
}
catch {
    Write-Error "Unable to assign permissions: $($_.Exception.Message)"
    Write-Warning "You will need to manually assign these permissions in the Azure portal"
}

# Step 6: Create First Custom Role
Show-Progress -Step "Creating Subscription Provisioner role" -Current 6 -Total 7
Write-ColorOutput "Creating custom role for subscription provisioning..." "Magenta"

# Define role at management group level - IMPORTANT: No DataActions for Management Group assignments
$roleName = "cr-subscription-provisioner"
$roleDefinition = @"
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
    "Microsoft.Storage/storageAccounts/blobServices/containers/delete",
    "Microsoft.Storage/storageAccounts/blobServices/containers/read",
    "Microsoft.Storage/storageAccounts/blobServices/containers/write",
    "Microsoft.Storage/storageAccounts/blobServices/generateUserDelegationKey/action",
    "Microsoft.Resources/subscriptions/resourceGroups/read",
    "Microsoft.Resources/subscriptions/resourceGroups/resources/read",
    "Microsoft.Resources/subscriptions/resources/read",
    "Microsoft.Resources/deployments/*",
    "Microsoft.Resources/tags/*"
  ],
  "AssignableScopes": [
    "/providers/Microsoft.Management/managementGroups/$tenant"
  ]
}
"@

# Check if role exists with correct definition
try {
    $existingRole = Get-AzRoleDefinition -Name $roleName -ErrorAction SilentlyContinue
    if ($existingRole) {
        Write-Success "Role '$roleName' already exists"
    } else {
        # Create role at tenant level
        $roleFile = [System.IO.Path]::GetTempFileName() + ".json"
        $roleDefinition | Out-File -FilePath $roleFile -Encoding utf8
        
        # Try to create the role with Az PowerShell
        $role = New-AzRoleDefinition -InputFile $roleFile
        Write-Success "Created role '$roleName' at tenant level"
        
        # Wait for the role to propagate
        Start-Sleep -Seconds 30
        
        # Clean up temp file
        Remove-Item -Path $roleFile -ErrorAction SilentlyContinue
    }
}
catch {
    Write-Error "Could not create custom role: $($_.Exception.Message)"
}

# Role Assignment via Azure CLI
try {
    Write-ColorOutput "Using Azure CLI for role assignment at tenant level..." "Magenta"
    
    # Make sure we use the correct role name formatting
    Write-ColorOutput "Verifying role exists before assignment..." "Magenta"
    $verifyRoleCommand = "az role definition list --name '$roleName' --custom-role-only true --query [].name -o tsv"
    $roleId = Invoke-Expression $verifyRoleCommand
    
    if ([string]::IsNullOrEmpty($roleId)) {
        Write-Warning "Role not found by name, attempting assignment anyway..."
    } else {
        Write-Success "Found role with name: $roleName"
    }
    
    # Assign role using Azure CLI with more debugging
    Write-ColorOutput "Executing role assignment command..." "Magenta"
    $cliCommand = "az role assignment create --assignee-object-id '$($sp.Id)' --role '$roleName' --scope '/providers/Microsoft.Management/managementGroups/$tenant'"
    Write-ColorOutput "Running: $cliCommand" "Gray"
    
    $assignmentResult = Invoke-Expression $cliCommand
    if ($assignmentResult) {
        Write-Success "Role '$roleName' assigned at tenant level successfully"
    } else {
        throw "Azure CLI command did not return a result"
    }
}
catch {
    Write-Error "Failed to assign '$roleName' role at tenant level: $($_.Exception.Message)"
    
    # Try direct API approach as fallback
    try {
        Write-ColorOutput "Trying alternative assignment method..." "Magenta"
        
        # Generate a unique GUID for the assignment
        $assignmentId = [System.Guid]::NewGuid().ToString()
        
        # Use PowerShell to assign role at the subscription level as fallback
        $subAssignment = New-AzRoleAssignment -ObjectId $sp.Id -RoleDefinitionName $roleName -Scope "/subscriptions/$subId"
        Write-Success "Role '$roleName' assigned at subscription level as fallback"
    }
    catch {
        Write-Error "Failed to assign role at subscription level as well: $($_.Exception.Message)"
        Write-Warning "Please manually assign the '$roleName' role in the Azure portal"
    }
}

# Step 7: Create Second Custom Role
Show-Progress -Step "Creating Management Administrator role" -Current 7 -Total 7
Write-ColorOutput "Creating custom role for management groups, groups and policies..." "Magenta"

# Define management role - IMPORTANT: No DataActions for Management Group assignments
$roleName = "cr-management-administrator"
$roleDefinition = @"
{
  "Name": "$roleName",
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
    "Microsoft.Resources/subscriptions/resourceGroups/delete"
  ],
  "AssignableScopes": [
    "/providers/Microsoft.Management/managementGroups/$tenant"
  ]
}
"@

# Check if role exists
try {
    $existingRole = Get-AzRoleDefinition -Name $roleName -ErrorAction SilentlyContinue
    if ($existingRole) {
        Write-Success "Role '$roleName' already exists"
    } else {
        # Create role at tenant level
        $roleFile = [System.IO.Path]::GetTempFileName() + ".json"
        $roleDefinition | Out-File -FilePath $roleFile -Encoding utf8
        
        # Try to create the role with Az PowerShell
        $role = New-AzRoleDefinition -InputFile $roleFile
        Write-Success "Created role '$roleName' at tenant level"
        
        # Wait for the role to propagate
        Start-Sleep -Seconds 30
        
        # Clean up temp file
        Remove-Item -Path $roleFile -ErrorAction SilentlyContinue
    }
}
catch {
    Write-Error "Could not create custom role: $($_.Exception.Message)"
}

# Role Assignment via Azure CLI
try {
    Write-ColorOutput "Using Azure CLI for role assignment at tenant level..." "Magenta"
    
    # Assign role using Azure CLI
    $cliCommand = "az role assignment create --assignee-object-id '$($sp.Id)' --role '$roleName' --scope '/providers/Microsoft.Management/managementGroups/$tenant'"
    Write-ColorOutput "Running: $cliCommand" "Gray"
    
    Invoke-Expression $cliCommand | Out-Null
    Write-Success "Role '$roleName' assigned at tenant level"
}
catch {
    Write-Error "Failed to assign role at tenant level: $($_.Exception.Message)"
    Write-Warning "You may need to manually assign this role in the Azure portal"
}

# Completion
Write-Separator
Write-ColorOutput "✅ Service Principal setup complete!" "Green"
Write-ColorOutput "App Name: $appName" "Cyan"
Write-ColorOutput "App ID: $($app.AppId)" "Cyan"
Write-ColorOutput "Object ID: $($sp.Id)" "Cyan"
Write-ColorOutput "Secret: $plainPassword" "Red"
Write-ColorOutput " "
Write-ColorOutput "📋 Important: Copy and save the password displayed above in a secure location." "Yellow"
Write-ColorOutput "The password will not be shown again!" "Red"

# Save information to a file (optional)
$infoFile = Join-Path -Path $PWD -ChildPath "NCCE-SP-Info-$(Get-Date -Format 'yyyyMMdd-HHmmss').txt"
try {
    @"
NCCE Service Principal Information
Created: $(Get-Date)
------------------------------------------
App Name: $appName
App ID (Client ID): $($app.AppId)
Object ID: $($sp.Id)
Tenant ID: $tenant
Secret: $plainPassword
------------------------------------------
NOTE: This file contains a secret. Keep it secure and delete when no longer needed.
"@ | Out-File -FilePath $infoFile -Encoding utf8

    Write-Success "Information saved to file: $infoFile"
} catch {
    Write-Warning "Could not save information to file: $($_.Exception.Message)"
}

# Final verification step for credentials
Write-ColorOutput "Performing final credential verification..." "Magenta"
try {
    $finalCredsCheck = Get-AzADAppCredential -ApplicationId $app.AppId -ErrorAction SilentlyContinue
    if ($null -eq $finalCredsCheck -or $finalCredsCheck.Count -eq 0) {
        Write-Warning "WARNING: No credentials found in final verification. The credential may not be visible in Azure Portal."
        Write-Warning "You may need to manually create a client secret in the Azure Portal."
    } else {
        Write-Success "Credential verification successful! Found $($finalCredsCheck.Count) credential(s)"
    }
} catch {
    Write-Warning "Could not perform final credential verification: $($_.Exception.Message)"
}

Write-ColorOutput "Setup completed at $(Get-Date)" "Green"