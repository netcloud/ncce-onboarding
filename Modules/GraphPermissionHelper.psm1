# GraphPermissionHelper.psm1

$ErrorActionPreference = 'Stop'

function Add-GraphAppPermission {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$AppObjectId,   # Graph “Id” (GUID) from Get-MgApplication
        [Parameter(Mandatory)][string]$GraphAppId,    # Typically "00000003-0000-0000-c000-000000000000"
        [Parameter(Mandatory)][string]$PermissionValue # For example, "Directory.ReadWrite.All"
    )

    # 1) Find Microsoft Graph service principal
    $graphSp = Get-MgServicePrincipal -Filter "AppId eq '$GraphAppId'"
    if (-not $graphSp) {
        throw "Cannot find Microsoft Graph Service Principal (AppId: $GraphAppId)"
    }

    # 2) Find the AppRole ID for the requested permission
    $appRole = $graphSp.AppRoles | Where-Object { $_.Value -eq $PermissionValue }
    if (-not $appRole) {
        throw "Cannot find Graph AppRole for '$PermissionValue'"
    }

    # 3) Get the existing MgApplication object
    $mgApp = Get-MgApplication -Filter "Id eq '$AppObjectId'"
    if (-not $mgApp) {
        throw "Cannot find Graph Application by ObjectId $AppObjectId"
    }

    # 4) Determine if RequiredResourceAccess entry exists
    $existingRRA = $mgApp.RequiredResourceAccess | 
                   Where-Object { $_.ResourceAppId -eq $graphSp.AppId }

    if ($existingRRA) {
        $already = $existingRRA.ResourceAccess | 
                   Where-Object { $_.Id -eq $appRole.Id -and $_.Type -eq "Role" }
        if ($already) {
            return  # nothing to do
        }

        # Add new ResourceAccess entry
        $updatedAccess = $existingRRA.ResourceAccess + @{
            Id   = $appRole.Id
            Type = "Role"
        }

        # Reconstruct RequiredResourceAccess array
        $newRRA = $mgApp.RequiredResourceAccess | ForEach-Object {
            if ($_.ResourceAppId -eq $graphSp.AppId) {
                @{
                    ResourceAppId = $_.ResourceAppId
                    ResourceAccess = $updatedAccess
                }
            }
            else {
                $_
            }
        }
    }
    else {
        # No existing entry for Graph: create one
        $newEntry = @{
            ResourceAppId = $graphSp.AppId
            ResourceAccess = @(@{
                Id   = $appRole.Id
                Type = "Role"
            })
        }

        $newRRA = @($newEntry) + $mgApp.RequiredResourceAccess
    }

    # 5) Update the application
    Update-MgApplication -ApplicationId $mgApp.Id -RequiredResourceAccess $newRRA

    # 6) Grant admin consent via app role assignment
    $mgSp = Get-MgServicePrincipal -Filter "AppId eq '$($mgApp.AppId)'"
    $params = @{
        PrincipalId = $mgSp.Id
        ResourceId  = $graphSp.Id
        AppRoleId   = $appRole.Id
    }

    try {
        New-MgServicePrincipalAppRoleAssignment -ServicePrincipalId $mgSp.Id -BodyParameter $params -ErrorAction Stop
    }
    catch {
        # If error indicates “already exists,” ignore
        if ($_.Exception.Message -notmatch 'already exists') {
            throw $_
        }
    }
}

Export-ModuleMember -Function Add-GraphAppPermission
