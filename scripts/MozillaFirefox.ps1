<#
    Download the latest Mozilla Firefox version in MSIX format and convert into MSIX app attach.
#>

$params = @{
    Name          = "MozillaFirefox"
    AppParams     = @{ Language = "en-GB" }
    ErrorAction   = "SilentlyContinue"
    WarningAction = "SilentlyContinue"
}
$Firefox = Get-EvergreenApp @params | Where-Object { $_.Architecture -eq "x64" -and $_.Channel -eq "LATEST_FIREFOX_VERSION" -and $_.Language -eq "en-GB" -and $_.Type -eq "msix" }
$FirefoxMsix = $Firefox | Save-EvergreenApp -Path "E:\Temp\Firefox"

$VhdPath = "E:\Temp\MozillaFirefox$($Firefox.Version).vhdx"
New-VHD -SizeBytes 512MB -Path $VhdPath -Fixed -Confirm:$false
$VhdObject = Mount-VHD $VhdPath -PassThru
$Disk = Initialize-Disk -PassThru -Number $VhdObject.Number
$Partition = New-Partition -AssignDriveLetter -UseMaximumSize -DiskNumber $Disk.Number
Format-Volume -FileSystem "NTFS" -DriveLetter $Partition.DriveLetter -Force -Confirm:$false 

msixmgr.exe -Unpack -PackagePath $FirefoxMsix.FullName -destination "$($Partition.DriveLetter):\MozillaFirefox" -ApplyACLs
