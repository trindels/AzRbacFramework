Param(
    [string]$sourceSubId = "00000000-0000-0000-0000-000000000000",
    [string]$targetSubId = "ffffffff-ffff-ffff-ffff-ffffffffffff",
    [hashtable]$customSubNames = @{
        "default" = "UnknownSub"
        $sourceSubId = "SourceSubCommonName"
        $targetSubId = "TargetSubCommonName"
    },
    [string]$workingFolder = $ENV:TEMP,
    [string]$roleAssignmentPath,
    [string]$rgMappingPath
)

# Establish Script Configuration
## Static Properties
$timeStamp = Get-Date -Format 'yyyyMMddhhmmss'

# Get Current Role Assignment Data
## From File
$roleAssignments = Import-Csv -Path $RoleAssignmentPath -Delimiter ","

# Resource Group Mapping
## Create Resource Group Mapping File
# .\Create-RbacFrameworkRgMap.ps1 -UseRoleAssignments `
#     -RoleAssignments $roleAssignments `
#     -OutputFileName "$($workingPath)\rgMapping_$($timeStamp).csv"
  
## Import Mapping File
$rgMapping = .\Import-RbacFrameworkRgMap.ps1 -ResourceGroupMapFile $RgMappingPath

# Target Subsciption Readiness
## Copy Custom Roles to Target Subscription (Verify)
.\Copy-RbacFrameworkRoleDefinitions.ps1 -SourceSubscriptionId $sourceSubId -TargetSubscriptionId $targetSubId -WhatIf

## Copy Custom Roles to Target Subscription (Execute)
.\Copy-RbacFrameworkRoleDefinitions.ps1 -SourceSubscriptionId $sourceSubId -TargetSubscriptionId $targetSubId

## Get Azure Resource to Built-In Role Defintion Hashtable
$resourceRoleDefinitionMapBuiltin = .\Get-RbacFrameworkResourceRoleMap.ps1

## Testing: Custom Resource-Specific Role Definitions
$resourceRoleDefinitionMapCustom = @{}
$resourceRoleDefinitionMapCustom += @{
    "App Services Automation" = "TRR-MDCContinuousExport"
    "Synapse WorkSpace Reader" = "TRR-MDCContinuousExport"
    "Virtual Machine Automation" = "TRR-MDCContinuousExport"
}

## Initial Validation
$missingRoles = .\Validate-RbacFrameworkRoleDefinitions.ps1 `
    -SubscriptionId $targetSubId `
    -RoleAssignments $roleAssignments `
    -ResourceRoleDefinitionMap $resourceRoleDefinitionMapBuiltin `
    -CustomResourceRoleDefinitionMap $resourceRoleDefinitionMapCustom
$missingRoles

## Create Custom Resource-Specific Role Definitions
$resourceRoleDefinitionMapCustom += @{
    "Microsoft.Databricks/workspaces Contributor" = "TRR-MDCContinuousExport"
    "Microsoft.Databricks/workspaces Reader" = "TRR-MDCContinuousExport"
    "Microsoft.DataLakeStore/accounts Reader" = "TRR-MDCContinuousExport"
    "Microsoft.Devices/IotHubs Contributor" = "TRR-MDCContinuousExport"
    "Microsoft.Devices/ProvisioningServices Contributor" = "TRR-MDCContinuousExport"
    "Microsoft.NotificationHubs/namespaces Contributor" = "TRR-MDCContinuousExport"
    "Microsoft.NotificationHubs/namespaces Reader" = "TRR-MDCContinuousExport"
    "Microsoft.PowerBIDedicated/capacities Contributor" = "TRR-MDCContinuousExport"
    "Microsoft.Purview/accounts Contributor" = "TRR-MDCContinuousExport"
    "Microsoft.Purview/accounts Reader" = "TRR-MDCContinuousExport"
    "Microsoft.Synapse/workspaces Contributor" = "TRR-MDCContinuousExport"
    "Microsoft.Synapse/workspaces Reader" = "TRR-MDCContinuousExport"
}

## Validate Again
$missingRoles = .\Validate-RbacFrameworkRoleDefinitions.ps1 `
    -SubscriptionId $targetSubId `
    -RoleAssignments $roleAssignments `
    -ResourceRoleDefinitionMap $resourceRoleDefinitionMapBuiltin `
    -CustomResourceRoleDefinitionMap $resourceRoleDefinitionMapCustom
$missingRoles



# Create New Role Assignment Map
$raMap = .\Create-RbacFrameworkRoleAssignmentMap.ps1 `
    -RoleAssignments $roleAssignments `
    -TargetSubscriptionId $targetSubId `
    -ResourceGroupMap $rgMapping `
    -ResourceRoleDefinitionMap $resourceRoleDefinitionMapBuiltin `
    -CustomResourceRoleDefinitionMap $resourceRoleDefinitionMapCustom `
    -SubscriptionNames $customSubNames `
    -GroupPrefix $customGroupPrefix


# Implement RBAC Framework
## Create New Entra ID Group and New Azure Role Assignment
$groupsAndRolesCreated = @()
$rasToCreate = $raMap | Select-Object TargetSubscriptionId, TargetResourceGroupName, TargetRoleDefinitionName -Unique | Sort-Object TargetSubscriptionId, TargetResourceGroupName, TargetRoleDefinitionName
foreach ( $ra in $rasToCreate ) {
    $newRbac = @{
        SubscriptionId = $ra.TargetSubscriptionId
        ResourceGroupName = $ra.TargetResourceGroupName
        RoleDefinition = $ra.TargetRoleDefinitionName
        GroupNamePrefix = $customGroupPrefix
        SubscriptionShortName = $customSubNames[$ra.TargetSubscriptionId]
    }
    $groupsAndRolesCreated += .\New-RbacFrameworkGroupAndAssignment.ps1 @newRbac -WhatIf
}

## Update Entra ID Group Members Using Map
$membersCreated = @()
foreach ( $grpRole in $groupsAndRolesCreated ) {
    $users = $raMap | Where-Object { `
        $_.TargetSubscriptionId -eq $grpRole.SubscriptionId -and `
        $_.TargetResourceGroupName -eq $grpRole.ResourceGroupName -and `
        $_.TargetRoleDefinitionName -eq $grpRole.RoleDefinitionName `
    } | Select-Object ObjectId -Unique

    $membersCreated += .\New-RbacFrameworkGroupMembership.ps1 -Group $grpRole.GroupId -Members $users.ObjectId -WhatIf
}



# Backup Role Assignment Map Final Product
$groupsAndRolesCreated | Export-Csv -Path "$($workingFolder)/groupsAndRolesCreated_$($timeStamp).csv" -Delimiter "," -NoTypeInformation
$membersCreated | Export-Csv -Path "$($workingFolder)/groupMembers_$($timeStamp).csv" -Delimiter "," -NoTypeInformation
$raMap | Export-Csv -Path "$($workingFolder)/raMap_$($timeStamp).csv" -Delimiter "," -NoTypeInformation