# Create-RbacFrameworkRgMapping.ps1

## Using Resource Groups
```powershell
.\Create-RbacFrameworkRgMapping.ps1 -UseResourceGroups [-SubscriptionId <string>] -OutputFileName <string>
```
## Using Role Assignments
```powershell
.\Create-RbacFrameworkRgMapping.ps1 -UseRoleAssignments [-SubscriptionId <string>] -OutputFileName <string>
```
```powershell
.\Create-RbacFrameworkRgMapping.ps1 -UseRoleAssignments -RoleAssignments <PSRoleAssignment[]> -OutputFileName <string>
```
```powershell
.\Create-RbacFrameworkRgMapping.ps1 -UseRoleAssignments -RoleAssignmentsFile <string> -OutputFileName <string>
```
