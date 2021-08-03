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
