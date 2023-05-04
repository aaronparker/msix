#Requires -Modules Evergreen
<#
    Download the latest DevToys version in MSIX format and convert into MSIX app attach.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ if (Test-Path -Path $_ -PathType "Container") { $true } else { throw "Path not found: '$_'" } })]
    [System.String] $Path = "E:\Temp"
)

begin {
    # Import functions
    Import-Module -Name "$PSScriptRoot\functions.psm1"
    $MsixMgrBin = Get-MsixMgr
}

process {
    # Find the latest DevToys version in MSIX format and download
    Write-Msg -Msg "Find details for  DevToys"
    $DevToys = Get-EvergreenApp -Name DevToys
    Write-Msg -Msg "Found version: $($DevToys.Version)"
    $DevToysMsix = $DevToys | Save-EvergreenApp -Path "$Path\DevToys"
    Write-Msg -Msg "Saved to: '$($DevToysMsix.FullName)'"

    # Create the VHDX file for this version of the package
    $VhdPath = "$Path\DevToys$($DevToys.Version).vhdx"
    Write-Msg -Msg "Creating VHDX file: '$VhdPath'"
    New-VHD -SizeBytes 512MB -Path $VhdPath -Dynamic -Confirm:$false
    $VhdObject = Mount-VHD $VhdPath -PassThru
    $Disk = Initialize-Disk -PassThru -Number $VhdObject.Number
    $Partition = New-Partition -AssignDriveLetter -UseMaximumSize -DiskNumber $Disk.Number
    Format-Volume -FileSystem "NTFS" -DriveLetter $Partition.DriveLetter -Force -Confirm:$false 

    # Unpack the package to the disk
    Write-Msg -Msg "Unpacking '$($DevToysMsix.FullName)' to '$($Partition.DriveLetter):\DevToys'"
    & $MsixMgrBin -Unpack -PackagePath $DevToysMsix.FullName -Destination "$($Partition.DriveLetter):\DevToys" -ApplyACLs

    # Dismount the VHDX file
    Dismount-VHD -Path $VhdPath
}

end {
    Get-ChildItem -Path $VhdPath
}
