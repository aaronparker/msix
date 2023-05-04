using namespace System.Management.Automation
<#
    Functions to support MSIX app attach conversion scripts.
#>

function Write-Msg {
    [CmdletBinding()]
    param(
        [System.String[]] $Msg
    )
    process {
        foreach ($String in $Msg) {
            $Message = [HostInformationMessage]@{
                Message         = "[$(Get-Date -Format 'dd.MM.yyyy HH:mm:ss')]"
                ForegroundColor = "Black"
                BackgroundColor = "DarkCyan"
                NoNewline       = $true
            }
            $params = @{
                MessageData       = $Message
                InformationAction = "Continue"
                Tags              = "Microsoft365"
            }
            Write-Information @params
            $params = @{
                MessageData       = " $String"
                InformationAction = "Continue"
                Tags              = "Microsoft365"
            }
            Write-Information @params
        }
    }
}

#region Download the msixmgr tool
function Get-MsixMgr {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({ if (Test-Path -Path $_ -PathType "Container") { $true } else { throw "Path not found: '$_'" } })]
        [System.String] $Path = "$Env:Temp\MsixMgr"
    )

    process {
        $MsixMgrBin = "$Path\x64\msixmgr.exe"
        if (Test-Path -Path $MsixMgrBin -PathType "Leaf") {
            Write-Msg -Msg "Using existing msixmgr.exe at '$MsixMgrBin'"
            Write-Output -InputObject $MsixMgrBin
        }
        else {
            Write-Msg -Msg "Create path: '$Path'"
            New-Item -Path $Path -ItemType "Container" -Force -ErrorAction "Stop" | Out-Null
            try {
                $params = @{
                    Uri             = "https://aka.ms/msixmgr"
                    OutFile         = "$Path\msixmgr.zip"
                    UseBasicParsing = $true
                }
                Write-Msg -Msg "Download from: 'https://aka.ms/msixmgr'"
                Invoke-WebRequest @params
                Write-Msg -Msg "Expand '$Path\msixmgr.zip'"
                Expand-Archive -Path "$Path\msixmgr.zip" -DestinationPath $Path -Force
                Write-Output -InputObject $MsixMgrBin
            }
            catch {
                throw $_
            }
        }
    }
}
#endregion

function Get-MicrosoftVCLibsDesktopAppx {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [System.String[]] $Url = "https://aka.ms/Microsoft.VCLibs.x64.14.00.Desktop.appx",

        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({ if (Test-Path -Path $_ -PathType "Container") { $true } else { throw "Path not found: '$_'" } })]
        [System.String] $Path = "$Env:Temp\VcLibs"
    )

    process {
        foreach ($Item in $Url) {
            if (Test-Path -Path $Path -PathType "Leaf") {
                Write-Msg -Msg "Create path: '$Path'"
                New-Item -Path $Path -ItemType "Container" -Force -ErrorAction "Stop" | Out-Null
            }
            try {
                $params = @{
                    Uri             = $Item
                    OutFile         = "$Path\$(Split-Path -Path $Item -Leaf)"
                    UseBasicParsing = $true
                }
                Write-Msg -Msg "Download from: '$Item'"
                Invoke-WebRequest @params
                Write-Output -InputObject $(Get-Item -Path "$Path\$(Split-Path -Path $Item -Leaf)")
            }
            catch {
                throw $_
            }
        }
    }
}
