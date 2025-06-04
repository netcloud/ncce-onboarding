# GraphDirectoryRoleHelper.psm1

$ErrorActionPreference = 'Stop'

function Add-GraphDirectoryRoleAssignment {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$RoleDisplayName,  # e.g. "Application Administrator"
        [Parameter(Mandatory)][string]$ServicePrincipalId
    )

    # 1) Attempt to find the directory role
    $dirRole = Get-MgDirectoryRole -Filter "DisplayName eq '$RoleDisplayName'" -ErrorAction SilentlyContinue
    if (-not $dirRole) {
        # 1a) Activate it if we find the template
        $template = Get-MgDirectoryRoleTemplate -Filter "DisplayName eq '$RoleDisplayName'"
        if (-not $template) {
            throw "Cannot find directory role template for '$RoleDisplayName'"
        }

        try {
            $dirRole = New-MgDirectoryRole -BodyParameter @{ roleTemplateId = $template.Id } -ErrorAction Stop
        }
        catch {
            # If “conflicting object” means it already exists but wasn’t returned above, re-fetch
            if ($_.Exception.Message -match 'conflicting') {
                Start-Sleep -Seconds 2
                $dirRole = Get-MgDirectoryRole -Filter "DisplayName eq '$RoleDisplayName'" -ErrorAction Stop
            }
            else {
                throw $_
            }
        }
    }

    # 2) Check if SP is already member
    $members = Get-MgDirectoryRoleMember -DirectoryRoleId $dirRole.Id -ErrorAction SilentlyContinue
    $exists = $members | Where-Object { $_.Id -eq $ServicePrincipalId }
    if ($exists) {
        return
    }

    # 3) Add SP to role
    $body = @{ '@odata.id' = "https://graph.microsoft.com/v1.0/directoryObjects/$ServicePrincipalId" }
    try {
        New-MgDirectoryRoleMemberByRef -DirectoryRoleId $dirRole.Id -BodyParameter $body -ErrorAction Stop
    }
    catch {
        # If it already exists or bad request, ignore
        if ($_.Exception.Message -notmatch 'already exists' -and $_.Exception.Message -notmatch 'Request_BadRequest') {
            throw $_
        }
    }
}

Export-ModuleMember -Function Add-GraphDirectoryRoleAssignment
