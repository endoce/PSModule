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
