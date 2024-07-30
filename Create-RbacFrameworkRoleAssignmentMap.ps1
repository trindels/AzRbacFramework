Param(
    [Parameter(Mandatory=$True)]
    [Microsoft.Azure.Commands.Resources.Models.Authorization.PSRoleAssignment[]]$RoleAssignments,

    [Parameter(Mandatory=$True)]
    [ValidateNotNullOrEmpty()]
    [string]$TargetSubscriptionId,

    [Parameter(Mandatory=$False)]
    [Object[]]$ResourceGroupMap,

    [Parameter(Mandatory=$True)]
    [hashtable]$ResourceRoleDefinitionMap,

    [Parameter(Mandatory=$True)]
    [hashtable]$CustomResourceRoleDefinitionMap,

    [Parameter(Mandatory=$False)]
    [hashtable]$SubscriptionNames,

    [Parameter(Mandatory=$False)]
    [string]$GroupPrefix = $null
)

# Convert ResourceGroupMap to Hashtable
$rgMap = @{}
foreach ( $rg in $ResourceGroupMap ) {
    $rgMap += @{
        $rg.SourceResourceGroup = $rg.TargetResourceGroup
    }
}

# Build Role Assignment Map
$raMap = @()
$ras = $RoleAssignments | Where-Object { $_.Scope -like "/subscriptions/*" -and $_.ObjectType -eq "User" }
foreach ( $ra in $ras ) {
    # Get Source Information
    $sScopeSplit = $ra.Scope.Split('/')
    $sRg = if( $sScopeSplit.Count -gt 4 ) { $sScopeSplit[4] } else { "" }
    $sRole = $ra.RoleDefinitionName
    
    # Get Target Information
    $tSub = $TargetSubscriptionId
    if ( $tSub -in $SubscriptionNames.Keys ) {
        $tSubName = $SubscriptionNames[$tSub]
    } elseif ( 'default' -in $SubscriptionNames.Keys ) {
        $tSubName = $SubscriptionNames['default']
    } else {
        $tSubName = $tSub
    }   
    $tRg = $sRg.ToLower()
    if ( $tRg -in $rgMap.Keys ) { $tRg = $rgMap[$tRg] }
    $tRole = $sRole
    if ( $sScopeSplit.Count -ge 9 -and $sRole -in @("Owner","Contributor","Reader") ) {
        $tRole = "$($sScopeSplit[6..7] -join "/") $($sRole)"
        if ( $tRole -in $CustomResourceRoleDefinitionMap.Keys ) {
            $tRole = $CustomResourceRoleDefinitionMap[$tRole]
        } elseif ( $tRole -in $ResourceRoleDefinitionMap.Keys ) {
            $tRole = $ResourceRoleDefinitionMap[$tRole]
        }
    }
    $tScope = "/subscriptions/$($tSub)"
    if ( $tRg -ne "" ) { $tScope = "$($tScope)/resourceGroups/$($tRg)" }
    $tGroupName = @(
        $GroupPrefix
        $tSubName
        $tRg
        $tRole -replace " ", ""
    ) | Where-Object { $_ }
    $tGroupName = $tGroupName -join "_"

    # Create Role Assignment Object
    $newRa = $ra
    $newRa | Add-Member -MemberType NoteProperty -Name TargetScope -Value $tScope
    $newRa | Add-Member -MemberType NoteProperty -Name TargetSubscriptionId -Value $tSub
    $newRa | Add-Member -MemberType NoteProperty -Name TargetResourceGroup -Value $tRg
    $newRa | Add-Member -MemberType NoteProperty -Name TargetRoleDefinitionName -Value $tRole
    $newRa | Add-Member -MemberType NoteProperty -Name TargetGroupName -Value $tGroupName
    $newRa | Add-Member -MemberType NoteProperty -Name TargetGroupObjectId -Value ""
    
    # Add Role Assignment to Map
    $raMap += $newRa
}

return $raMap