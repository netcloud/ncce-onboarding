# Modules/AuthHelper/AuthHelper.psm1
$ErrorActionPreference = 'Stop'
function Initialize-AuthContexts {
    $azCtx = Get-AzContext -ErrorAction SilentlyContinue
    if (-not $azCtx) {
        Write-Host "[Auth] STEP 1 of 2: Azure Device-Code Login" -ForegroundColor Cyan
        Connect-AzAccount -UseDeviceAuthentication -ErrorAction Stop
        $azCtx = Get-AzContext -ErrorAction Stop
        Write-Host "[Auth] Azure login successful (Tenant: $($azCtx.Tenant.Id))" -ForegroundColor Green
    } else {
        Write-Host "[Auth] Azure already signed in (Tenant: $($azCtx.Tenant.Id))" -ForegroundColor Green
    }

    $requiredScopes = @(
        'Application.ReadWrite.All',
        'Directory.ReadWrite.All',
        'AppRoleAssignment.ReadWrite.All',
        'RoleManagement.ReadWrite.Directory'
    )

    $mgCtx = Get-MgContext -ErrorAction SilentlyContinue
    $needReconnect = $true
    if ($mgCtx) {
        # Reuse if same tenant and scopes present
        $hasScopes = ($mgCtx.Scopes | Sort-Object) -join ',' -match (($requiredScopes | Sort-Object) -join '.*')
        if ($mgCtx.TenantId -eq $azCtx.Tenant.Id -and $hasScopes) { $needReconnect = $false }
    }
    if ($needReconnect) {
        Write-Host "[Auth] STEP 2 of 2: Microsoft Graph Device-Code Login" -ForegroundColor Cyan
        Connect-MgGraph -TenantId $azCtx.Tenant.Id -Scopes $requiredScopes -DeviceCode -NoWelcome -ErrorAction Stop | Out-Host
        $mgCtx = Get-MgContext -ErrorAction Stop
        Write-Host "[Auth] Microsoft Graph login successful" -ForegroundColor Green
    } else {
        Write-Host "[Auth] Microsoft Graph already signed in (tenant match, scopes OK)" -ForegroundColor Green
    }

    return @{ Azure = $azCtx; Graph = $mgCtx }
}

Export-ModuleMember -Function Initialize-AuthContexts
