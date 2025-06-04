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

    New-AzRoleAssignment -ObjectId $ObjectId -RoleDefinitionName $RoleDefinitionName -Scope $Scope | Out-Null
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
    if ($existingRole) {
        return $existingRole
    }

    # Create a temporary file for JSON
    $tmp = [IO.Path]::GetTempFileName() + ".json"
    $JsonDefinition | Out-File -FilePath $tmp -Encoding utf8

    $newRole = New-AzRoleDefinition -InputFile $tmp -ErrorAction Stop
    Remove-Item $tmp -ErrorAction SilentlyContinue
    return $newRole
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

    New-AzRoleAssignment -ObjectId $ObjectId -RoleDefinitionName $RoleName -Scope $Scope | Out-Null
}

Export-ModuleMember -Function Add-AzRoleAssignment, Add-AzCustomRole, Add-CustomRoleAssignment
