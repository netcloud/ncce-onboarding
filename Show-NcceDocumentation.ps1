# Show-NcceDocumentation.ps1

# Load local module virtual environment
$VenvRoot = Join-Path $PSScriptRoot '.pwsh_venv'
$env:PSModulePath = "$VenvRoot;$env:PSModulePath"
foreach ($modDir in Get-ChildItem -Path $VenvRoot -Directory) {
    foreach ($verDir in Get-ChildItem -Path $modDir.FullName -Directory) {
        $psd1 = Join-Path $verDir.FullName "$($modDir.Name).psd1"
        if (Test-Path $psd1) {
            Import-Module $psd1 -Force -ErrorAction Stop
        }
    }
}

function Show-NcceDocumentation {
    # Separator line
    Write-Separator

    # Header
    Write-ColorOutput '### NCCE Onboarding Configuration Summary' 'Cyan'

    # Service Principals
    Write-Output '- sp-ncce-global-provisioner:'
    Write-Output '    - Application (Client) ID: ' + $app.AppId
    Write-Output '    - Service Principal (Object) ID: ' + $sp.Id
    Write-Output '- sp-ncce-token-rotator:'
    Write-Output '    - Application (Client) ID: ' + $trApp.AppId
    Write-Output '    - Service Principal (Object) ID: ' + $trSp.Id

    # Permissions
    Write-Output "`n### Permissions"
    Write-Output '- Microsoft Graph Application permission: Directory.ReadWrite.All'

    # Role Assignments
    Write-Output "`n### Role Assignments"
    Write-Output '- Owner role on subscription: /subscriptions/' + $subId
    Write-Output "- Custom role 'cr-subscription-provisioner' at Tenant Root Group"
    Write-Output "- Custom role 'cr-management-administrator' at Tenant Root Group"
    Write-Output "- Directory role 'Application Administrator'"

    # Separator line
    Write-Separator
}