# Initialize-NCCE.ps1 – NCCE PREREQUISITES SETUP
$ErrorActionPreference = 'Stop'

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

# --------------------------- Globals ---------------------------
$global:stepResults    = @()
$global:contexts       = $null
$global:tenantId       = $null
$global:domain         = $null
$global:app1Name       = $null
$global:app1           = $null
$global:sp1            = $null
$global:plainPassword1 = $null
$global:app2Name       = $null
$global:app2           = $null
$global:sp2            = $null
$global:plainPassword2 = $null

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

    # Hier findet interactive Login statt (Azure + Graph), mit den erforderlichen Scopes
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
}

# --------------------------- SP2: sp-ncce-token-rotator ---------------------------
function TaskSP2CreateApp {
    Write-Host "`t⚙️ [Task] SP2 – Ensure App 'sp-ncce-token-rotator' exists..." -ForegroundColor Magenta

    Import-Module "$PSScriptRoot/Modules/AzureSpHelper.psm1" -Force -ErrorAction Stop -DisableNameChecking

    $global:app2Name = "sp-ncce-token-rotator"
    $global:app2 = Get-OrCreate-AzApp -DisplayName $app2Name -IdentifierUriBase "https://$domain"

    $info = "AppName: $app2Name; Token Rotator Client ID: $($app2.AppId)"
    Write-Host "`t`t→ $info`n" -ForegroundColor Green
    $global:stepResults += @{ Name = "SP2: Create App"; Info = $info }
}

function TaskSP2CreateSP {
    Write-Host "`t⚙️ [Task] SP2 – Ensure Service Principal exists for App2..." -ForegroundColor Magenta

    Import-Module "$PSScriptRoot/Modules/AzureSpHelper.psm1" -Force -ErrorAction Stop -DisableNameChecking

    $global:sp2 = Get-OrCreate-AzServicePrincipal -AppId $global:app2.AppId

    $info = "AppName: $app2Name; Token Rotator Object ID: $($sp2.Id)"
    Write-Host "`t`t→ $info`n" -ForegroundColor Green
    $global:stepResults += @{ Name = "SP2: Create Service Principal"; Info = $info }
}

function TaskSP2CreateCredential {
    Write-Host "`t⚙️ [Task] SP2 – Ensure client secret exists for App2..." -ForegroundColor Magenta

    Import-Module "$PSScriptRoot/Modules/AzureSpHelper.psm1" -Force -ErrorAction Stop -DisableNameChecking

    $credInfo2 = Get-OrCreate-AzAppCredential -AppId $global:app2.AppId
    $global:plainPassword2 = $credInfo2.SecretText

    if ($plainPassword2) {
        $info = "AppName: $app2Name; New secret: $plainPassword2"
        Write-Host "`t`t→ $info`n" -ForegroundColor Red
    } else {
        $info = "AppName: $app2Name; Existing secret reused"
        Write-Host "`t`t→ $info`n" -ForegroundColor Green
    }

    $global:stepResults += @{ Name = "SP2: Create Credential"; Info = $info }
}

# --------------------------- SP1: Graph Permissions ---------------------------
function TaskSP1GraphPermission {
    Write-Host "`t🔐 [Task] SP1 – Grant Directory.ReadWrite.All via Graph..." -ForegroundColor Yellow

    # Helper-Modul für Graph-Berechtigungen laden
    Import-Module "$PSScriptRoot/Modules/GraphPermissionHelper.psm1" `
        -Force -ErrorAction Stop -DisableNameChecking

    # Wir übergeben hier die ObjectId der Azure AD Application (nicht die SP-Id)
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
    
    # App-Objekt ins Mg holen (falls nötig)
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

function TaskExportConfluenceDoc {
    Write-Host "`t📄 [Task] Exporting Confluence documentation..." -ForegroundColor Magenta

    Import-Module "$PSScriptRoot/Modules/ConfluenceDoc.generated.psm1" -Force -ErrorAction Stop

    $outputFile = "$PSScriptRoot/NCCE_Confluence_Documentation.md"
    Export-NcceConfluenceConfiguration `
        -TenantName $global:contexts.Azure.Tenant.Name `
        -OutputFile $outputFile

    Write-Host "`t✅ [Task] Confluence doc exported to: $outputFile`n" -ForegroundColor Green
    $global:stepResults += @{ Name = "Export Confluence Doc"; Info = "Documentation exported to $outputFile" }
}

