<#Version:
       v1.1-alpha
    About:
       This script is written to remove and install the SentinelOne agent.
    Author :
       Udishman Mudiar
    Co-author :
       Sourav Mahato
    Feedback :
       Email: udishman.mudiar@sentinelone.com
       Or the engineer you are working with    
 #>

param(
    [Parameter(Mandatory=$false)]
           [String]$k,
    [Parameter(Mandatory=$true)]
            [String]$t,
    [Parameter(Mandatory=$false)]
            [String]$p,
    [Parameter(Mandatory=$false)]
            [String]$n,
    [Parameter(Mandatory=$false)]
            [Boolean]$b
)

#Replace the below parameters before running the script for debugging
#$paramPassphrase = ""
#$siteToken = ""
#$pathToSOI = "" E.x: "C:\Temp"
#$SOIName = "" E.x: "SentinelOneInstaller_windows_64bit_v24_1_4_257.exe"

function logMessage($sev, $message, $file){
    $dateUTC = [DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ss')    
    #$logFile = $logPath + "\log.txt"
    $dateUTC + "`t" + $sev + "`t" + $message >> $file
}

function checkPreReq(){
    Write-Host "Checking Pre-requsistes..." -ForegroundColor Cyan
    logMessage INFO "Checking Pre-rquisites." $logFile
    #Check Administrator Privilege
    $user = [Security.Principal.WindowsIdentity]::GetCurrent();
    $admin=(New-Object Security.Principal.WindowsPrincipal $user).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)  

    if ($admin -eq $false) {
        Write-Warning "Please run the script as Administrator"
        logMessage WARN "Script not ran as Administrator." $logFile
        Start-Sleep -s 5
        Exit
    }
    else{
        logMessage INFO "Script ran as Administrator." $logFile
    }

    #check SOI path existence
    if(!(Test-Path -Path $pathToSOI -ErrorAction SilentlyContinue)){
        Write-Warning "Path to SOI $($pathToSOI) does not exist."
        logMessage WARN "Path to SOI $($pathToSOI) does not exist." $logFile
        Start-Sleep -s 5
        Exit
    }
    else{
        logMessage INFO "Path to SOI $($pathToSOI) exist." $logFile
    }

    #check SOI existence
    if(!(Test-Path -Path $pathToSOI\$SOIName -ErrorAction SilentlyContinue)){
        Write-Warning "SOI $($SOIName) does not exist."
        logMessage WARN "SOI $($SOIName) does not exist." $logFile
        Start-Sleep -s 5
        Exit
    }
    else{
        logMessage INFO "SOI $($SOIName) exist." $logFile
    }

    Write-Host "All pre-requisistes passed.." -ForegroundColor Green
    logMessage INFO "All pre-requisistes passed." $logFile
}

function checkispathtoSOIRemote(){
    if($SOIName -match "\\\\"){
        $ispathToSOIRemote = $true
    }
    else{
        $ispathToSOIRemote = $false
    }
    return $ispathToSOIRemote
}

function getScriptDirectory
{
  $Invocation = (Get-Variable MyInvocation -Scope 1).Value
  Split-Path $Invocation.MyCommand.Path
}

function copyExeToLocalPath(){
    #copy the exe to a local path if the path is remote for better success of cleaner.
    $ispathToSOIRemote = checkispathtoSOIRemote
    if($ispathToSOIRemote)
    {
        #Write-Host "The path is remote. Copying the .exe to current path" -ForegroundColor Cyan
        $fullPathtoSOI = $pathToSOI + "\" + $SOIName    
        if(Get-ChildItem -Path $pwd.Path  -Filter $SOIName)
        {
            #Write-Host "`tThe SOI $($SOIName) is already present in the current directory $($pwd.Path)." -ForegroundColor Green
        }
        else
        {
            #Write-Host "`tThe SOI $($SOIName) is NOT present in the current directory $($pwd.Path). Copying...." -ForegroundColor Magenta
            Copy-Item -Path $fullPathtoSOI -Destination $pwd.Path
        }
        $global:currentPathSOI = $pwd.Path + "\" + $SOIName    
    }
    else
    {
        $global:currentPathSOI = $pathToSOI + "\" + $SOIName
    }
}

