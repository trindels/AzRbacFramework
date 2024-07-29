# AzRbacFramework
 
Establish Source Subscription
> $subId = "00000000-0000-0000-0000-000000000000"

Get Your Current Role Assignments
From Live Data:
> $roleAssignments = Get-AzRoleAssignment -Scope "/subscriptions/$($subId)"
From Stored File:
> $roleAssignments = Import-Csv -Path "(pathToFile).csv" -Delimeter ","

Filter Your Role Assignment Data
> $fRoleAssignments = $roleAssignments `
>     | Where-Object { $_.Scope -like "/subscriptions/*" } `
>     | Where-Object { $_.ObjectType -eq "User" }