# --------------------------- Main Execution & Workflow ---------------------------
Show-Banner

$steps = @(
    @{ Name = "Prepare Environment";                                            Action = { SetupEnvironment             } },
    @{ Name = "Login to Azure & Microsoft Graph";                               Action = { TaskInitAuth                 } },
    @{ Name = "Provisioner App: Create Application";                            Action = { TaskSP1CreateApp             } },
    @{ Name = "Provisioner App: Create Service Principal";                      Action = { TaskSP1CreateSP              } },
    @{ Name = "Provisioner App: Create Client Secret";                          Action = { TaskSP1CreateCredential      } },
    @{ Name = "Token Rotator App: Create Application";                          Action = { TaskSP2CreateApp             } },
    @{ Name = "Token Rotator App: Create Service Principal";                    Action = { TaskSP2CreateSP              } },
    @{ Name = "Token Rotator App: Create Client Secret";                        Action = { TaskSP2CreateCredential      } },
    @{ Name = "Provisioner: Grant Directory.ReadWrite.All Permission";          Action = { TaskSP1GraphPermission       } },
    @{ Name = "Provisioner: Assign Owner Role to Subscription";                 Action = { TaskSP1RBACOwner             } },
    @{ Name = "Provisioner: Create & Assign 'Subscription Provisioner' Role";   Action = { TaskSP1RBACCustomRole1       } },
    @{ Name = "Provisioner: Create & Assign 'Management Administrator' Role";   Action = { TaskSP1RBACCustomRole2       } },
    @{ Name = "Provisioner: Assign 'Application Administrator' Directory Role"; Action = { TaskSP1GraphDirRole          } },
    @{ Name = "Disconnect from Graph for your Safety";                          Action = { Disconnect-MgGraph     } }
)

$total = $steps.Count

for ($i = 0; $i -lt $total; $i++) {
    $stepIndex   = $i + 1
    $currentStep = $steps[$i].Name
    $percent     = [int]($stepIndex / $total * 100)

    # Show progress bar with percentage
    Write-Progress `
        -Id               1 `
        -Activity         "Cloud Engine Setup Progress: $percent% Complete" `
        -Status           "Step $stepIndex/$total – $currentStep" `
        -PercentComplete  $percent

    Write-Host "🎬 [Workflow] Starting: $currentStep" -ForegroundColor Cyan
    & $steps[$i].Action
    Write-Host "✅ [Workflow] Completed: $currentStep`n" -ForegroundColor Cyan
}

# Mark the progress as complete (clears the bar)
Write-Progress -Id 1 -Activity "☁️ NCCE Setup Progress" -Completed
# --------------------------- Summary ---------------------------
Write-Host "`n📑  Step Summary:" -ForegroundColor Cyan

# Determine padding based on the longest step name
$maxNameLength = ($global:stepResults | ForEach-Object { $_.Name.Length } | Measure-Object -Maximum).Maximum

foreach ($entry in $global:stepResults) {
    $paddedName = $entry.Name.PadRight($maxNameLength)

    # Green checkmark, white for name, gray separator, cyan for info
    Write-Host "  ✅ " -NoNewline -ForegroundColor Green
    Write-Host $paddedName -NoNewline -ForegroundColor White
    Write-Host " : " -NoNewline -ForegroundColor Gray
    Write-Host $entry.Info -ForegroundColor Cyan
}
Write-Host ""