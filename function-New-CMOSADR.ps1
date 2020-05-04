<#
    .SYNOPSIS
    .DESCRIPTION
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
        [ValidateSet("1709","1809","1903","1909")]
        [int]
        $OSVersion,

        # OS Short Name
        [Parameter(Mandatory=$false)]
        [ValidateSet("WS2012R2","WS2016")]
        [String]
        $OSName,

        # Architectur
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
        $Location
    )

    begin {

    }

    process {

    }

    end {

    }
}