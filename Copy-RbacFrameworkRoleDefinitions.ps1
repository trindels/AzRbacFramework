Param(
    [Parameter(Mandatory=$True)]
    [string]$SourceSubscriptionId,
    [Parameter(Mandatory=$True)]
    [string]$TargetSubscriptionId,
    [Parameter(Mandatory=$False)]
    [switch]$WhatIf = $False
)

$errors = $False

$subList = Get-AzContext -ListAvailable -ErrorAction SilentlyContinue
if ( $null -eq $subList ) {
    Write-Error "Please Connect to Azure Powershell (Connect-AzAccount) before running this script."
    exit
}
elseif ( $SourceSubscriptionId -notin $subList.Subscription.Id ) {
    Write-Error "Subscription $SourceSubscriptionId not found."
    exit
}
elseif ( $TargetSubscriptionId -notin $subList.Subscription.Id ) {
    Write-Error "Subscription $TargetSubscriptionId not found."
    exit
}

$missingCustomRoles = Get-AzRoleDefinition `
    -Scope "/subscriptions/$($SourceSubscriptionId)" `
    -Custom `
    -ErrorAction SilentlyContinue `
    | Where-Object { $_.AssignableScopes -contains "/subscriptions/$($SourceSubscriptionId)" }
    | Where-Object { $_.AssignableScopes -notcontains "/subscriptions/$($TargetSubscriptionId)" }


foreach ( $role in $missingCustomRoles ) {
    if ( -not $WhatIf ) {
        $role.AssignableScopes += "/subscriptions/$($TargetSubscriptionId)"
        try {
            $role | Set-AzRoleDefinition -ErrorAction Stop
            Write-Host "Copied Custom Role $($role.Name) to Subscription $TargetSubscriptionId"
        } catch {
            Write-Error "Failed to Copy Custom Role $($role.Name) to Subscription $TargetSubscriptionId"
            $errors = $true
        }
    } else {
        Write-Host "Missing Custom Role $($role.Name) in Subscription $TargetSubscriptionId" -ForegroundColor Yellow
    }
}

if ( $missingCustomRoles.Count -eq 0 ) {
    Write-Host "No Custom Roles to Copy to Subscription $TargetSubscriptionId" -ForegroundColor Green
} elseif ( -not $WhatIf ) {
    if ( $errors ) {
        Write-Host "Complete with Errors!" -ForegroundColor Yellow
    } else {
        Write-Host "Complete!" -ForegroundColor Green
    }
}