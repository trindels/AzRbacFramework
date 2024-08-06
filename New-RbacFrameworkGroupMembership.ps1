param(
    [Parameter(Mandatory=$True)]
    [ValidateNotNullOrEmpty()]
    [string]$Group,

    [Parameter(Mandatory=$True)]
    [ValidateNotNullOrEmpty()]
    [string[]]$Members,

    [Parameter(Mandatory=$False)]
    [switch]$WhatIf
)

$guidFormat = '^[{(]?[0-9A-Fa-f]{8}[-]?([0-9A-Fa-f]{4}[-]?){3}[0-9A-Fa-f]{12}[)}]?$'

# Check Microsoft Graph Connection
$mgCtx = Get-MgContext
if ( $null -eq $mgCtx ) {
    Write-Error "Please connect to Microsoft Graph Powershell (Connect-MgGraph) before running this script."
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

# Verify Group ID
if ( $Group -match $guidFormat ) {
    $grp = Get-MgGroup -GroupId $Group -ErrorAction SilentlyContinue
} else {
    $grp = Get-MgGroup -Filter "DisplayName eq '$($Group)'" -ErrorAction SilentlyContinue
}
if ( $null -eq $grp -or $grp.Count -eq 0) {
    if ( $null -ne $WhatIf -and $WhatIf ) {
        Write-Host "[WhatIf] [Warning]: Group Does Not Exist: $($Group)" -ForegroundColor Yellow
        $grp = @{
            DisplayName = "WhatIf_$($Group)"
            Id = $Group
        }
    } else {
        Write-Error "Group ID Does Not Exist: $($Group)"
        exit
    }
}

# Group Members
$grpMbrs = @()

# Loop through each member and add to the group
foreach ( $mbr in $Members ) {
    if ( $mbr -match $guidFormat ) {
        $usr = Get-MgUser -UserId $mbr -ErrorAction SilentlyContinue
    } else {
        $usr = Get-MgUser -Filter "UserPrincipalName eq '$($mbr)'" -ErrorAction SilentlyContinue
    }
    $usr = Get-MgUser -UserId $mbr -ErrorAction SilentlyContinue
    if ( $null -eq $usr -or $usr.Count -eq 0 ) {
        Write-Host "[Warning]: Member ObjectID Does Not Exist: $($mbr)" -ForegroundColor Yellow
        continue
    } 

    try {
        if ( $null -ne $WhatIf -and $WhatIf ) {
            Write-Host "[WhatIf] " -NoNewline
        } else {
            $grpMbr = New-MgGroupMember -GroupId $grp.Id -DirectoryObjectId $usr.Id -ErrorAction Stop
        }
        Write-Host "Member Added: $($usr.DisplayName) to Group: $($grp.DisplayName)" -ForegroundColor Green
        $grpMbr = [PSCustomObject]@{
            GroupObjectId = $grp.Id
            GroupDisplayName = $grp.DisplayName
            MemberObjectId = $usr.Id
            MemberDisplayName = $usr.DisplayName
        }
        $grpMbrs += $grpMbr

    } catch {
        if ( $_.Exception.Message -match "already exist" ) {
            Write-Host "Member Already Exists: $($usr.DisplayName) in Group: $($grp.DisplayName)" -ForegroundColor Yellow
        } else {
            Write-Error "Member Not Added: $($usr.DisplayName) to Group: $($grp.DisplayName)"
            Write-Host $_.Exception.Message
        }
    }
}

return $grpMbrs