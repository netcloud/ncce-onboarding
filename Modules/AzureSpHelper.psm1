# AzureSpHelper.psm1

$ErrorActionPreference = 'Stop'

function Get-OrCreate-AzApp {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$DisplayName,
        [string]$IdentifierUriBase,   # now optional
        [ValidateSet('AzureADMyOrg','AzureADMultipleOrgs')][string]$Audience = 'AzureADMyOrg'
    )

    $app = Get-AzADApplication -DisplayName $DisplayName -ErrorAction SilentlyContinue
    if ($app) { return $app }

    $params = @{ DisplayName = $DisplayName; SignInAudience = $Audience }

    if ($IdentifierUriBase) {
        if ($IdentifierUriBase -like 'api://*') {
            # Use exactly the provided api:// GUID without appending the name
            $params.IdentifierUris = $IdentifierUriBase
        } else {
            $params.IdentifierUris = ($IdentifierUriBase.TrimEnd('/') + '/' + $DisplayName)
        }
    }

    return New-AzADApplication @params
}


function Get-OrCreate-AzServicePrincipal {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$AppId)
    $sp = Get-AzADServicePrincipal -ApplicationId $AppId -ErrorAction SilentlyContinue
    if ($sp) { return $sp }
    return New-AzADServicePrincipal -ApplicationId $AppId
}

function Get-OrCreate-AzAppCredential {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$AppId,[DateTime]$EndDate = (Get-Date).AddYears(1))
    $creds = Get-AzADAppCredential -ApplicationId $AppId -ErrorAction SilentlyContinue
    if ($creds -and $creds.Count -gt 0) { return @{ SecretText = $null; NewSecret = $false } }
    $pwdCred = New-AzADAppCredential -ApplicationId $AppId -EndDate $EndDate
    return @{ SecretText = $pwdCred.SecretText; NewSecret = $true }
}

function Ensure-AppApiUriAndScope {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$AppObjectId,   # Graph objectId
        [Parameter(Mandatory)][string]$AppId,         # clientId (guid)
        [string]$ScopeName = 'user_impersonation',
        [string]$ScopeDisplayName = 'Access Token Rotator API',
        [string]$ScopeDescription = 'Allow the app to access the Token Rotator API on your behalf'
    )

    # Wait until app is visible in Graph
    $mgApp = Get-MgApplicationEventually -ObjectId $AppObjectId -AppId $AppId
    $desiredIdUri = "api://$AppId"

    $needsUri = -not ($mgApp.IdentifierUris -contains $desiredIdUri)

    # Existing scopes (if any)
    $scopes = @()
    if ($mgApp.Api -and $mgApp.Api.Oauth2PermissionScopes) {
        $scopes = @($mgApp.Api.Oauth2PermissionScopes)
    }

    $scopeExists = $false
    foreach ($s in $scopes) {
        if ($s.Value -eq $ScopeName -and $s.IsEnabled) { $scopeExists = $true; break }
    }

    if (-not $scopeExists) {
        $scopes = $scopes + @{
            id                      = [guid]::NewGuid()
            value                   = $ScopeName
            type                    = 'User'    # delegated permission
            adminConsentDisplayName = $ScopeDisplayName
            adminConsentDescription = $ScopeDescription
            isEnabled               = $true
        }
    }

    if ($needsUri -or -not $scopeExists) {
        $body = @{
            identifierUris = @($desiredIdUri)
            api = @{
                oauth2PermissionScopes = $scopes
            }
        }
        Update-MgApplication -ApplicationId $mgApp.Id -BodyParameter $body | Out-Null
    }

    return $desiredIdUri
}


Export-ModuleMember -Function Get-OrCreate-AzApp, Get-OrCreate-AzServicePrincipal, Get-OrCreate-AzAppCredential, Ensure-AppApiUriAndScope
