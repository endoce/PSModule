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
