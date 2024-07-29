# AzRbacFramework
 
## Establish Source Subscription

```powershell
$subId = "00000000-0000-0000-0000-000000000000"
$workingFolder = $ENV:TEMP
$timeStamp = Get-Date -Format 'yyyyMMddhhmmss'
```

## Get Your Current Role Assignment Data

### Using Live Data
```powershell
$roleAssignments = Get-AzRoleAssignment -Scope "/subscriptions/$($subId)"
$roleAssignments | Export-Csv -Path "$($workingFolder)/roleAssignments_$($timeStamp).csv" -Delimeter "," -NoTypeInformation -NoClobber
```

### From File
```powershell
$roleAssignments = Import-Csv -Path "$($workingFolder)/roleAssignments.csv" -Delimeter ","
```

## Filter Your Role Assignment Data
To reduce the amount of data you are transforming, filter your role assignments to exclude management groups as well as Service Principals, Managed Identities, and orphaned role assignments.

```powershell
$fRoleAssignments = $roleAssignments `
    | Where-Object { $_.Scope -like "/subscriptions/*" } `
    | Where-Object { $_.ObjectType -eq "User" }
```

## Resource Group Mapping

If you plan to change the resource group names, you need to create a mapping process.

### Create Mapping File

```powershell
$fRoleAssignments `
    | Select-Object `
        @{Name="SourceSubscription";Expression={$_.Scope.Split("/")[2].ToLower()}}, `
        @{Name="SourceResourceGroup";Expression={$_.Scope.Split("/")[4].ToLower()}}, `
        @{Name="TargetSubscription";Expression=""}, `
        @{Name="TargetResourceGroup";Expression=""} `
        -Unique `
    | Sort-Object SourceSubscription, SourceResourceGroup
    | Export-Csv -Path "$($ENV:temp)\$($subId)_rgMapping_$($timeStamp).csv" -Delimiter "," -NoTypeInformation -NoClobber
```

### Update Mapping File

1. Open your Resource Group Mapping File in favorite text editor (Notepad, Excel).
2. Update the TargetSubscription column for each resource group with the Target Subscription Id
3. Update the TargetResourceGroup column with the Target Resource Group Name
4. Save your Resource Group Mapping file.

### Import Mapping File

```powershell
$rgMapping = Import-Csv -Path "$($workingFolder)/rgMapping.csv" -Delimiter ","
```

### [!NOTE]
If you do not wish to map your Resource Groups between subscriptions, make sure the $rgMapping variable is set to $null.
```powershell
$rgMapping = $null
```