#require -version 5.1
<#
    .SYNOPSIS
        This script detects and installs ninja as needed.
    .DESCRIPTION
        This script checks for 3 methods of detection. If all 3 methods come back true, the script stops executing. If one method fails, it installs or force uninstalls then reinstalls the NinjaOne agent.
    .NOTES
        By: Thomas Marcarello
#>

#To remove
Import-Module .\Company_List.psm1

#Variable declaration
$InstallLog = "$env:TEMP\ninjaone.log"

$NinjaURL = Get-SyncroSelection -Client "NCSC" #Remove this line and replace with switch case that this function performs.

Write-Host $NinjaURL