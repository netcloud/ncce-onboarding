# Modules/ModuleVenvHelper/ModuleVenvHelper.psm1
# ──────────────────────────────────────────────────────────────────────────────
# Version-pinning helper (imports selected MS Graph sub-modules).
# Outputs are streamlined with a single [Venv] prefix for clarity.

$ErrorActionPreference = 'Stop'

# --------------------------- Module Inventory ---------------------------
$RequiredAzModules = @(
    @{ Name = 'Az.Resources'; Version = '8.0.0' },
    @{ Name = 'Az.Accounts';   Version = '5.0.2' }
)

$RequiredGraphModules = @(
    @{ Name = 'Microsoft.Graph.Authentication';   Version = '2.24.0' },
    @{ Name = 'Microsoft.Graph.Applications';     Version = '2.24.0' },
    @{ Name = 'Microsoft.Graph.DirectoryObjects'; Version = '2.24.0' },
    @{ Name = 'Microsoft.Graph.Identity.DirectoryManagement'; Version = '2.24.0' }
)

# Compute paths
$ModuleFilePath = $MyInvocation.MyCommand.Path
$ModuleFolder   = Split-Path -Path $ModuleFilePath -Parent
$RepoRoot       = Split-Path -Path $ModuleFolder -Parent
$VenvRoot       = Join-Path -Path $RepoRoot -ChildPath '.pwsh_venv'

# --------------------------- PRIVATE: Build Cache ---------------------------

function New-ModuleVenv {
    if (-not (Test-Path $VenvRoot)) {
        New-Item -ItemType Directory -Path $VenvRoot | Out-Null
    }

    Import-Module PowerShellGet -ErrorAction Stop

    foreach ($mod in $RequiredAzModules + $RequiredGraphModules) {
        Save-Module -Name            $mod.Name `
                    -RequiredVersion $mod.Version `
                    -Path            $VenvRoot `
                    -Force           `
                    -ErrorAction     Stop
    }
}

# --------------------------- PUBLIC: Enable Module Venv ---------------------------

function Enable-ModuleVenv {
    [CmdletBinding()]
    param(
        [switch]$Quiet
    )

    # Determine if cache needs building
    $needsBuild = $false
    if (-not (Test-Path $VenvRoot)) {
        $needsBuild = $true
    }
    else {
        # Ensure each required module folder exists
        foreach ($mod in $RequiredAzModules + $RequiredGraphModules) {
            $path = Join-Path -Path $VenvRoot -ChildPath "$($mod.Name)\$($mod.Version)"
            if (-not (Test-Path $path)) {
                $needsBuild = $true
                break
            }
        }
    }

    if ($needsBuild) {
        if (-not $Quiet) { Write-Host "[Venv] Building module cache at $VenvRoot..." -ForegroundColor Yellow }
        if (Test-Path $VenvRoot) {
            Remove-Item -Recurse -Force $VenvRoot
        }
        New-ModuleVenv
        if (-not $Quiet) { Write-Host "[Venv] Module cache built." -ForegroundColor Green }
    }
    elseif (-not $Quiet) {
        Write-Host "[Venv] Module cache already valid; skipping build." -ForegroundColor Green
    }

    # Prepend our cache path to PSModulePath
    $sep = [IO.Path]::PathSeparator
    $env:PSModulePath = "$VenvRoot$sep$env:PSModulePath"

    # Import each required module
    foreach ($mod in $RequiredAzModules + $RequiredGraphModules) {
        if (-not $Quiet) { Write-Host "[Venv] Importing $($mod.Name) v$($mod.Version)..." -ForegroundColor Yellow }
        Import-Module -Name $mod.Name -RequiredVersion $mod.Version -Force -ErrorAction Stop
    }

    if (-not $Quiet) { Write-Host "[Venv] All modules loaded from cache.`n" -ForegroundColor Green }
}

# --------------------------- PUBLIC: Get Loaded Module Info ---------------------------
function Get-LoadedModuleInfo {
    <#
    .SYNOPSIS
      Returns an array of PSCustomObjects containing Name and Version
      for each pinned module that is currently loaded.
    .OUTPUTS
      PSCustomObject with properties: Name, Version
    #>

    $result = @()
    foreach ($mod in $RequiredAzModules + $RequiredGraphModules) {
        $loaded = Get-Module -Name $mod.Name -ListAvailable | Where-Object { $_.Version.ToString() -eq $mod.Version }
        if ($loaded) {
            $result += [PSCustomObject]@{
                Name    = $mod.Name
                Version = $mod.Version
            }
        }
        else {
            $result += [PSCustomObject]@{
                Name    = $mod.Name
                Version = 'Not Loaded'
            }
        }
    }
    return $result
}

Export-ModuleMember -Function Enable-ModuleVenv, Get-LoadedModuleInfo
