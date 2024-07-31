param(
    [Parameter(Mandatory=$True)]
    [string]$SubscriptionId,

    [Parameter(Mandatory=$False)]
    [string]$ResourceGroupName = $null,

    # [Parameter(Mandatory=$False)]
    # [string]$ResourceType = $null,

    # [Parameter(Mandatory=$False)]
    # [string]$ResourceName = $null,

    [Parameter(Mandatory=$True)]
    [string]$RoleDefinition,

    [Parameter(Mandatory=$False)]
    [string[]]$Owners = @(),
    
    [Parameter(Mandatory=$False)]
    [string[]]$Members = @(),

    [Parameter(Mandatory=$False, ParameterSetName="GroupDoesNotExists")]
    [ValidateNotNull()]
    [string]$GroupNamePrefix = "",

    [Parameter(Mandatory=$False, ParameterSetName="GroupDoesNotExists")]
    [string]$SubscriptionShortName = $null,

    [Parameter(Mandatory=$True, ParameterSetName="GroupAlreadyExists")]
    [string]$ExistingGroup,

    [Parameter(Mandatory=$False)]
    [switch]$WhatIf
)

# Guid String
$guidFormat = '^[{(]?[0-9A-Fa-f]{8}[-]?([0-9A-Fa-f]{4}[-]?){3}[0-9A-Fa-f]{12}[)}]?$'

# Check Azure PowerShell Connection
$azCtx = Get-AzContext
if ( $null -eq $azCtx ) {
    Write-Error "Please connect to Azure Powershell (Connect-AzAccount) before running this script."
    exit
}

# Check Microsoft Graph Connection
$mgCtx = Get-MgContext
if ( $null -eq $mgCtx ) {
    Write-Error "Please connect to Microsoft Graph Powershell (Connect-MgGraph) before running this script."
    exit
}

# Check Azure Powershell and Microsoft Graph are connected to the same tenant
if ( $azCtx.Tenant.Id -ne $mgCtx.TenantId ) {
    Write-Error "Azure Powershell and Microsoft Graph are connected to different tenants."
    exit
}

# Is the Microsoft Graph "Group.ReadWrite.All" Scope available?
if ( $mgCtx.Scopes -notcontains "Group.ReadWrite.All" ) {
    Write-Error "Microsoft Graph Scope 'Group.ReadWrite.All' is not available."
    exit
}

# Is the Microsoft Graph "User.Read.All" Scope available?
if ( $mgCtx.Scopes -notcontains "User.Read.All" ) {
    Write-Error "Microsoft Graph Scope 'User.Read.All' is not available."
    exit
}

# Check if Subscription Exists
try {
    $subscription = Get-AzSubscription -SubscriptionId $SubscriptionId -ErrorAction Stop
} catch {
    Write-Error "Subscription $SubscriptionId not found."
    exit
}

# Check if Resource Group Exists
if ( $null -ne $ResourceGroupName -and $ResourceGroupName -ne "" ) {
    try {
        $resourceGroup = Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction Stop
        $resId = $resourceGroup.ResourceId
    } catch {
        Write-Error "Resource Group $ResourceGroupName not found."
        exit
    }
} else {
    $resId = "/subscriptions/$($subscription.Id)"
}
Write-Host "Resource Found: $resId"

# Check if Role Definition Exists
try {
    $RoleDefinitionName = $RoleDefinition
    if ($RoleDefinition -match $guidFormat) {
        $roleDef = Get-AzRoleDefinition -Id $RoleDefinition -ErrorAction Stop
        $RoleDefinitionName = $roleDef.Name -replace " ", ""
    } else {
        $roleDef = Get-AzRoleDefinition -Name $RoleDefinition -ErrorAction Stop
        $RoleDefinitionName = $RoleDefinition -replace " ", ""
    }

    if ( $null -eq $roleDef ) { throw }
    Write-Host "Role Definition Found: $($roleDef.Name) (Id: $($roleDef.Id))"
} catch {
    Write-Error "Role Definition Not Found: $RoleDefinition"
    exit
}

# Create Group, or Use Existing Group
if ( $PsCmdlet.ParameterSetName -eq "GroupDoesNotExists" ) {
    # Determine Group Name
    $groupName = "$($GroupNamePrefix)"
    if ( $groupName -ne "" ) {
        $groupName += "_"
    }
    
    if ( $null -eq $SubscriptionShortName -or $SubscriptionShortName -eq "" ) {
        $groupName += "$subscriptionId"
    } else {
        $groupName += "$SubscriptionShortName"
    }
    
    if ( $null -ne $ResourceGroupName -and $ResourceGroupName -ne "" ) {
        $groupName += "_$ResourceGroupName"
    }
    
    $groupName += "_$RoleDefinitionName"

    $group = Get-MgGroup -Filter "displayName eq '$groupName'" -ErrorAction SilentlyContinue    
    if ( $null -eq $group ) {
        try {
            if ( $WhatIf.Exists ) {
                $group = @{
                    DisplayName = $groupName
                    Id = "(whatif)$((New-Guid).Guid)"
                }
                Write-Host "[WhatIf] " -NoNewline
            } else {
                $group = New-MgGroup -DisplayName $groupName -MailEnabled:$false -MailNickname $groupName -SecurityEnabled:$true -ErrorAction Stop
            }
            Write-Host "Group Created: $($group.DisplayName) (Id: $($group.Id))"
        } catch {
            Write-Error "Group Not Created: $groupName"
            exit
        }
    } else {
        Write-Host "Group Already Exists: $groupName (Id: $($group.Id))"
    }
} else {
    # Check if Group Exists
    if ( $ExistingGroup -match $guidFormat ) {
        $group = Get-MgGroup -GroupId $ExistingGroup -ErrorAction SilentlyContinue
    } else {
        $group = Get-MgGroup -Filter "displayName eq '$ExistingGroup'" -ErrorAction SilentlyContinue
    }

    if ( $null -ne $group ) {
        Write-Host "Group Found: $($group.DisplayName) (Id: $($group.Id))"
    } else {
        Write-Error "Group Not Found: $ExistingGroup"
        exit
    }   
}

# Search for Existing Role Assignment
$assignment = Get-AzRoleAssignment -ObjectId $group.Id -RoleDefinitionId $roleDef.Id -Scope $resId -ErrorAction SilentlyContinue
if ( $null -ne $assignment ) {
    Write-Host "Role Assignment Exists! (Id: $($assignment.RoleAssignmentId))"
} else {
    try {
        if ( $WhatIf.Exists ) {
            $assignment = @{
                RoleAssignmentId = "(whatif)$((New-Guid).Guid)"
                Scope = $resId
                RoleDefinitionId = $roleDef.Id
                ObjectId = $group.Id
            }
            Write-Host "[WhatIf] " -NoNewline
        } else {
            $assignment = New-AzRoleAssignment -ObjectId $group.Id -RoleDefinitionId $roleDef.Id -Scope $resId -ErrorAction Stop
        }
        Write-Host "Role Assignment Created! (Id: $($assignment.RoleAssignmentId))"
    }
    catch {
        Write-Error "Role Assignment Not Created!"
        Write-Host $_.Exception.Message
        exit
    }
}

# Get Entra ID Group Name based on parameters
return [PSCustomObject]@{ 
    "RoleAssignmentId" = $assignment.RoleAssignmentId
    "Scope" = $resId
    "GroupName" = $group.DisplayName
    "GroupId" = $group.Id
    "RoleDefinitionName" = $roleDef.Name
    "RoleDefinitionId" = $roleDef.Id
}