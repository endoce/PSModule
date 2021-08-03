##
## Joe PS Module
##
## C:\WINDOWS\system32\WindowsPowerShell\v1.0\Modules
##
## Function
## 1. Get-SecurityAgents -ComputerName $ComputerName [-Remediation=1]
## 2. Restore-Snapshot -ComputerName $ComputerName
## 3. Update-Snapshot -VMName $VMname -Sendto $Sendto -Wait $Mins
## 4. NewVM-Initial -ComputerName $ComputerName
## 5. KeepMeAlive -minutes $minutes
##

#region 1. Get-SecurityAgents
Function Get-SecurityAgents{
    
    ## Bingding Parameters
    [CmdletBinding()]

    # Parameters
    param (
        [Parameter(Mandatory)][String[]]$ComputerName,[string]$Remediation="1"
    )
    $Services = @(
        "CSFalconService",
        "ir_agent",
        "SplunkForwarder"
    )

    # Get currently services status
    # Ignore any errors
    # Print out the result
    
    $ServicesStatus = Get-Service -ComputerName $ComputerName -Name $Services -ErrorAction SilentlyContinue | Select-Object Name,Status,StartType,DisplayName,MachineName
    $ServicesStatus | Format-Table

    # If need remediation
    if($Remediation -ne $False){

        # Restart any stopped service
        foreach($SSA_Service in $ServicesStatus){

            # Remediating status
            if($SSA_Service.Status -eq "Stopped"){
                Write-Warning "Trying to start $($SSA_Service.Name) service..."
                Get-Service -ComputerName $ComputerName -Name $SSA_Service.Name | Start-Service -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
            }

            # Remediating starttype
            if($SSA_Service.StartType -ne "Automatic"){
                Write-Warning "Trying to set $($SSA_Service.Name) starttype to automatic..."
                Get-Service -ComputerName $ComputerName -Name $SSA_Service.Name | Set-Service -StartupType Automatic -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
            }
        } 

        # Get fixed services and print out
        Write-Warning "Getting services status after remediation..."
        $ServicesStatus_Fixed = Get-Service -ComputerName $ComputerName -Name $Services -ErrorAction SilentlyContinue | Select-Object Name,Status,StartType,DisplayName,MachineName
        $ServicesStatus_Fixed | Format-Table
    }
}
#endregion

#region 2. Restore-Snapshot
Function Restore-Snapshot{
    [CmdletBinding()]
    param(
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 0
            )]
        [string]  $ComputerName
    )
    
    BEGIN {}
    
    PROCESS {
        ## Define and connect to VMM server
        $VMMServer = 'CNSHVWITVMM2.infor.com'
        Get-SCVMMServer $VMMServer | Out-Null

        $VM = Get-SCVirtualMachine -Name $ComputerName
        $CheckpointList = Get-SCVMCheckpoint -VM $VM

        Write-Host "There are"$CheckpointList.Length"checkpoints for $ComputerName."  -BackgroundColor White -ForegroundColor DarkBlue

        for ($i=1; $i -le $CheckpointList.Length; $i++) {
            $Checkptname = $CheckpointList[$i-1].Name
            Write-Host "$i - $Checkptname"   -BackgroundColor White -ForegroundColor Black
        }

        [int]$SelectCheckpoint = (Read-Host "Which one?")-1
        
        $SelectName = $CheckpointList[$SelectCheckpoint].Name
        Write-Host "Will revert $SelectName"   -BackgroundColor White -ForegroundColor DarkBlue

        Write-Host "Reverting $SelectName."  -BackgroundColor Yellow -ForegroundColor DarkBlue
        Restore-SCVMCheckpoint -VMCheckpoint $CheckpointList[$SelectCheckpoint]

        Write-Host "Power up $ComputerName"  -BackgroundColor Yellow -ForegroundColor DarkBlue
        Start-SCVirtualMachine -VM $ComputerName

    }
    
    END {}
}
#endregion