function checkServiceExistence(){
    logMessage INFO "Check Service existence." $logFile
    $service = Get-Service -Name SentinelAgent
    if($service){
        logMessage INFO "SentinelAgent service is present." $logFile
        if($service.Status -eq 'Running'){
            logMessage INFO "SentinelAgent service is running." $logFile
            return 1
        }
        else{
            logMessage WARN "SentinelAgent service is NOT running." $logFile
            return 0
        }
    }
    else{
        logMessage INFO "SentinelAgent service is NOT present." $logFile
    }
}

function cleanAgent($passphrase, $argscriptPath, $argscriptFullPath  ){    
    try{
            Write-Host "Running SOI -c to clean the agent..." -ForegroundColor Magenta
            logMessage INFO "Running SOI -c to clean the agent." $logFile
            
            if(-not $passphrase){
                Write-Host "Passphrase is NULL." -ForegroundColor Magenta
                logMessage WARN "Passphrase is NULL." $logFile
                $serviceexistenace = checkServiceExistence
                if($serviceexistenace -eq 1){
                    Write-Warning "S1 Agent service is running. Running SOI -c without passphrase. Might return 2021 Exit Code."
                    logMessage WARN "S1 Agent service is running. Running SOI -c without passphrase." $logFile
                    Start-Process -FilePath $currentPathSOI -ArgumentList "-c -t `"$siteToken`" -q" -NoNewWindow -wait 
                }
                else{
                    Write-Host "S1 Agent service is running. Running SOI -c without passphrase." -ForegroundColor Magenta
                    logMessage INFO "S1 Agent service is running. Running SOI -c without passphrase." $logFile
                    Start-Process -FilePath $currentPathSOI -ArgumentList "-c -t `"$siteToken`" -q" -NoNewWindow -wait 
                }
            }
            else{
                logMessage INFO "Passphrase is present. Running SOI -c with -k." $logFile
                Start-Process -FilePath $currentPathSOI -ArgumentList "-c -k `"$passphrase`" -t `"$siteToken`" -q" -NoNewWindow -wait    
            }               
    
            $exitcodeS1 = (Get-Content -Path C:\Windows\Temp\SC-exit-code.txt)
            if($exitcodeS1 -eq '0')
            {
                Write-Host "The cleaning is successfull. Exit code is $($exitcodeS1). Proceeding with installaton...." -ForegroundColor "Cyan"
                logMessage INFO "The cleaning is successfull. Exit code is $($exitcodeS1). Proceeding with installaton." $logFile
                #install with silent switch
                Start-Process -FilePath $currentPathSOI -ArgumentList "-f --dont_fail_on_config_preserving_failures -t `"$siteToken`" -q" -NoNewWindow -Wait
                
                $exitcodeS1 = (Get-Content -Path C:\Windows\Temp\SC-exit-code.txt)
                if($exitcodeS1 -eq '0')
                {
                    Write-Host "The installation is successful. Exit code is $($exitcodeS1)." -ForegroundColor Green
                    logMessage INFO "The installation is successful. Exit code is $($exitcodeS1)." $logFile          
                }        
                elseif($exitcodeS1 -ne '0' -or $exitcodeS1 -ne '12' -or $exitcodeS1 -ne '100' -or $exitcodeS1 -ne '101' -or $exitcodeS1 -ne '103' -or $exitcodeS1 -ne '104' -or $exitcodeS1 -ne '200')
                {
                    Write-Warning "The installation is NOT successfull. Exit code is $($exitcodeS1)." -ForegroundColor Yellow
                    logMessage INFO "The installation is NOT successfull. Exit code is $($exitcodeS1)." $logFile 
                }
            }    
            elseif($exitcodeS1 -eq '200')
            {
                Write-Host "`tThe cleaning will be successful after reboot. Exit code is $($exitcodeS1)." -ForegroundColor Cyan
                logMessage INFO "The cleaning will be successful after reboot. Exit code is $($exitcodeS1)." $logFile 
                
                #Before the reboot, adding a Task Scheduler task to reinstall the agent after reboot            
                logMessage INFO "Before the reboot, adding a Task Scheduler task to reinstall the agent after reboot " $logFile 

                createTask $argscriptPath $argscriptFullPath                
                
                if($boot){
                    Write-Warning "Removal Completed. Rebooting computer as boot parameter was set to true. After reboot, installation will proceed."
                    logMessage WARN "RRemoval Completed. Rebooting computer as boot parameter was set to true. After reboot, installation will proceed." $logFile 
                    Start-Sleep -Seconds 5  # Pauses for 5 seconds
                    Restart-Computer -Force -Confirm:$false
                }
                else{
                    Write-Warning "Removal Completed. Restart the computer for installation to complete successfully."
                    logMessage WARN "Removal Completed. Restart the computer for installation to complete successfully." $logFile 
                    Start-Sleep -Seconds 5  # Pauses for 5 seconds
                }                
            }
            elseif($exitcodeS1 -eq '2021' ){
                Write-Host "`tThe cleaning process failed. Exit code is $($exitcodeS1)." -ForegroundColor Yellow
                Write-Host "`tAuthorization failed. Make sure 'Confirm Local Upgrade' is done on console for the endpoint. Or 'Site Wide Authorization' is done." -ForegroundColor Yellow
                Write-Host "`tIf the above points are already done and verified. Escalate the issue to S1 support." -ForegroundColor Yellow
                logMessage ERROR "The cleaning process failed. Exit code is $($exitcodeS1)" $logFile 
            }
            elseif($exitcodeS1 -ne '0' -or $exitcodeS1 -ne '12' -or $exitcodeS1 -ne '100' -or $exitcodeS1 -ne '101' -or $exitcodeS1 -ne '103' -or $exitcodeS1 -ne '104' -or $exitcodeS1 -ne '200')
            {
                Write-Host "`tThe cleaning process failed. Exit code is $($exitcodeS1)" -ForegroundColor Yellow
                logMessage ERROR "The cleaning process failed. Exit code is $($exitcodeS1)" $logFile 
            } 
        }
        catch{
            $ErrorMessage = $_.Exception.Message
            logMessage ERROR "Cleaning failed with $($ErrorMessage)" $logFile 
            Write-Error "Cleaning failed with $($ErrorMessage)"
            exit
        }
}

