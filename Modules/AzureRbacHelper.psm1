# AzureRbacHelper.psm1

$ErrorActionPreference = 'Stop'

function Add-AzRoleAssignment {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$ObjectId,             # SP ObjectId
        [Parameter(Mandatory)][string]$RoleDefinitionName,   # e.g. "Owner"
        [Parameter(Mandatory)][string]$Scope                   # e.g. "/subscriptions/<subId>"
    )

    $existing = Get-AzRoleAssignment -ObjectId $ObjectId `
                                     -RoleDefinitionName $RoleDefinitionName `
                                     -Scope $Scope `
                                     -ErrorAction SilentlyContinue
    if ($existing) {
        return
    }

    New-AzRoleAssignment -ObjectId $ObjectId -RoleDefinitionName $RoleDefinitionName -Scope $Scope
}

function Add-AzCustomRole {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$RoleName,
        [Parameter(Mandatory)][string]$TenantId,
        [Parameter(Mandatory)][string]$JsonDefinition
    )

    # Create a temporary JSON file
    $tmp = [IO.Path]::GetTempFileName() + ".json"
    $JsonDefinition | Out-File -FilePath $tmp -Encoding utf8

    # Check for existing role definition
    $existingRole = Get-AzRoleDefinition -Name $RoleName -ErrorAction SilentlyContinue

    if ($existingRole) {
        # Backup and remove current assignments
        $assignments = Get-AzRoleAssignment -RoleDefinitionName $RoleName -ErrorAction SilentlyContinue
        foreach ($a in $assignments) {
            Remove-AzRoleAssignment -ObjectId $a.ObjectId -RoleDefinitionName $RoleName -Scope $a.Scope -ErrorAction SilentlyContinue | Out-Null
        }

        # Update JSON to include existing role Id
        $roleObj = ConvertFrom-Json $JsonDefinition
        $roleObj | Add-Member -MemberType NoteProperty -Name Id -Value $existingRole.Id
        $roleObj | ConvertTo-Json -Depth 10 | Out-File -FilePath $tmp -Encoding utf8

        # Update the role definition
        Set-AzRoleDefinition -InputFile $tmp -ErrorAction Stop | Out-Null
        Write-Host "Custom role '$RoleName' updated." -ForegroundColor Green

        # Wait for propagation
        Write-Host "Waiting for role propagation..." -ForegroundColor Cyan
        Start-Sleep -Seconds 30

        # Fetch the updated role definition once
        $updatedRole = Get-AzRoleDefinition -Name $RoleName -ErrorAction Stop

        # Reassign to principals with retries using the updated role Id
        $maxAttempts = 5; $delay = 10
        foreach ($a in $assignments) {
            $attempt = 1
            while ($attempt -le $maxAttempts) {
                try {
                    New-AzRoleAssignment -ObjectId $a.ObjectId -RoleDefinitionId $updatedRole.Id -Scope $a.Scope -ErrorAction Stop | Out-
                    Write-Host "Assigned role to $($a.ObjectId) on attempt $attempt." -ForegroundColor Green
                    break
                } catch {
                    if ($attempt -lt $maxAttempts) {
                        Write-Host "Assignment attempt $attempt failed (${($_.Exception.Message)}), waiting $delay seconds..." -ForegroundColor Yellow
                        Start-Sleep -Seconds $delay
                        $attempt++
                    } else {
                        throw "Failed to assign role to $($a.ObjectId) after $maxAttempts attempts: $($_.Exception.Message)"
                    }
                }
            }
        }

        Remove-Item $tmp -ErrorAction SilentlyContinue
        return $updatedRole
    }
    else {
        # Create a new custom role
        $newRole = New-AzRoleDefinition -InputFile $tmp -ErrorAction Stop
        Write-Host "New custom role '$RoleName' created." -ForegroundColor Green

        # Wait for propagation
        Write-Host "Waiting for role propagation..." -ForegroundColor Cyan
        Start-Sleep -Seconds 30

        Remove-Item $tmp -ErrorAction SilentlyContinue
        return $newRole
    }
}


function Add-CustomRoleAssignment {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$ObjectId,            # SP ObjectId
        [Parameter(Mandatory)][string]$RoleName,            # Already-created role name
        [Parameter(Mandatory)][string]$Scope                # e.g. "/providers/Microsoft.Management/managementGroups/<tenant-guid>"
    )

    $existing = Get-AzRoleAssignment -ObjectId $ObjectId `
                                     -RoleDefinitionName $RoleName `
                                     -Scope $Scope `
                                     -ErrorAction SilentlyContinue
    if ($existing) {
        return
    }

    New-AzRoleAssignment -ObjectId $ObjectId -RoleDefinitionName $RoleName -Scope $Scope 
}

Export-ModuleMember -Function Add-AzRoleAssignment, Add-AzCustomRole, Add-CustomRoleAssignment
