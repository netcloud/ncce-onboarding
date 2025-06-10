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
        [Parameter(Mandatory)][string]$TenantId,       # e.g. “<tenant-guid>”
        [Parameter(Mandatory)][string]$JsonDefinition  # The JSON string for the role
    )

    # Output: returns role object or throws
    $existingRole = Get-AzRoleDefinition -Name $RoleName -ErrorAction SilentlyContinue
    $tmp = [IO.Path]::GetTempFileName() + ".json"
    $JsonDefinition | Out-File -FilePath $tmp -Encoding utf8

    if ($existingRole) {
        # Capture existing assignments
        $assignments = Get-AzRoleAssignment -RoleDefinitionName $RoleName -ErrorAction SilentlyContinue
        foreach ($a in $assignments) {
            Remove-AzRoleAssignment -ObjectId $a.ObjectId -RoleDefinitionName $RoleName -Scope $a.Scope -ErrorAction SilentlyContinue | Out-Null
        }
        # Prepare updated JSON with existing Role Id
        $roleObj = ConvertFrom-Json $JsonDefinition
        $roleObj | Add-Member -MemberType NoteProperty -Name Id -Value $existingRole.Id
        $roleObj | ConvertTo-Json -Depth 10 | Out-File -FilePath $tmp -Encoding utf8
        # Update role definition
        Set-AzRoleDefinition -InputFile $tmp -ErrorAction Stop | Out-Null
        Write-Host "Custom role '$RoleName' updated." -ForegroundColor Green
        # Reassign to previous principals
        foreach ($a in $assignments) {
            New-AzRoleAssignment -ObjectId $a.ObjectId -RoleDefinitionName $RoleName -Scope $a.Scope | Out-Null
        }
        Remove-Item $tmp -ErrorAction SilentlyContinue
        return Get-AzRoleDefinition -Name $RoleName
    }
    else {
        # Create new custom role
        $newRole = New-AzRoleDefinition -InputFile $tmp -ErrorAction Stop
        Write-Host "Custom role '$RoleName' created." -ForegroundColor Green
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
