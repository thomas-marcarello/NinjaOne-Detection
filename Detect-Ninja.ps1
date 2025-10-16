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
$Override = $false

function Write-Log {
    param (
        [switch]$Info,
        [switch]$Success,
        [switch]$Fail,
        [string]$Message
    )
    
    $DAndT = Get-Date -UFormat "%a %m-%d-%Y | %r | %Z UTC"

    if($Info.IsPresent){
        Write-Host "$DAndT - [INFO]     - $Message"
    }
    if($Success.IsPresent){
        Write-Host "$DAndT - [SUCCESS]  - $Message"
    }
    if($Fail.IsPresent){
        Write-Host "$DAndT - [FAIL]     - $Message"
    }
}

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
    Write-Log -Info -Message "Checking WMI..."
    if($null -ne $(Get-WmiObject -Class Win32_Product -ErrorAction SilentlyContinue | where-object {$_.Name -like "NinjaRMMAgent"})){
        Write-Log -Success -Message "Found NinjaRMMAgent in WMI querry."
        $check1 = $true
    }
    else {
        Write-Log -Fail -Message "NinjaRMMAgent NOT found in WMI querry."
    }

    #Checking for file path
    Write-Log -Info -Message "Checking file path..."
    if(Test-Path -Path $ProgramPath){
        Write-Log -Success -Message "Folder found."
        #Checking to make sure the RMM agent
        if(Test-Path -Path $Target){
            Write-Log -Success -Message "Agent exe found."
            $Check2 = $true
        }
        else {
            Write-Log -Fail -Message "EXE NOT found."
        }
    }
    else {
        Write-Log -Fail -Message "File path and exe NOT found."
    }

    #Checking for service and if service can be ran or is running
    Write-Log -Info -Message "Checking service running..."
    if($null -ne $(Get-Service -Name "NinjaRMMAgent" -ErrorAction SilentlyContinue)){
        Write-Log -Success -Message "NinjaRMMAgent service found."
        if($(Get-Service -Name "NinjaRMMAgent").Status -eq "Running"){
            Write-Log -Success -Message "NinjaRMMAgent service is running."
            $Check3 = $true
        }
        else {
            Write-Log -Fail -Message "NinjaRMMAgent service is NOT running."
        }
    }

    return ($Check1 -or $Check2) -and $Check3
}

function Install-NinjaOneAgent {
    param (
        [string]$NinjaURL,
        [string]$InstallLog
    )
    Start-Process msiexec.exe -ArgumentList "/i $NinjaURL /quiet /L*V $InstallLog" -Wait
}

function Remove-NinjaOneAgent {
    param (
        
    )
    
}

Write-Log -Info -Message "Override status: $Override"

#Check for Ninja agent previously installed
Write-Log -Info -Message "Checking for preexisting Ninja agent."
$NinjaInstalled = Get-NinjaAgentInstall
If($NinjaInstalled){
    Write-Log -Success -Message "NinjaRMMAgent found and working."
    If(!$Override){
        exit 0
    }
}

Write-Log -Fail -Message "NinjaRMMAgent not found or broken."