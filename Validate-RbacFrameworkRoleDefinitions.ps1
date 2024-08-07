Param(
    [Parameter(Mandatory=$True)]
    [ValidateNotNullOrEmpty()]
    [String]$SubscriptionId,
    [Parameter(Mandatory=$True)]
    [Object[]]$RoleAssignments,
    [Parameter(Mandatory=$False)]
    [Hashtable]$ResourceRoleDefinitionMap = @{},
    [Parameter(Mandatory=$False)]
    [Hashtable]$CustomResourceRoleDefinitionMap = @{}
)

$NeededRoles = $RoleAssignments `
    | Where-Object { $_.Scope -like "/subscriptions/*" } `
    | Select-Object @{Name="RoleDefinitionName";Expression={
        if ( $_.Scope.Split("/").Count -ge 9 -and $_.RoleDefinitionName -in @("Owner", "Contributor", "Reader") ) {
            "$($_.Scope.split("/")[6..7] -join "/") $($_.RoleDefinitionName)"
        } else {
            $_.RoleDefinitionName
        }
    }} -Unique `
    | Select-Object @{Name="RoleDefinitionName";Expression={
        if ( $_.RoleDefinitionName -in $CustomResourceRoleDefinitionMap.Keys  ) {
            $CustomResourceRoleDefinitionMap[$_.RoleDefinitionName]
        } elseif ( $_.RoleDefinitionName -in $ResourceRoleDefinitionMap.Keys ) {
            $ResourceRoleDefinitionMap[$_.RoleDefinitionName]
        } else {
            $_.RoleDefinitionName
        }
    }} -Unique `
    | Sort-Object RoleDefinitionName

$RoleDefinitions = Get-AzRoleDefinition -Scope "/subscriptions/$($SubscriptionId)"
$MissingRoles = $NeededRoles | Where-Object { $_.RoleDefinitionName -notin $RoleDefinitions.Name }

if ( $null -ne $MissingRoles -and $MissingRoles.Count -gt 0 ) {
    Write-Host "Role Definitions Missing:" -ForegroundColor Yellow
    return $MissingRoles.RoleDefinitionName
} else {
    Write-Host "Success! Role Definitions Validated!" -ForegroundColor Green
    return $null
}