function checkTask(){
    if(Get-ScheduledTask -TaskName "SentinelOne Installer Startup" -ErrorAction SilentlyContinue){
        #Write-Host "Task 'SentinelOne Installer Startup' is already present. Not proceeding with creating the same task." -ForegroundColor Cyan
        logMessage INFO "Task 'SentinelOne Installer Startup' found" $logFile
        return 1
    }
    else{
        logMessage INFO "Task 'SentinelOne Installer Startup' not found." $logFile
        return 0
        #Write-Host "Task 'SentinelOne Installer Startup' not found. -ForegroundColor Magenta        
    }
}

function createTask($arg2scriptPath, $arg2scriptFullPath){  
  
    $taskTrigger = New-ScheduledTaskTrigger -AtStartup
    $Settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
    $taskAction = New-ScheduledTaskAction -Execute "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -File $arg2scriptFullPath -t $siteToken -p $pathToSOI -n $SOIName" -WorkingDirectory $arg2scriptPath
    Register-ScheduledTask 'SentinelOne Installer Startup' -Action $taskAction -Trigger $taskTrigger -Settings $Settings -User "SYSTEM" -RunLevel Highest | Out-Null
}

function deleteTask(){
    Get-ScheduledTask -TaskName "SentinelOne Installer Startup" | Unregister-ScheduledTask -Confirm:$false
}

