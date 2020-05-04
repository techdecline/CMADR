# Implement your module commands in this script.
Get-ChildItem -Path $PSScriptRoot -filter "function*.ps1" |
ForEach-Object {
    . $_.FullName
}


# Export only the functions using PowerShell standard verb-noun naming.
# Be sure to list each exported functions in the FunctionsToExport field of the module manifest file.
# This improves performance of command discovery in PowerShell.
Export-ModuleMember -Function New-CMOSADR
