param(
    [Parameter(Mandatory=$True, ParameterSetName="LiveData")]
    [string]$SubscriptionId,

    [Parameter(Mandatory=$False, ParameterSetName="LiveData")]
    [string]$ResourceGroupName = $null,

    [Parameter(Mandatory=$False, ParameterSetName="FromFile")]
    [string]$FileName = "",

    [Parameter(Mandatory=$False, ParameterSetName="FromFile")]
    [string]$Scope = ""
)

if ( $PSCmdlet.ParameterSetName -eq "FromFile" ) {
    # Check if File Exists
    if ( -not (Test-Path $FileName) ) {
        Write-Error "File $FileName does not exist."
        exit
    }

    # Retrieve Content of File
    $data = Get-Content $FileName | ConvertFrom-Csv -Delimiter ","
    $assignments = $data
} else {
    # Check if Subscription Exists
    try {
        $subscription = Get-AzSubscription -SubscriptionId $SubscriptionId -ErrorAction Stop
    } catch {
        Write-Error "Subscription $($subscription.Id) not found."
        exit
    }

    $Scope = "/subscriptions/$($subscription.Id)"
    if ( $null -ne $ResourceGroupName -and $ResourceGroupName -ne "" ) {
        $Scope = "$($scope)/resourceGroups/$($ResourceGroupName)"
        
    }
    $assignments = Get-AzRoleAssignment -Scope $Scope -ErrorAction SilentlyContinue
}

# Filter Out Of Scope Assignments
$assignments = $assignments | Where-Object { $_.Scope -like "$($Scope)*" } | Sort-Object Scope, RoleDefinitionName, DisplayName

$newStructure = @()