function startupTask(){
    $startuplogFile = $logPath + "\" + "startup_log_$($dateUTC).txt"
    logMessage INFO "Task 'SentinelOne Installer Startup' is already present." $startuplogFile
    #Write-Host "Task 'SentinelOne Installer Startup' is already present."
    #Write-Host "Check if the last Exit Code is 200."
    logMessage INFO "Check if the last Exit Code is 200." $startuplogFile

    $exitcodeS1 = (Get-Content -Path C:\Windows\Temp\SC-exit-code.txt)
    if($exitcodeS1 -eq 200){
        logMessage INFO "The last Exit Code is 200. Procceding with installation of the agent." $startuplogFile
        #Write-Host "The last Exit Code is 200. Procceding with installation of the agent.."
        copyExeToLocalPath
        Start-Process -FilePath $currentPathSOI -ArgumentList "-f --dont_fail_on_config_preserving_failures -t `"$siteToken`" -q" -NoNewWindow -Wait

        $exitcodeS1 = (Get-Content -Path C:\Windows\Temp\SC-exit-code.txt)
        if($exitcodeS1 -eq 0)
        {
            logMessage INFO "The Exit Code after running the installation from startup is 0. The agent installation is successful." $startuplogFile
            logMessage INFO "Deleting the task 'SentinelOne Installer Startup'. So that it does not run at the next startup." $startuplogFile
            deleteTask
            checkTask                
        }
        else
        {
            logMessage WARN "The last Exit Code is not equal to 0. It is $($exitcodeS1)." $startuplogFile
            logMessage INFO "Deleting the task 'SentinelOne Installer Startup'. So that it does not run at the next startup." $startuplogFile
            deleteTask
        }
    }
    # We are deleting the task 'SentinelOne Installer Startup' if the last Exit Code is not 200. Only if is 200 we will have a success in running the installer after reboot.
    else{
        #Write-Host "The last Exit Code is not equal to 200. It is $($exitcodeS1). Deleting the task 'SentinelOne Installer Startup'"
        logMessage INFO "The last Exit Code is not equal to 200. It is $($exitcodeS1). Deleting the task 'SentinelOne Installer Startup'" $startuplogFile               
        deleteTask
    }    
}

#main
try{
    $Invocation = (Get-Variable MyInvocation).Value
    $logPath =  Split-Path $Invocation.MyCommand.Path
    $dateUTC = [DateTime]::UtcNow.ToString('yyyy-MM-ddTHH_mm_ss')    
    $logFile = $logPath + "\" + "log_$($dateUTC).txt"
    logMessage INFO "Script Starting." $logFile

    $paramPassphrase = $k
    $siteToken = $t
    $pathToSOI = $p
    $SOIName = $n
    $boot = $b
    logMessage INFO "Arguments passed are:" $logFile
    logMessage INFO "Passphrase  : $($paramPassphrase)" $logFile
    logMessage INFO "Site Token  : $($siteToken)" $logFile
    logMessage INFO "Path to SOI : $($pathToSOI)" $logFile
    logMessage INFO "SOI Name    : $($SOIName)" $logFile
    logMessage INFO "Boot flag   : $($boot)" $logFile

    if($b -eq $NULL){
        $boot = $false
    }    

    checkPreReq
    
    $taskReturn = checkTask
    if($taskReturn -eq 1){
        startupTask        
    }
    else{
        #Write-Host "Task 'SentinelOne Installer Startup' is not present. Treating as a new installer."
        logMessage INFO "Task 'SentinelOne Installer Startup' not found. Treating as a new installer." $logFile

        copyExeToLocalPath       

        # start the cleaning process
        Write-Host "Starting the cleaning process..." -ForegroundColor Cyan
        logMessage INFO "Starting the cleaning process." $logFile        
            
        $scriptPath = getScriptDirectory
        $scriptFullPath = $MyInvocation.MyCommand.Path 
        cleanAgent $paramPassphrase $scriptPath  $scriptFullPath       
    }      
}
catch{
    $ErrorMessage = $_.Exception.Message
    Write-Error "Script failed with $($ErrorMessage)."
    logMessage ERROR "Script failed with $($ErrorMessage)" $logFile 
}




