# GraphPermissionHelper.psm1

$ErrorActionPreference = 'Stop'

function Add-GraphAppPermission {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$AppObjectId,    # ObjectId der AAD-Application
        [Parameter(Mandatory)][string]$GraphAppId,     # i.d.R. "00000003-0000-0000-c000-000000000000"
        [Parameter(Mandatory)][string]$PermissionValue # z.B. "Directory.ReadWrite.All"
    )

    # 1) Microsoft Graph Service Principal holen
    $graphSp = Get-MgServicePrincipal -Filter "AppId eq '$GraphAppId'"
    if (-not $graphSp) {
        throw "Cannot find Microsoft Graph Service Principal (AppId: $GraphAppId)"
    }

    # 2) AppRole im Graph-Katalog suchen
    $appRole = $graphSp.AppRoles | Where-Object { $_.Value -eq $PermissionValue }
    if (-not $appRole) {
        throw "Cannot find Graph AppRole for '$PermissionValue'"
    }

     # 3) AAD-Application via direkte ID-Abfrage (mit Retry, falls noch nicht vollständig propagiert)
    $mgApp       = $null
    $maxAttempts = 100

    for ($attempt = 1; $attempt -le $maxAttempts; $attempt++) {
        try {
            # Direkter Abruf per ApplicationId (um Filter-Probleme zu vermeiden)
            $mgApp = Get-MgApplication -ApplicationId $AppObjectId -ErrorAction Stop
            if ($mgApp) { break }
        }
        catch {
            # Wenn 404 oder NotFound, 2 Sek warten und erneut versuchen
            Start-Sleep -Seconds 2
        }
    }
    if (-not $mgApp) {
        throw "Cannot find Graph Application by ObjectId '$AppObjectId' after $maxAttempts attempts."
    }

    # 4) Prüfen, ob bereits ein RequiredResourceAccess-Eintrag für Graph existiert
    $existingRRA = $mgApp.RequiredResourceAccess |
                   Where-Object { $_.ResourceAppId -eq $graphSp.AppId }

    if ($existingRRA) {
        $already = $existingRRA.ResourceAccess |
                   Where-Object { $_.Id -eq $appRole.Id -and $_.Type -eq "Role" }
        if ($already) {
            return  # Berechtigung schon gesetzt, nichts zu tun
        }

        # ResourceAccess-Liste erweitern
        $updatedAccess = $existingRRA.ResourceAccess + @{
            Id   = $appRole.Id
            Type = "Role"
        }

        # Neues RequiredResourceAccess-Array zusammenbauen
        $newRRA = $mgApp.RequiredResourceAccess | ForEach-Object {
            if ($_.ResourceAppId -eq $graphSp.AppId) {
                @{
                    ResourceAppId   = $_.ResourceAppId
                    ResourceAccess  = $updatedAccess
                }
            }
            else {
                $_
            }
        }
    }
    else {
        # Kein bestehender Eintrag für Graph vorhanden → neu anlegen
        $newEntry = @{
            ResourceAppId  = $graphSp.AppId
            ResourceAccess = @(@{
                Id   = $appRole.Id
                Type = "Role"
            })
        }
        $newRRA = @($newEntry) + $mgApp.RequiredResourceAccess
    }

    # 5) Application aktualisieren (RequiredResourceAccess)
    Update-MgApplication -ApplicationId $mgApp.Id -RequiredResourceAccess $newRRA

    # 6) AppRoleAssignment (Admin Consent) vergeben
    #    Dazu brauchen wir das ServicePrincipal-Objekt der soeben
    #    geänderten Application – wir filtern nach AppId (ClientId).
    $mgSp = Get-MgServicePrincipal -Filter "AppId eq '$($mgApp.AppId)'" -ErrorAction Stop

    $params = @{
        PrincipalId = $mgSp.Id
        ResourceId  = $graphSp.Id
        AppRoleId   = $appRole.Id
    }

    try {
        New-MgServicePrincipalAppRoleAssignment `
            -ServicePrincipalId $mgSp.Id `
            -BodyParameter $params `
            -ErrorAction Stop
    }
    catch {
        # Falls "already exists", ignorieren, sonst weiterwerfen
        if ($_.Exception.Message -notmatch 'already exists') {
            throw $_
        }
    }
}

Export-ModuleMember -Function Add-GraphAppPermission