foreach ( $assign in $assignments ) {
    $myObject = [PSCustomObject]@{
        SubscriptionId = "$($assign.Scope.split("/")[2])"
        ResourceGroupName = ""
        RoleDefinitionName = "$($assign.RoleDefinitionName)"
        GroupMembers = @( $assign.ObjectId )
    }

    $scopeCount = $assign.Scope.split("/").Count
    
    # Resource Group Scope
    if ( $scopeCount -gt 3 ) { $myObject.ResourceGroupName = $assign.Scope.split("/")[4] }
    
    # Scoping Generic Roles to Resource Specific Roles
    if ( $scopeCount -ge 9 -and $myObject.RoleDefinitionName -in @("Owner", "Contributor", "Reader") ) {
        #Write-Host $assign.Scope
        $myObject.RoleDefinitionName = "$($assign.Scope.split("/")[6..7] -join "/") $($assign.RoleDefinitionName)"
        switch ( $myObject.RoleDefinitionName ) {
            # Built-In Role Definition Matching
            { $_ -in @( "Microsoft.Automation/automationAccounts Contributor" ) } { $myObject.RoleDefinitionName = "Automation Contributor" }
            { $_ -in @( "Microsoft.Cache/Redis Contributor" ) } { $myObject.RoleDefinitionName = "Redis Cache Contributor" }
            { $_ -in @( "Microsoft.Compute/virtualMachines Contributor"
                        "Microsoft.Compute/virtualMachines Reader" ) } { $myObject.RoleDefinitionName = "Virtual Machine Contributor" }
            { $_ -in @( "Microsoft.DataFactory/factories Contributor"
                        "Microsoft.DataFactory/factories Reader" ) } { $myObject.RoleDefinitionName = "Data Factory Contributor" }
            { $_ -in @( "Microsoft.DocumentDB/databaseAccounts Contributor" ) } { $myObject.RoleDefinitionName = "Cosmos DB Operator" }
            { $_ -in @( "Microsoft.DocumentDb/databaseAccounts Reader" ) } { $myObject.RoleDefinitionName = "Cosmos DB Account Reader Role" }
            { $_ -in @( "Microsoft.insights/components Owner"
                        "Microsoft.insights/components Contributor" ) } { $myObject.RoleDefinitionName = "Application Insights Component Contributor" }
            { $_ -in @( "microsoft.insights/components Reader" ) } { $myObject.RoleDefinitionName = "Application Insights Snapshot Debugger" }
            { $_ -in @( "Microsoft.KeyVault/vaults Owner"
                        "Microsoft.KeyVault/vaults Contributor" ) } { $myObject.RoleDefinitionName = "Key Vault Contributor" }
            { $_ -in @( "Microsoft.KeyVault/vaults Reader" ) } { $myObject.RoleDefinitionName = "Key Vault Reader" }
            { $_ -in @( "Microsoft.Logic/workflows Owner"
                        "Microsoft.Logic/workflows Contributor"
                        "Microsoft.Logic/workflows Reader" ) } { $myObject.RoleDefinitionName = "Logic App Contributor" }
            { $_ -in @( "Microsoft.ManagedIdentity/userAssignedIdentities Reader" ) } { $myObject.RoleDefinitionName = "Managed Identity Operator" }
            { $_ -in @( "Microsoft.Media/mediaservices Contributor" ) } { $myObject.RoleDefinitionName = "Media Services Account Administrator" }
            { $_ -in @( "microsoft.operationalinsights/workspaces Contributor" ) } { $myObject.RoleDefinitionName = "Log Analytics Contributor" }
            { $_ -in @( "Microsoft.ServiceBus/namespaces Owner"
                        "Microsoft.ServiceBus/namespaces Contributor" ) } { $myObject.RoleDefinitionName = "Azure Service Bus Data Owner" }
            { $_ -in @( "Microsoft.SignalRService/WebPubSub Contributor" ) } { $myObject.RoleDefinitionName = "SignalR/Web PubSub Contributor" }
            { $_ -in @( "Microsoft.Storage/storageAccounts Owner"
                        "Microsoft.Storage/storageAccounts Contributor" ) } { $myObject.RoleDefinitionName = "Storage Account Contributor" }
            { $_ -in @( "Microsoft.Storage/storageAccounts Reader" ) } { $myObject.RoleDefinitionName = "Reader and Data Access" }
            { $_ -in @( "Microsoft.Sql/servers Contributor"
                        "Microsoft.Sql/servers Reader" ) } { $myObject.RoleDefinitionName = "SQL Server Contributor" }
            { $_ -in @( "Microsoft.Web/sites Owner"
                        "Microsoft.Web/sites Contributor"
                        "Microsoft.Web/sites Reader"
                        "Microsoft.Web/serverfarms Reader" ) } { $myObject.RoleDefinitionName = "Website Contributor" }

            # Custom Role Definition Matching
            default { $myObject.RoleDefinitionName = "**$($_)"}
            # { $_ -in @( "Microsoft.Databricks/workspaces Contributor"
            #             "Microsoft.Databricks/workspaces Reader" ) } { $myObject.RoleDefinitionName = "**Databricks Contributor" }
            # { $_ -in @( "Microsoft.DataLakeStore/accounts Contributor" ) } { $myObject.RoleDefinitionName = "**DataLakeStore Contributor" }
            # { $_ -in @( "Microsoft.DataLakeStore/accounts Reader" ) } { $myObject.RoleDefinitionName = "**DataLakeStore Reader" }
            # { $_ -in @( "Microsoft.Devices/IotHubs Contributor" ) } { $myObject.RoleDefinitionName = "**Iot Hub Data Contributor" }
            # { $_ -in @( "Microsoft.Devices/ProvisioningServices Contributor" ) } { $myObject.RoleDefinitionName = "**Iot Device Provisioning Services" }
            # { $_ -in @( "Microsoft.NotificationHubs/namespaces Contributor"
            #             "Microsoft.NotificationHubs/namespaces Reader" ) } { $myObject.RoleDefinitionName = "**Notification Hub Namespace Contributor" }
            # { $_ -in @( "Microsoft.PowerBIDedicated/capacities Contributor" ) } { $myObject.RoleDefinitionName = "**PowerBIDedicated Contributor" }
            # { $_ -in @( "Microsoft.Purview/accounts Contributor" ) } { $myObject.RoleDefinitionName = "**Purview Contributor" }
            # { $_ -in @( "Microsoft.Purview/accounts Reader" ) } { $myObject.RoleDefinitionName = "**Purview Reader" }
            # { $_ -in @( "Microsoft.Synapse/workspaces Contributor" ) } { $myObject.RoleDefinitionName = "**Synapse Contributor" }
            # { $_ -in @( "Microsoft.Synapse/workspaces Reader" ) } { $myObject.RoleDefinitionName = "**Synapse Reader" }
        }
    }

    # Updating Output
    $obj = $newStructure | Where-Object { $_.SubscriptionId -eq $myObject.SubscriptionId -and $_.ResourceGroupName -eq $myObject.ResourceGroupName -and $_.RoleDefinitionName -eq $myObject.RoleDefinitionName }
    if ( $null -eq $obj ) {
        $newStructure += $myObject
    } elseif ( $myObject.GroupMembers -notin $obj[0].GroupMembers ) {
        $obj[0].GroupMembers += $myObject.GroupMembers
    }
}

# Output
return $newStructure

