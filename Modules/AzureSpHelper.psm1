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

Export-ModuleMember -Function Get-OrCreate-AzApp, Get-OrCreate-AzServicePrincipal, Get-OrCreate-AzAppCredential
