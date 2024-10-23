#Requires -Modules Evergreen
<#
    Download the latest application version in MSIX format and convert into MSIX app attach.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ if (Test-Path -Path $_ -PathType "Container") { $true } else { throw "Path not found: '$_'" } })]
    [System.String] $Path = "E:\Temp",

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [System.String] $Apps = "./apps.csv"
)

begin {    
    # Import functions
    Import-Module -Name "$PSScriptRoot\functions.psm1"

    # Get the MsixMgr binary
    $MsixMgrBin = Get-MsixMgr

    # Read the input CSV file
    $AppsList = Import-Csv -Path $Apps -ErrorAction "Stop"
}

process {
    foreach ($App in $AppsList) {

        # Find the latest $App version in MSIX format and download
        Write-Msg -Msg "Find details for: '$($App.Name)'"
        $params = @{
            Name = $App.Name
        }
        if ($App.AppParams) {
            $params.AppParams = $App.AppParams
        }
        $AppDetails = Get-EvergreenApp -Name @params
        if ($App.Filter) {
            $AppDetails = $AppDetails | Where-Object -FilterScript $App.Filter
        }

        Write-Msg -Msg "Found version: $($AppDetails.Version)"
        New-Item -Path "$Path\$($App.Name)" -ItemType "Directory" -Force -ErrorAction "Stop" | Out-Null
        $AppMsix = $AppDetails | Save-EvergreenApp -Path "$Path\$($App.Name)"
        Write-Msg -Msg "Saved to: '$($AppMsix.FullName)'"

        # Create the VHDX file for this version of the package
        $VhdPath = "$Path\$($App.Name)$($AppDetails.Version).vhdx"
        Write-Msg -Msg "Creating VHDX file: '$VhdPath'"
        New-VHD -SizeBytes 512MB -Path $VhdPath -Dynamic -Confirm:$false

        # Mount the VHDX file
        $VhdObject = Mount-VHD $VhdPath -PassThru
        $Disk = Initialize-Disk -PassThru -Number $VhdObject.Number
        $Partition = New-Partition -AssignDriveLetter -UseMaximumSize -DiskNumber $Disk.Number
        Format-Volume -FileSystem "NTFS" -DriveLetter $Partition.DriveLetter -Force -Confirm:$false 

        # Unpack the package to the disk
        Write-Msg -Msg "Unpacking '$($AppMsix.FullName)' to '$($Partition.DriveLetter):\$($App.Name)'"
        & $MsixMgrBin -Unpack -PackagePath $AppMsix.FullName -Destination "$($Partition.DriveLetter):\$($App.Name)" -ApplyACLs

        # Dismount the VHDX file
        Dismount-VHD -Path $VhdPath
        Get-ChildItem -Path $VhdPath
    }
}

end {
}