#region 3. Refresh-Snapshot
Function Update-Snapshot{
    [CmdletBinding()]
    param(
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 0
            )]
        [string]  $ComputerName,
        [Parameter(
            Mandatory = $true
        )]
        [string]  $Mailto,
        [Parameter(
            Mandatory = $false
        )]
        [string]  $Wait
    )
 
    BEGIN {}
 
    PROCESS {
        ## Show input information
        Write-Host "You've inputed VM name $ComputerName" -ForegroundColor Green

        $VMMServer = "CNSHVWITVMM2.infor.com"
        Get-SCVMMServer $VMMServer | Out-Null

        $VM = Get-SCVirtualMachine -Name $ComputerName
        $CheckpointList = Get-SCVMCheckpoint -VM $VM
    
        Write-Host "There are"$CheckpointList.Length"checkpoints for $ComputerName." -ForegroundColor Yellow
    
        for ($i=1; $i -le $CheckpointList.Length; $i++){
            $Checkptname = $CheckpointList[$i-1].Name
            Write-Host "$i $Checkptname"   -ForegroundColor Yellow
        }

        [int]$SelectCheckpoint = (Read-Host "Which one?")-1

        $Keepname = Read-Host "Do you want to use the same name?(y/n)"
        if($Keepname -eq 'y'){
            $NewName = $CheckpointList[$SelectCheckpoint].Name
        }else{
            $NewName = Read-Host "Input the name name:"
        }

        #Wait for designated mins
        if($Wait -gt 0){
        Write-Host "Wating $Wait mins to start..." -ForegroundColor Red
        Start-Sleep -Seconds $($Wait*60)
        }

        if((Get-SCVirtualMachine -Name $ComputerName).Status -ne "PowerOff"){
            Write-Host "$ComputerName is running, stop it now." -ForegroundColor Green
            Stop-SCVirtualMachine -VM $VM
            Start-Sleep -Seconds 30
            if((Get-SCVirtualMachine -Name $ComputerName).Status -ne "PowerOff"){
                Stop-SCVirtualMachine -VM $VM -Force
                }
        }

        Write-Host "Removing checkpoint..." -ForegroundColor Green
        Remove-SCVMCheckpoint -VMCheckpoint $CheckpointList[$SelectCheckpoint] -ErrorAction Suspend


        do {
            Start-Sleep -Seconds 60
        }while((Get-SCVirtualMachine -Name $ComputerName).Status -ne "PowerOff")

        Write-Host "Creating checkpoint..." -ForegroundColor Green
        New-SCVMCheckpoint -VM $VM -Name $NewName -Description (Get-Date) -ErrorAction Suspend

        do {
            Start-Sleep -Seconds 60
        }while((Get-SCVirtualMachine -Name $ComputerName).Status -ne "PowerOff")

        # Start VM
        Write-Host "Starting VM..." -ForegroundColor Green
        Start-SCVirtualMachine -VM $VM

        $OldName = $CheckpointList[$SelectCheckpoint].Name

        ## Send email when completed
        $smtpserver = 'mail.infor.com'
        $adminmail = 'Joe.Chang@infor.com'
        $mailfrom = 'VM_Automation@infor.com'
        $subject = 'Refresh checkpoint '+$CheckpointName+' for VM '+$ComputerName+' is completed.'
        $body = "Removed $OldName, and created $NewName."
        Send-MailMessage -From $mailfrom -To $Mailto,$adminmail -Subject $subject -SmtpServer $smtpserver -Body $body

    }
 
    END {}
}
#endregion

#region 4. NewVM-Initial
Function Initialize-NewVM {

    [CmdletBinding()]
    param(
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 0
            )]
        [string]  $ComputerName
    )
 
    BEGIN {
        # New pssession 
        $NewSession = New-PSSession -ComputerName $ComputerName
    }
 
    PROCESS {
        Invoke-Command -Session $NewSession -ScriptBlock {
            param($VMNameSession=$ComputerName)
    
            Function FDomainuser{
                #stop until you input a domain user
                do{
                    $FDomainUser = Read-Host "Input the domain username"
                    if($FDomainUser -like "infor\*") {  
                        Write-Host $FDomainUser"will be added to the local admin group." -BackgroundColor DarkGreen -ForegroundColor Yellow
                        return $FDomainUser
                        }
                    #this make sure the name does not include ~!@#$%^....
                    elseif("~!@#$%^&`/\|" -contains $FDomainUser) {
                        Write-Host $FDomainUser" is not a valid domain user." -BackgroundColor DarkGreen -ForegroundColor Yellow
                        $FDomainUser = FDomainuser
                        return $FDomainUser
                        }
                    else {
                        #if you just input name without infor\, add it
                        $FDomainUser = "infor\"+$FDomainUser 
                        Write-Host $FDomainUser" will be added to the local admin group." -BackgroundColor DarkGreen -ForegroundColor Yellow
                        return $FDomainUser
                        }
                }while($FDomianUser -eq "") 
            }
    
            if($env:COMPUTERNAME -ne $VMNameSession){
                Write-Host "Name not matched."
                Exit
            }
    
            # Define
            $adminAcct = "Administrator"
            $adminPass = "P@ssword"
            $username = "it"
            $userPass = "P@ssword"
            $group = "Administrators"
            $serveradminaccount = "infor\ACD-WW-Server Admins"
            $cnshadminaccount = "infor\ACL-CNSH-IT"
    
            # 1. Change administrator's password
            Write-Host "Changing local admin password." -ForegroundColor Green
            Net User $adminAcct $adminPass
    
            # 2. Add a new admin user
            Write-Host "Adding new local admin user." -ForegroundColor Green
            NET USER $Username $userPass /add /y /expires:never
            NET LOCALGROUP $group $Username /add
            WMIC USERACCOUNT WHERE "Name='$Username'" SET PasswordExpires=FALSE
    
            # 3. Add IT local admin group
        #    Write-Host "$VMName_S is running, stop it now." -ForegroundColor Green
        #    NET LOCALGROUP $group $ITaccount /add
    
            # 4. Enable remote desktop
            Write-Host "Enabling remote desktop." -ForegroundColor Green
            Set-ItemProperty -Path 'HKLM:SYSTEM\CurrentControlSet\Control\Terminal Server' -Name fDenyTSConnections -Value 0
    
            # 5. Disable windows firewall
            Write-Host "Disabling windows firewall." -ForegroundColor Green
            Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled False
    
            # 6. Adding VM admin
            NET LOCALGROUP $group $serveradminaccount /add
            NET LOCALGROUP $group $cnshadminaccount /add
            While((Read-Host "Do you want to add user to local admin group? y/n") -eq 'y'){
                $adminaccount = FDomainuser
                Write-Host "Adding $adminaccount to local admin group." -ForegroundColor Green
                NET LOCALGROUP $group $adminaccount /add
            }
    
            # Pause
            pause
    
    
        } -ArgumentList $ComputerName
    }
 
    END {
        Remove-PSSession $NewSession
    }
}
#endregion

#region 5. KeepMeAlive
function KeepMeAlive {
    param (
        $minutes = 60
    )

    $myshell = New-Object -com "Wscript.Shell"

    for ($i = 0; $i -lt $minutes; $i++) {
    Start-Sleep -Seconds 60
    $myshell.sendkeys(".")
    }
}
#endregion
