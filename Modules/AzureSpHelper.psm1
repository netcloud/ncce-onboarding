# AzureSpHelper.psm1

$ErrorActionPreference = 'Stop'

function Get-OrCreate-AzApp {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$DisplayName,
        [Parameter(Mandatory)][string]$IdentifierUriBase,
        [ValidateSet('AzureADMyOrg','AzureADMultipleOrgs')][string]$Audience = 'AzureADMyOrg'
    )

    $app = Get-AzADApplication -DisplayName $DisplayName -ErrorAction SilentlyContinue
    if ($app) { return $app }

    $app = New-AzADApplication -DisplayName $DisplayName \
                               -IdentifierUris "$IdentifierUriBase/$DisplayName" \
                               -SignInAudience $Audience
    return $app
}

function Get-OrCreate-AzServicePrincipal {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$AppId
    )

    # 1) Try to find SP by AppId
    $sp = Get-AzADServicePrincipal -ApplicationId $AppId -ErrorAction SilentlyContinue
    if ($sp) {
        return $sp
    }

    # 2) Create new SP
    $sp = New-AzADServicePrincipal -ApplicationId $AppId
    return $sp
}

function Get-OrCreate-AzAppCredential {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$AppId,
        [DateTime]$EndDate = (Get-Date).AddYears(1)
    )

    # 1) Check existing credentials
    $creds = Get-AzADAppCredential -ApplicationId $AppId -ErrorAction SilentlyContinue
    if ($creds -and $creds.Count -gt 0) {
        return @{ SecretText = $null; NewSecret = $false }
    }

    # 2) Create one new secret
    $pwdCred = New-AzADAppCredential -ApplicationId $AppId -EndDate $EndDate
    return @{ SecretText = $pwdCred.SecretText; NewSecret = $true }
}

Export-ModuleMember -Function Get-OrCreate-AzApp, Get-OrCreate-AzServicePrincipal, Get-OrCreate-AzAppCredential
