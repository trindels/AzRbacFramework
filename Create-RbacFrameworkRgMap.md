# Create-RbacFrameworkRgMap.ps1

## Using Resource Groups
```powershell
.\Create-RbacFrameworkRgMap.ps1 -UseResourceGroups [-SubscriptionId <string>] -OutputFileName <string>
```
## Using Role Assignments
```powershell
.\Create-RbacFrameworkRgMap.ps1 -UseRoleAssignments [-SubscriptionId <string>] -OutputFileName <string>
```
```powershell
.\Create-RbacFrameworkRgMap.ps1 -UseRoleAssignments -RoleAssignments <PSRoleAssignment[]> -OutputFileName <string>
```
```powershell
.\Create-RbacFrameworkRgMap.ps1 -UseRoleAssignments -RoleAssignmentsFile <string> -OutputFileName <string>
```
