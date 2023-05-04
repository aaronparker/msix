#Requires -Modules Evergreen
<#
    Download the latest Mozilla Firefox version in MSIX format and convert into MSIX app attach.
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
    # Find the latest Firefox version in MSIX format and download
    Write-Msg -Msg "Find details for Mozilla Firefox"
    $params = @{
        Name          = "MozillaFirefox"
        AppParams     = @{ Language = "en-GB" }
        ErrorAction   = "SilentlyContinue"
        WarningAction = "SilentlyContinue"
    }
    $Firefox = Get-EvergreenApp @params | Where-Object { $_.Architecture -eq "x64" -and $_.Channel -eq "LATEST_FIREFOX_VERSION" -and $_.Language -eq "en-GB" -and $_.Type -eq "msix" }
    Write-Msg -Msg "Found version: $($Firefox.Version)"
    $FirefoxMsix = $Firefox | Save-EvergreenApp -Path "$Path\Firefox"
    Write-Msg -Msg "Saved to: '$($FirefoxMsix.FullName)'"

    # Create the VHDX file for this version of the package
    $VhdPath = "$Path\MozillaFirefox$($Firefox.Version).vhdx"
    Write-Msg -Msg "Creating VHDX file: '$VhdPath'"
    New-VHD -SizeBytes 512MB -Path $VhdPath -Dynamic -Confirm:$false
    $VhdObject = Mount-VHD $VhdPath -PassThru
    $Disk = Initialize-Disk -PassThru -Number $VhdObject.Number
    $Partition = New-Partition -AssignDriveLetter -UseMaximumSize -DiskNumber $Disk.Number
    Format-Volume -FileSystem "NTFS" -DriveLetter $Partition.DriveLetter -Force -Confirm:$false 

    # Unpack the package to the disk
    Write-Msg -Msg "Unpacking '$($FirefoxMsix.FullName)' to '$($Partition.DriveLetter):\MozillaFirefox'"
    & $MsixMgrBin -Unpack -PackagePath $FirefoxMsix.FullName -Destination "$($Partition.DriveLetter):\MozillaFirefox" -ApplyACLs

    # Dismount the VHDX file
    Dismount-VHD -Path $VhdPath
}

end {
    Get-ChildItem -Path $VhdPath
}
