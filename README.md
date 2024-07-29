# AzRbacFramework
 
## Establish Source Subscription

```powershell
$subId = "00000000-0000-0000-0000-000000000000"
```

## Get Your Current Role Assignments

### [Live Data](#tab/livedata)

```powershell
$roleAssignments = Get-AzRoleAssignment -Scope "/subscriptions/$($subId)"
$roleAssignments | Export-Csv -Path "(pathToFile)/file_$($timestamp).csv" -Delimeter "," -NoTypeInformation -NoClobber
```

### [From File](#tab/fromfile)

```powershell
$roleAssignments = Import-Csv -Path "(pathToFile).csv" -Delimeter ","
```

Filter Your Role Assignment Data
```
$fRoleAssignments = $roleAssignments `
    | Where-Object { $_.Scope -like "/subscriptions/*" } `
    | Where-Object { $_.ObjectType -eq "User" }
```