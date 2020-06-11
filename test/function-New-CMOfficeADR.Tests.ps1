$moduleName = "CMADR"
Remove-Module $moduleName -Force -ErrorAction SilentlyContinue

Import-Module "$PSScriptRoot\..\$moduleName.psd1"

Describe "New-CMOfficeADR Function Test" {

}