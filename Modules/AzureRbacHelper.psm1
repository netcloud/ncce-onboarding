# AzureRbacHelper.psm1

$ErrorActionPreference = 'Stop'

# Utility: Check that a service principal actually exists in the directory.
function Test-ServicePrincipalExists {
    param(
        [Parameter(Mandatory)][string]$ObjectId
    )
    return (Get-AzADServicePrincipal -ObjectId $ObjectId -ErrorAction SilentlyContinue) -ne $null
}
function Use-AzContextForScope {
    param(
        [Parameter(Mandatory)][string]$Scope,
        [string]$TenantId = $(Get-AzContext).Tenant.Id
    )

    # Extract subscriptionId if the scope contains it
    if ($Scope -match '/subscriptions/([0-9a-fA-F-]{36})') {
        $subId = $Matches[1]
        $ctx = Get-AzContext
        if ($ctx.Subscription.Id -ne $subId) {
            Select-AzSubscription -SubscriptionId $subId -TenantId $TenantId -ErrorAction Stop | Out-Null
        }
    }
}

function Add-AzRoleAssignment {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$ObjectId,             # SP ObjectId
        [Parameter(Mandatory)][string]$RoleDefinitionName,   # Role name (built‑in or custom)
        [Parameter(Mandatory)][string]$Scope,                # e.g. "/subscriptions/<subId>"
        [string]$TenantId = $(Get-AzContext).Tenant.Id
    )

    # Validate principal
    if (-not (Test-ServicePrincipalExists -ObjectId $ObjectId)) {
        Write-Warning "Skip assignment: principal $ObjectId not found."
        return
    }

    # Pin context to correct subscription
    Use-AzContextForScope -Scope $Scope -TenantId $TenantId

    # Resolve role definition and always work with its GUID
    $role = Get-AzRoleDefinition -Name $RoleDefinitionName -ErrorAction Stop |
            Select-Object -First 1
    if (-not $role) {
        throw "Role '$RoleDefinitionName' not found."
    }

    # Check for an active assignment (ignore deleted/orphaned)
    $existing = Get-AzRoleAssignment -ObjectId $ObjectId -Scope $Scope -ErrorAction SilentlyContinue |
                Where-Object { $_.RoleDefinitionId -eq $role.Id -and -not $_.DeletedDateTime }
    if ($existing) {
        return
    }

    # Assign with retry back‑off (handles transient 400/409)
    $maxAttempts = 5
    for ($i = 1; $i -le $maxAttempts; $i++) {
        try {
            New-AzRoleAssignment -ObjectId $ObjectId -RoleDefinitionId $role.Id -Scope $Scope -ErrorAction Stop | Out-Null
            Write-Host "Assigned role '$RoleDefinitionName' to $ObjectId." -ForegroundColor Green
            break
        } catch {
            if ($i -eq $maxAttempts) { throw }
            Write-Host "Attempt $i failed: $($_.Exception.Message) – retrying in $([int]($i*5)) s" -ForegroundColor Yellow
            Start-Sleep -Seconds ($i*5)
        }
    }
}

# ---------------------------------------------------------------------------
# Add a *custom* role definition and return it – idempotent update version
function Add-AzCustomRole {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$RoleName,
        [Parameter(Mandatory)][string]$TenantId,
        [Parameter(Mandatory)][string]$JsonDefinition
    )

    # Write JSON spec to a temp file
    $tmp = [IO.Path]::GetTempFileName() + ".json"
    $JsonDefinition | Out-File -FilePath $tmp -Encoding utf8

    $role = Get-AzRoleDefinition -Name $RoleName -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($role) {
        # Keep existing assignments – just update the definition
        # Inject existing Id so Set-AzRoleDefinition performs an update
        $obj = ConvertFrom-Json $JsonDefinition
        $obj | Add-Member -MemberType NoteProperty -Name Id -Value $role.Id -Force
        $obj | ConvertTo-Json -Depth 10 | Out-File $tmp -Encoding utf8
        Set-AzRoleDefinition -InputFile $tmp -ErrorAction Stop | Out-Null
        Write-Host "Custom role '$RoleName' updated." -ForegroundColor Green
        Remove-Item $tmp -ErrorAction SilentlyContinue
        return (Get-AzRoleDefinition -Id $role.Id)
    }
    else {
        $newRole = New-AzRoleDefinition -InputFile $tmp -ErrorAction Stop
        Write-Host "Custom role '$RoleName' created." -ForegroundColor Green
        Remove-Item $tmp -ErrorAction SilentlyContinue
        return $newRole
    }
}

# ---------------------------------------------------------------------------
# Assign a *custom* role (by name) safely
function Add-CustomRoleAssignment {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$ObjectId,
        [Parameter(Mandatory)][string]$RoleName,
        [Parameter(Mandatory)][string]$Scope,
        [string]$TenantId = $(Get-AzContext).Tenant.Id
    )

    # Validate principal
    if (-not (Test-ServicePrincipalExists -ObjectId $ObjectId)) {
        Write-Warning "Skip assignment: principal $ObjectId not found."
        return
    }

    # Pin context
    Use-AzContextForScope -Scope $Scope -TenantId $TenantId

    # Resolve role definition
    $role = Get-AzRoleDefinition -Name $RoleName -ErrorAction Stop | Select-Object -First 1
    if (-not $role) { throw "Role '$RoleName' not found." }

    # Reuse generic function above
    Add-AzRoleAssignment -ObjectId $ObjectId -RoleDefinitionName $RoleName -Scope $Scope -TenantId $TenantId
}

Export-ModuleMember -Function Test-ServicePrincipalExists, Use-AzContextForScope, Add-AzRoleAssignment,  Add-AzCustomRole, Add-CustomRoleAssignment
