# Azure RBAC Framework - Subscription to Subscription Migration Guide
1. Establish Script Configuration
2. Get Current Role Assignment Data
3. Resource Group Mapping (Optional)
4. Target Subscription Readiness
5. Create New Role Assignment Map
6. Implement RBAC Framework
7. Backup Final Product

## Establish Script Configuration
- Static Properties
- Subscription Information
- Subscription Common Names (Used In Group Names)
- New Group Prefix

### Static Properties
```powershell
$workingFolder = $ENV:TEMP
$timeStamp = Get-Date -Format 'yyyyMMddhhmmss'
```

### Subscription Information
```powershell
$sourceSubId = "00000000-0000-0000-0000-000000000000"
$targetSubId = "ffffffff-ffff-ffff-ffff-ffffffffffff"
```

### Subscription Common Names (Used In Group Names)
```powershell
$customSubNames = @{
    "default" = "UnknownSub"
    $sourceSubId = "SourceSubCommonName"
    $targetSubId = "TargetSubCommonName"
}
```

### New Group Name Prefix
```powershell
$customGroupPrefix = "AzUsers"
```

## Get Your Current Role Assignment Data
- Using Live Data
- From File

### Using Live Data
```powershell
$roleAssignments = Get-AzRoleAssignment -Scope "/subscriptions/$($sourceSubId)"
$roleAssignments | Export-Csv -Path "$($workingFolder)/roleAssignments_$($timeStamp).csv" -Delimiter "," -NoTypeInformation -NoClobber
```

### From File
```powershell
$roleAssignments = Import-Csv -Path "$($workingFolder)/roleAssignments.csv" -Delimeter ","
```

<!-- ## Filter Your Role Assignment Data
To reduce the amount of data you are transforming, filter your role assignments to exclude management groups as well as Service Principals, Managed Identities, and orphaned role assignments.

```powershell
$fRoleAssignments = $roleAssignments `
    | Where-Object { $_.Scope -like "/subscriptions/*" } `
    | Where-Object { $_.ObjectType -eq "User" }
``` -->

## Resource Group Mapping (Optional)

If you plan to change the resource group names, you need to create a mapping process.
- Create Mapping File
- Update Mapping File
- Import Mapping File
- When Not Using a Mapping File

### Create Mapping File

```powershell
.\Create-RbacFrameworkRgMap.ps1 -UseRoleAssignments `
    -RoleAssignments $roleAssignments `
    -OutputFileName "$($workingPath)\rgMapping_$($timeStamp).csv"
```

### Update Mapping File

1. Open your Resource Group Mapping File in favorite text editor (Notepad, Excel).
2. Update the TargetResourceGroup column with the Target Resource Group Name
3. Save your Resource Group Mapping file.

### Import Mapping File

```powershell
$rgMapping = .\Import-RbacFrameworkRgMap.ps1 -ResourceGroupMapFile "$($workingFolder)/rgMapping_$($timeStamp).csv"
```

### When Not Using a Mapping File
```powershell
Remove-Variable -Name rgMapping -ErrorAction SilentlyContinue
```

## Target Subscription Readiness
- Copy Custom Role Definitions to Target Subscription
- Get Resource-Specific Built-In Role Definition Hashtable
- Validate Role Definitions
- Create Custom Role Defintions for Missing Maps (If Validation Fails)
- Create Custom Resource-Specific Role Definition Map (If Validation Fails)
- Repeat Validation until Success

### Copy Custom Role Definitions to Target Subscription
```powershell
.\Copy-RbacFrameworkRoleDefinitions.ps1 -SourceSubscriptionId $sourceSubId -TargetSubscriptionId $targetSubId [-WhatIf]
```

### Get Resource-Specific to Built-In Role Defintion Hashtable
Get the hashtable map of Azure Resources to their Built-In Role Definitions
```powershell
$resourceRoleDefinitionMapBuiltin = .\Get-RbacFrameworkResourceRoleMap.ps1
```

