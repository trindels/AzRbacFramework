Param(
    [Parameter(Mandatory=$False, ParameterSetName="LiveData")]
    [string]$SubscriptionId,

    [Parameter(Mandatory=$True, ParameterSetName="FromFile")]
    [ValidateScript({
        if ( -not (Test-Path $_) ) { throw "File $_ does not exist." }
        if ( $_ -notmatch "(\.csv)" ) { throw "File $_ is not a CSV file." }
        return $True
    })]
    [string]$Path = ""
)

if ( $PSCmdlet.ParameterSetName -ne "FromFile" ) {
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


if ( $PSCmdlet.ParameterSetName -eq "LiveData" ) {
    $assignments = Get-AzRoleAssignment -Scope "/subscriptions/$($ctx.Subscription.Id)" -ErrorAction SilentlyContinue
    <# Action to perform if the condition is true #>
} elseif ( $PSCmdlet.ParameterSetName -eq "FromFile" ){
    $assignments = Import-Csv $Path -Delimiter ","
    foreach ( $a in $assignments ) {
        $a = [Microsoft.Azure.Commands.Resources.Models.Authorization.PSRoleAssignment]$a
    }
}

$assignments = $assignments | Where-Object { $_.Scope -notlike "/providers/Microsoft.Management/*" }

return $assignments