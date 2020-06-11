<#
    .SYNOPSIS
    Creates an Automatic Deployment Rule including Deployment Package and Deployment for Microsoft Office.
    .DESCRIPTION
    Creates an Automatic Deployment Rule including Deployment Package and Deployment for Microsoft Office.
    .EXAMPLE
    PS> New-CMOfficeADR -CMSiteCode dec: -CMSiteServerFQDN cm001.techdecline.com -OfficeVersion Office2019 -Architecture x86 -CollectionId DEC0007A -EnableDeployment -Location \\cm001\SUP\ -WsusLocalization en-us

    Will Create an Automatic Deployment Rule for Office 2019 (x86) with an active Deployment
#>
function New-CMOfficeADR {
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

        # Office Version
        [Parameter(Mandatory)]
        [ValidateSet("Office2019")]
        [string]
        $OfficeVersion,

        # Architecture
        [Parameter(Mandatory)]
        [ValidateSet("x64","x86")]
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
        # Determine Office Version and ADR Name
        $adrName = "ADR_$($OfficeVersion)_$($Architecture)"
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
            Product = "Office 365 Client"
        }

        # set title
        switch ($OfficeVersion) {
            "Office2019" {
                Write-Verbose "Setting Title filter to: Office 2019"
                $adrParam.Add("Title","Office 2019%") }
            default {

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