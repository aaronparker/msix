#Requires -Modules Evergreen
<#
    Download the latest Microsoft Terminal version in MSIX format and convert into MSIX app attach.
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
    # Find the latest version in MSIX format and download
    Write-Msg -Msg "Find details for Microsoft Terminal"
    $App = Get-EvergreenApp -Name "MicrosoftTerminal" | Where-Object { $_.URI -match "Win10" }
    Write-Msg -Msg "Found version: $($App.Version)"
    $AppMsix = $App | Save-EvergreenApp -Path "$Path\MicrosoftTerminal"
    Write-Msg -Msg "Saved to: '$($AppMsix.FullName)'"

    # Create the VHDX file for this version of the package
    $VhdPath = "$Path\MicrosoftTerminal$($App.Version).vhdx"
    Write-Msg -Msg "Creating VHDX file: '$VhdPath'"
    New-VHD -SizeBytes 512MB -Path $VhdPath -Dynamic -Confirm:$false
    $VhdObject = Mount-VHD $VhdPath -PassThru
    $Disk = Initialize-Disk -PassThru -Number $VhdObject.Number
    $Partition = New-Partition -AssignDriveLetter -UseMaximumSize -DiskNumber $Disk.Number
    Format-Volume -FileSystem "NTFS" -DriveLetter $Partition.DriveLetter -Force -Confirm:$false 

    # Unpack the package to the disk
    Write-Msg -Msg "Unpacking '$($AppMsix.FullName)' to '$($Partition.DriveLetter):\MicrosoftTerminal'"
    & $MsixMgrBin -Unpack -PackagePath $AppMsix.FullName -Destination "$($Partition.DriveLetter):\MicrosoftTerminal" -ApplyACLs

    # Dismount the VHDX file
    Dismount-VHD -Path $VhdPath
}

end {
    Get-ChildItem -Path $VhdPath
}