### Validate Role Definitions
```powershell
.\Validate-RbacFrameworkRoleDefinitions.ps1 `
    -SubscriptionId $targetSubId `
    -RoleAssignments $roleAssignments `
    -ResourceRoleDefinitionMap $resourceRoleDefinitionMapBuiltin
```

### Create Custom Role Definition for Missing Maps (If Validation Fails)

> #### COMING SOON!
> ```powershell
> # .\New-RbacFrameworkCustomRoleDefinition.ps1
> # $resourceRoleDefinitionMapCustom += @{
> #     [MissingRoleName] = [CustomRoleName]
> # }
> ```

### Create Custom Resource-Specific Role Definition Map (If Validation Fails)
```powershell
$resourceRoleDefinitionMapCustom = @{
    "Microsoft.Synapse/workspaces Contributor" = "Contributor" # Exmaple: Built-In Role Definition Name
    "Microsoft.Synapse/workspaces Reader" = "Synapse WorkSpace Reader" # Example: Custom Role Definition Name
}
```

### Repeat Validation until Success
```powershell
.\Validate-RbacFrameworkRoleDefinitions.ps1 `
    -SubscriptionId $targetSubId `
    -RoleAssignments $roleAssignments `
    -ResourceRoleDefinitionMap $resourceRoleDefinitionMapBuiltin `
    [-CustomResourceRoleDefinitionMap $resourceRoleDefinitionMapCustom]
```

## Create New Role Assignment Map

```powershell
$raMap = .\Create-RbacFrameworkRoleAssignmentMap.ps1 `
    -RoleAssignments $roleAssignments `
    -TargetSubscriptionId $targetSubId `
    -ResourceGroupMap $rgMapping `
    -ResourceRoleDefinitionMap $resourceRoleDefinitionMapBuiltin `
    -CustomResourceRoleDefinitionMap $resourceRoleDefinitionMapCustom
```

## Implement RBAC Framework
- Create New Entra ID Group and New Azure Role Assignment
- Update Entra ID Group Membership

### Create New Entra ID Group and New Azure Role Assignment
```powershell
$groupsAndRolesCreated = @()
$rasToCreate = $raMap | Select-Object TargetSubscriptionId, TargetResourceGroupName, TargetRoleDefinitionName -Unique
foreach ( $ra in $rasToCreate ) {
    $newRbac = @{
        SubscriptonId = $ra.TargetSubscriptionId
        ReourceGroupName = $ra.TargetResourceGroupName
        RoleDefinition = $ra.TargetRoleDefinitionName
        GroupNamePrefix = $customGroupPrefix
        SubscriptionShortName = $customSubNames[$ra.TargetSubscriptionId]
    }
    $groupsAndRolesCreated += .\New-RbacFrameworkGroupAndAssignment.ps1 @newRbac [-WhatIf]
}
```

### Update Entra ID Group Members Using Map
```powershell
foreach ( $grpRole in $groupsAndRolesCreated ) {
    $users = $raMap | Where-Object { `
        $_.TargetSubscriptionId -eq $grpRole.SubscriptionId -and `
        $_.TargetResourceGroupName -eq $grpRole.ResourceGroupName -and `
        $_.TargetRoleDefinitionName -eq $grpRole.RoleDefinition
    } | Select-Object ObjectId -Unique

    $membersCreated += .\New-RbacFrameworkGroupMembership.ps1 -Group $grpRole.GroupId -Members $users.ObjectId [-WhatIf]
}
```

# Backup Final Product
```powershell
$groupsAndRolesCreated | Export-Csv -Path "$($workingFolder)/groupsAndRolesCreated_$($timeStamp).csv" -Delimeter "," -NoTypeInformation
$membersCreated | Export-Csv -Path "$($workingFolder)/groupMembers_$($timeStamp).csv" -Delimeter "," -NoTypeInformation
$raMap | Export-Csv -Path "$($workingFolder)/raMap_$($timeStamp).csv" -Delimeter "," -NoTypeInformation
```