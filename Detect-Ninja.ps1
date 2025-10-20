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

$NinjaDownloadURL = Get-SyncroSelection -Client "NCSC" #Remove this line and replace with switch case that this function performs.
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
    # Ninja Uninstall Script
    # to be deleted:
    # Usage: [-Uninstall] [-Cleanup]
    #   -Uninstall calls msiexec {ninjaRmmAgent product ID}
    #   -Cleanup removes keys, files, services
    # Examples:
    #
    # NewAgentRemoval.ps1 -Uninstall
    #   disables uninstall prevention and uninstalls using msiexec, does not check if there are any leftovers
    #
    # NewAgentRemoval.ps1 -Cleanup
    #   removes keys, files, services related to NinjaRMMProduct, does not use amy msiexec, uninstall prevention status is ignored
    #
    # NewAgentRemoval.ps1  -Uninstall -Cleanup
    #   combines two actions together
    #   order of arguments does not matter, msiexec is called first, cleanup goes second
    param (
        [Parameter(Mandatory=$false)]
        [switch]$Cleanup,
        [Parameter(Mandatory=$false)]
        [switch]$Uninstall,
        [Parameter(Mandatory=$false)]
        [switch]$ShowError
    )

    $ErrorActionPreference = 'SilentlyContinue'

    if($ShowError -eq $true) {
        $ErrorActionPreference = 'Continue'
    }

    Write-Log -Info -Message "Running Ninja Removal Script"

    if([system.environment]::Is64BitOperatingSystem)
    {
        $ninjaPreSoftKey = 'HKLM:\SOFTWARE\WOW6432Node\NinjaRMM LLC'
        $uninstallKey = 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall'
        $exetomsiKey = 'HKLM:\SOFTWARE\WOW6432Node\EXEMSI.COM\MSI Wrapper\Installed'
    }
    else
    {
        $ninjaPreSoftKey = 'HKLM:\SOFTWARE\NinjaRMM LLC'
        $uninstallKey = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall'
        $exetomsiKey = 'HKLM:\SOFTWARE\EXEMSI.COM\MSI Wrapper\Installed'
    }

    $ninjaSoftKey = Join-Path $ninjaPreSoftKey -ChildPath 'NinjaRMMAgent'

    $ninjaDir = [string]::Empty
    $ninjaDataDir = Join-Path -Path $env:ProgramData -ChildPath "NinjaRMMAgent"

    ###################################################################################################
    # locating NinjaRMMAgent
    ###################################################################################################
    $ninjaDirRegLocation = $(Get-ItemPropertyValue $ninjaSoftKey -Name Location) 
    if($ninjaDirRegLocation)
    {
        if(Join-Path -Path $ninjaDirRegLocation -ChildPath "NinjaRMMAgent.exe" | Test-Path)
        {
            #location confirmed from registry location
            $ninjaDir = $ninjaDirRegLocation
            Write-Log -Info -Message "Ninja folder found at: $ninjaDir"
        }
    }

    if(!$ninjaDir)
    {
        #attempt to get the path from service
        $ss = Get-WmiObject win32_service -Filter 'Name Like "NinjaRMMAgent"'
        if($ss)
        {
            $ninjaDirService = ($(Get-WmiObject win32_service -Filter 'Name Like "NinjaRMMAgent"').PathName | Split-Path).Replace("`"", "")
            if(Join-Path -Path $ninjaDirService -ChildPath "NinjaRMMAgentPatcher.exe" | Test-Path)
            {
                #location confirmed from service location
                $ninjaDir = $ninjaDirService
                Write-Log -Info -Message "Ninja folder found at: $ninjaDir"
            }
        }
    }

    if($ninjaDir)
    {
        $ninjaDir.Replace('/','\')
    }
    else {
        Write-Log -Fail -Message "Unable to locate NinjaOne folder."
    }

    if($Uninstall -and (Join-Path -Path $ninjaDir -ChildPath "NinjaRMMAgentPatcher.exe" | Test-Path))
    {
        Write-Log -Info -Message "Attempting to uninstall NinjaOne."
        #there are few measures agent takes to prevent accidental uninstllation
        #disable those measures now
        #it automatically takes care if those measures are already removed
        Start-Process -FilePath "$ninjaDir\NinjaRMMAgent.exe" -ArgumentList "-disableUninstallPrevention NOUI"
        # Executes uninstall.exe in Ninja install directory
        $Arguments = @(
            "/uninstall"
            $(Get-WmiObject -Class win32_product -Filter "Name='NinjaRMMAgent'").IdentifyingNumber
            "/quiet"
            "/log"
            "$env:temp\NinjaRMMAgent_uninstall.log"
            "/L*v"
            "WRAPPED_ARGUMENTS=`"--mode unattended`""
        )
        Start-Process -FilePath "msiexec.exe"  -Verb RunAs -Wait -NoNewWindow -WhatIf -ArgumentList $Arguments
        Write-Log -Info -Message "Attempt to uninstall NinjaOne complete."
    }


    if($Cleanup)
    {
        Write-Log -Info -Message "Starting cleanup process"
        $Search = "NinjaRMMAgent"
        Write-Log -Info -Message "Searching for service: $Search"
        $service=Get-Service $Search
        if($service)
        {
            Write-Log -Success -Message "Found service: $Search"
            Write-Log -Info -Message "Stopping and deleting service: $Search"
            Stop-Service $service -Force
            & sc.exe DELETE NinjaRMMAgent
            #Computer\HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\NinjaRMMAgent
        }
        else{
            Write-Log -Fail -Message "Service not found: $Search"
        }
        $Search = "NinjaRMMProxyProcess64"
        Write-Log -Info -Message "Searching for service: $Search"
        $proxyservice=Get-Process $Search
        if($proxyservice)
        {
            Write-Log -Success -Message "Found service: $Search"
            Write-Log -Info -Message "Stopping and deleting service: $Search"
            Stop-Process $proxyservice -Force
            & sc.exe DELETE NinjaRMMAgent
        }
        else{
            Write-Log -Fail -Message "Service not found: $Search"
        }
        $Search = "nmsmanager"
        Write-Log -Info -Message "Searching for service: $Search"
        $nmsservice=Get-Service $Search
        if($nmsservice)
        {
            Write-Log -Success -Message "Found service: $Search"
            Write-Log -Info -Message "Stopping and deleting service: $Search"
            Stop-Service $nmsservice -Force
            & sc.exe DELETE nmsmanager
        }
        else{
            Write-Log -Fail -Message "Service not found: $Search"
        }
        # Delete Ninja install directory and all contents
        Write-Log -Info -Message "Removing directory and child files: $ninjaDir"
        if(Test-Path $ninjaDir)
        {
            Remove-Item -Path $ninjaDir -Recurse -Force
            Write-Log -Success -Message "Directory removes successfully: $ninjaDir"
        }
        else {
            Write-Log -Fail -Message "Directory does not exist: $ninjaDir"
        }

        Write-Log -Info -Message "Removing directory and child files: $ninjaDataDir"
        if(Test-Path $ninjaDataDir)
        {
            Remove-Item -Path $ninjaDataDir -Recurse -Force
            Write-Log -Success -Message "Directory removes successfully: $ninjaDataDir"
        }
        else {
            Write-Log -Fail -Message "Directory does not exist: $ninjaDataDir"
        }

        # Will search registry locations for NinjaRMMAgent value and delete parent key
        Write-Log -Info -Message "Searching registry keys for uninstall key."
        $keys = Get-ChildItem $uninstallKey | Get-ItemProperty -name 'DisplayName'
        foreach ($key in $keys) {
            if ($key.'DisplayName' -eq 'NinjaRMMAgent'){
                Remove-Item $key.PSPath -Recurse -Force
                Write-Log -Success -Message "Key found and removed: $key"
            }
        }
        Write-Log -Info -Message "Search complete."

        #Search $installerKey
        Write-Log -Info -Message "Searching registry keys for installer key."
        $keys = Get-ChildItem 'HKLM:\SOFTWARE\Classes\Installer\Products' | Get-ItemProperty -name 'ProductName'
        foreach ($key in $keys) {
            if ($key.'ProductName' -eq 'NinjaRMMAgent'){
                Remove-Item $key.PSPath -Recurse -Force
                Write-Log -Success -Message "Key found and removed: $key"
            }
        }
        Write-Log -Info -Message "Search complete."

        Write-Log -Info -Message "Searching registry keys for extrenious key."
        $keys = Get-ChildItem 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Installer\UserData\S-1-5-18\Products'
        foreach ($key in $keys) {
            $kn = $key.Name -replace 'HKEY_LOCAL_MACHINE' , 'HKLM:'; 
            $k1 = Join-Path $kn -ChildPath 'InstallProperties';
            if( $(Get-ItemProperty -Path $k1 -Name DisplayName).DisplayName -eq 'NinjaRMMAgent')
            {
                Get-Item -LiteralPath $kn | Remove-Item -Recurse -Force
                Write-Log -Success -Message "Key found and removed: $key"
            }
        }
        Write-Log -Info -Message "Search complete."

        #Computer\HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\EXEMSI.COM\MSI Wrapper\Installed\NinjaRMMAgent 5.3.3681
        Get-ChildItem $exetomsiKey | Where-Object -Property Name -CLike '*NinjaRMMAgent*'  | Remove-Item -Recurse -Force

        #HKLM:\SOFTWARE\WOW6432Node\NinjaRMM LLC
        Get-Item -Path $ninjaPreSoftKey | Remove-Item -Recurse -Force

        # agent creates this key by mistake but we delete it here
        Get-Item -Path "HKLM:\SOFTWARE\WOW6432Node\WOW6432Node\NinjaRMM LLC" | Remove-Item -Recurse -Force

    ###################Write-Progress -Activity "Running Ninja Removal Script" -Status "Cleanup Completed" -PercentComplete 75
    }

    if(Get-Item -Path $ninjaPreSoftKey)
    {
        Write-Log -Fail -Message "Failed to remove NinjaRMMAgent reg keys: $ninjaPreSoftKey"
    }

    if(Get-Service "NinjaRMMAgent")
    {
        Write-Log -Fail -Message "Failed to remove NinjaRMMAgent service"
    }

    if($ninjaDir)
    {
        if(Test-Path $ninjaDir)
        {
            Write-Log -Fail -Message "Failed to remove NinjaRMMAgent program folder"
            if(Join-Path -Path $ninjaDir -ChildPath "NinjaRMMAgent.exe" | Test-Path)
            {
                Write-Log -Fail -Message "Failed to remove NinjaRMMAgent.exe"
            }

            if(Join-Path -Path $ninjaDir -ChildPath "NinjaRMMAgentPatcher.exe" | Test-Path)
            {
                Write-Log -Fail -Message "Failed to remove NinjaRMMAgentPatcher.exe"
            }
        }
    }

    Write-Log -Info -Message "Cleanup complete."

    $error | out-file C:\Windows\Temp\NinjaRemovalScriptError.txt
}

Write-Log -Info -Message "Override status: $Override"

#Check for Ninja agent previously installed
Write-Log -Info -Message "Checking for preexisting Ninja agent."
$NinjaInstalled = Get-NinjaAgentInstall
If($NinjaInstalled){
    Write-Log -Success -Message "NinjaRMMAgent found and working."
    If(!$Override){
        Write-Log -Info -Message "Override enabled, force reinstalling NinjaOne agent"
        Remove-NinjaOneAgent -Uninstall -Cleanup
    }
}
else{
    Write-Log -Fail -Message "NinjaRMMAgent not found or broken."
    Remove-NinjaOneAgent -Cleanup
}

#No matter what, we reinstall NinjaOne
Install-NinjaOneAgent -NinjaURL $NinjaDownloadURL -InstallLog $InstallLogFile