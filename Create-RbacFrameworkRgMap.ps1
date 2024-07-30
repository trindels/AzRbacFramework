Param(
    [Parameter(Mandatory=$True, ParameterSetName="FromResourceGroups", Position=0)]
    [switch]$UseResourceGroups,

    [Parameter(Mandatory=$True, ParameterSetName="FromRoleAssignment", Position=0)]
    [Parameter(Mandatory=$True, ParameterSetName="FromRoleAssignmentObject", Position=0)]
    [Parameter(Mandatory=$True, ParameterSetName="FromRoleAssignmentFile", Position=0)]
    [switch]$UseRoleAssignments, 
    
    [Parameter(Mandatory=$False, ParameterSetName="FromResourceGroups", Position=1)]
    [Parameter(Mandatory=$False, ParameterSetName="FromRoleAssignment", Position=1)]
    [ValidateNotNullOrEmpty()]
    [string]$SubscriptionId = "",
 
    [Parameter(Mandatory=$True, ParameterSetName="FromRoleAssignmentObject", Position=1)]
    [ValidateNotNullOrEmpty()]
    [Microsoft.Azure.Commands.Resources.Models.Authorization.PSRoleAssignment[]]$RoleAssignments,

    [Parameter(Mandatory=$True, ParameterSetName="FromRoleAssignmentFile", Position=1)]
    [ValidateScript({
        if ( -not (Test-Path $_) ) { throw "File $_ does not exist." }
        if ( $_ -notmatch "(\.csv)" ) { throw "File $_ is not a CSV file." }
        return $True
    })]
    [string]$RoleAssignmentsFile = "",

    [Parameter(Mandatory=$True, Position=2)]
    [ValidateNotNullOrEmpty()]
    [string]$OutputFileName
)

$output = @()

if ( $PSCmdlet.ParameterSetName -ne "FromRoleAssignmentFile" ) {
    try {
        $ctx = Get-AzContext -ErrorAction Stop
    } catch {
        Write-Error "Please Connect to Azure Powershell (Connect-AzAccount) before running this script."
        exit
    }

    try {
        if ( $SubscriptionId -ne "" -and $ctx.Subscription.Id -ne $SubscriptionId ) {
            $ctx = Set-AzContext -SubscriptionId $SubscriptionId -ErrorAction Stop
        }
    }
    catch {
        Write-Error "Subscription $SubscriptionId not found."
        exit
    }
}

if ( $PSCmdlet.ParameterSetName -eq "FromResourceGroups") {
    $rgs = Get-AzResourceGroup -ErrorAction SilentlyContinue
    foreach ( $rg in $rgs ) {
        $output += [PSCustomObject]@{
            SourceResourceGroup = $rg.ResourceGroupName.ToLower()
            TargetResourceGroup = ""
        }
    }
} elseif ( $PSCmdlet.ParameterSetName -like "FromRoleAssignment*" ) {
    if ( $PSCmdlet.ParameterSetName -eq "FromRoleAssignment" ) {
        try {
            $assignments = Get-AzRoleAssignment -Scope "/subscriptions/$($ctx.Subscription.Id)" -ErrorAction Stop
        } catch {
            Write-Error "No Role Assignments found in Subscription $($ctx.Subscription.Id)."
            exit
        }
    } elseif ( $PSCmdlet.ParameterSetName -eq "FromRoleAssignmentFile" ) {
        if ( -not (Test-Path $RoleAssignmentsFile) ) {
            Write-Error "File $RoleAssignmentsFile does not exist."
            exit
        }
        $assignments = Import-Csv $RoleAssignmentsFile -Delimiter ","
    } elseif ( $PSCmdlet.ParameterSetName -eq "FromRoleAssignmentObject" ) {
        $assignments = $RoleAssignments
    }

    $assignments = $assignments `
        | Where-Object { $_.Scope.split("/").Count -gt 4 } `
        | Where-Object { $_.Scope -notlike "/providers/Microsoft.Management/*" }
    foreach ( $assignment in $assignments ) {
        $output += [PSCustomObject]@{
            SourceResourceGroup = $assignment.Scope.Split("/")[4].ToLower()
            TargetResourceGroup = ""
        }
    }
}

if ( $output.Count -gt 0 ) {
    $output | Select-Object * -Unique | Sort-Object SourceResourceGroup | Export-Csv -Path $OutputFileName -NoTypeInformation -Force
    Write-Host "Resource Group Mapping Complete: $OutputFileName"
} else {
    Write-Error "No Resource Group Mapping Found."
}
