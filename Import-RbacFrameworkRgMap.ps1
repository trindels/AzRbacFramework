Param(
    [Parameter(Mandatory=$True)]
    [ValidateScript({
        if ( -not (Test-Path $_) ) { throw "File $_ does not exist." }
        if ( $_ -notmatch "(\.csv)" ) { throw "File $_ is not a CSV file." }
        return $True
    })]
    [string]$ResourceGroupMapFile
)

$rgMapping = Import-Csv -Path $ResourceGroupMapFile -Delimiter ","
$rgMapping = $rgMapping | Select-Object `
    @{Name="SourceResourceGroup";Expression={$_.SourceResourceGroup.ToLower()}}, `
    @{Name="TargetResourceGroup";Expression={$_.TargetResourceGroup.ToLower()}} `
    -Unique
$rgMapping = $rgMapping | Sort-Object SourceResourceGroup, TargetResourceGroup
$rgMapping = $rgMapping | Where-Object { $_.SourceResourceGroup -ne "" -and $_.TargetResourceGroup -ne "" }

return $rgMapping
    