<#
    .SYNOPSIS
    Creates an Automatic Deployment Rule including Deployment Package and Deployment for any supported Microsoft Operating System.
    .DESCRIPTION
    Creates an Automatic Deployment Rule including Deployment Package and Deployment for any supported Microsoft Operating System.
    .EXAMPLE
#>
function New-CMOSADR {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param (
        # Specify ConfigMgr Site Code
        [Parameter(Mandatory)]
        [ValidatePattern("^\w{3}:$")]
        [string]
        $CMSiteCode,

        # Specify CM Site Server FQDN
        [Parameter(Mandatory)]
        [String]
        $CMSiteServerFQDN,

        # Windows 10 Version
        [Parameter(Mandatory,ParameterSetName="ByOSVersion")]
        [ValidateSet("1709","1803","1809","1903","1909","2004")]
        [int]
        $OSVersion,

        # OS Short Name
        [Parameter(Mandatory,ParameterSetName="ByOSName")]
        [ValidateSet("WS2012R2","WS2016","WS2019")]
        [String]
        $OSName,

        # Architecture
        [Parameter(Mandatory)]
        [ValidateSet("x64")]
        [String]
        $Architecture,

        # Collection ID
        [Parameter(Mandatory)]
        [String]
        $CollectionId,

        # Switch Parameter to Enable newly created deployment
        [Parameter(Mandatory=$false)]
        [switch]
        $EnableDeployment,

        # Location to store Deployment Package
        [Parameter(Mandatory)]
        [ValidateScript({Test-Path $_ })]
        [ValidatePattern("\\\\")]
        [String]
        $Location,

        # Select WSUS localization settings
        [Parameter(Mandatory=$false)]
        [ValidateSet("en-us","de-de")]
        [String]
        $WsusLocalization = "en-us"
    )

    begin {
        # Connect ConfigMgr
        $modulePath = Join-Path -Path (split-path "$env:SMS_ADMIN_UI_PATH" -Parent) -ChildPath "ConfigurationManager.psd1"
        Write-Verbose "Loading ConfigMgr Module from: $modulePath"
        try {
            Import-Module $modulePath -ErrorAction Stop -Verbose:$false
            New-PSDrive -Name $CMSiteCode.Substring(0,3) -PSProvider CMSite -Root $CMSiteServerFQDN  -ErrorAction stop | Out-Null
            Push-Location -Path ($CMSiteCode + "\")
        }
        catch [System.Management.Automation.ActionPreferenceStopException] {
            throw "Could not load ConfigMgr Module"
        }
    }

    process {
        # Determine OS and ADR Name
        Write-Verbose "Parameter Set Name is : $($PSCmdlet.ParameterSetName)"
        switch ($PSCmdlet.ParameterSetName) {
            "ByOSName" {
                $adrName = "ADR_$($OSName)_$($Architecture)"
            }
            "ByOSVersion" {
                $adrName = "ADR_W10_$($OSVersion)_$($Architecture)"
            }
        }
        Write-Verbose "ADR Name will be: $adrName"

        # check for existing ADR
        if ( Get-CMAutoDeploymentRule -Name $adrName -ErrorAction SilentlyContinue -Fast) {
            throw "Automatic Deployment Rule already exists"
        }

        # Setting up ADR Parameters
        Write-Verbose "Selected WSUS Localization is: $WsusLocalization"
        $classificationArr = Import-LocalizedData -UICulture $WsusLocalization -FileName Classification

        $adrParam = @{
            Architecture = $Architecture
            CollectionId = $CollectionId
            AddToExistingSoftwareUpdateGroup = $true
            DeployWithoutLicense = $true
            Superseded = $false
            UpdateClassification = [System.Collections.ArrayList]$classificationArr.Values
            AvailableImmediately = $true
            DeadlineImmediately = $true
            RunType = "RunTheRuleAfterAnySoftwareUpdatePointSynchronization"
            UserNotification = "DisplaySoftwareCenterOnly"
            Name = $adrName
        }

        # set product
        if ($PSCmdlet.ParameterSetName -eq "ByOSVersion") {
            switch ($OSVersion) {
                {$_ -ge 1903} {
                    Write-Verbose "Setting Title filter to: Windows 10, version 1903 and later"
                    $adrParam.Add("Product","Windows 10, version 1903 and later") }
                default {
                    $adrParam.Add("Product","Windows 10")
                    Write-Verbose "Setting Title filter to: Windows 10"
                }
            }

            # set title search string
            $adrParam.Add("Title","%$OSVersion%")
        }
        else {
            switch ($OSName) {
                "WS2012R2" {
                    Write-Verbose "Setting Title filter to: Windows Server 2012 R2"
                    $adrParam.Add("Product","Windows Server 2012 R2")

                }
                "WS2016" {
                    Write-Verbose "Setting Title filter to: Windows Server 2016"
                    $adrParam.Add("Product","Windows Server 2016")
                }
                "WS2019" {
                    Write-Verbose "Setting Title filter to: Windows Server 2016"
                    $adrParam.Add("Product","Windows Server 2019")
                }
                Default {throw "OS not implemented: $OSName"}
            }
        }

        # Enable Deployment
        if ($EnableDeployment) {
            $adrParam.Add("EnabledAfterCreate",$true)
        }
        else {
            $adrParam.Add("EnabledAfterCreate",$false)
        }

        # Warn about Bug regarding architecture (doesn't get set in 1910)
        Write-Warning "The selected Target Architecture must be set manually after creation"

        # Create Deployment Package
        $dpkgName = [String]::Concat("DPKG_",$adrName)
        $adrParam.Add("DeploymentPackageName",$dpkgName)
        Write-Verbose "Deployment Package Name will be: $dpkgName"
        $dpkgLocation = Join-Path $Location -ChildPath $dpkgName
        Write-Verbose "Deployment Package Location will be: $dpkgLocation"

        If ($PSCmdlet.ShouldProcess($dpkgName,'Creating Software Update Deployment Package')) {
            #new-item $dpkgLocation -ItemType Directory -Force
            New-CMSoftwareUpdateDeploymentPackage -Name $dpkgName -Path $dpkgLocation
        }

        # Create Software Update Automatic Deployment Rule
        If ($PSCmdlet.ShouldProcess($adrName,'Creating Automatic Deployment Rule')) {
            New-CMAutoDeploymentRule @adrParam
        }
    }

    end {
        Pop-Location
    }
}