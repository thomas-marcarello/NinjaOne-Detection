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
$InstallLogPath = $env:TEMP
$InstallLogFile = "$InstallLogPath\ninjaone.log"

$NinjaURL = Get-SyncroSelection -Client "NCSC" #Remove this line and replace with switch case that this function performs.

#Write-Host $NinjaURL

#Detection function
function Get-NinjaAgentInstall {
    #Variable declaration
    $Check1 = $false
    $Check2 = $false
    $Check3 = $false
    $ProgramPath = "C:\Program Files (x86)\NinjaOne"
    $Agent = "NinjaRMMAgent.exe"
    $Target = "$Programpath\$Agent"

    #Checking WMI for ninja install instance, in a botched install instance, this may detect
    if($null -ne $(Get-WmiObject -Class Win32_Product | where-object {$_.Name -like "NinjaRMMAgent"})){
        $check1 = $true
    }

    #Checking for file path
    if(Test-Path -Path $ProgramPath){
        #Checking to make sure the RMM agent
        If(Test-Path -Path $Target){
            $Check2 = $true
        }
    }

    #Checking for service and if service can be ran or is running
    if($null -ne $(Get-Service -Name "NinjaRMMAgent" -ErrorAction SilentlyContinue)){
        if($(Get-Service -Name "NinjaRMMAgent").Status -eq "Running"){
            $Check3 = $true
        }
    }

    return $Check1 -and $Check2 -and $Check3
}

Write-Host $(Get-NinjaAgentInstall)