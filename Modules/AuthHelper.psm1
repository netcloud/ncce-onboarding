# Modules/AuthHelper/AuthHelper.psm1
# ===================================
# Single function to handle both Azure + Microsoft Graph device‐code login.
# The function name uses an approved verb “Initialize”.

$ErrorActionPreference = 'Stop'

function Initialize-AuthContexts {
    <#
    .SYNOPSIS
      Initializes both Azure (Az) and Microsoft Graph (Mg) contexts, prompting
      for device‐code login if necessary. Returns a hashtable with keys “Azure”
      and “Graph” containing the corresponding context objects.
    #>

    # ------ Azure Login ------
    $azCtx = Get-AzContext -ErrorAction SilentlyContinue
    if (-not $azCtx) {
        Write-Host "[Auth] STEP 1 of 2: Azure Device-Code Login" -ForegroundColor Cyan

        # Show device-code prompt
        Connect-AzAccount -UseDeviceAuthentication -ErrorAction Stop

        # After successful login, retrieve context
        $azCtx = Get-AzContext -ErrorAction Stop
        Write-Host "[Auth] Azure login successful (Tenant: $($azCtx.Tenant.Id))" -ForegroundColor Green
    }
    else {
        Write-Host "[Auth] Azure already signed in (Tenant: $($azCtx.Tenant.Id))" -ForegroundColor Green
    }

    # ------ Graph Login ------
    $mgCtx = Get-MgContext -ErrorAction SilentlyContinue
    if (-not $mgCtx) {
        Write-Host "[Auth] STEP 2 of 2: Microsoft Graph Device-Code Login" -ForegroundColor Cyan

        $scopes = @(
            'Application.ReadWrite.All',
            'Directory.ReadWrite.All',
            'AppRoleAssignment.ReadWrite.All',
            'RoleManagement.ReadWrite.Directory'
        )
        Connect-MgGraph -Scopes $scopes -DeviceCode -NoWelcome -ErrorAction Stop | Out-Host
        $mgCtx = Get-MgContext -ErrorAction Stop
        Write-Host "[Auth] Microsoft Graph login successful" -ForegroundColor Green
    }
    else {
        Write-Host "[Auth] Microsoft Graph already signed in" -ForegroundColor Green
    }

    return @{ Azure = $azCtx; Graph = $mgCtx }
}

Export-ModuleMember -Function Initialize-AuthContexts
