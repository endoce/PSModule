## Used for service checking
## 1. CiscoAMP* - Cisco AMP
## 2. CSFalconService - CrowdStrike
## 3. ir_agent - Rapid 7
## 4. SplunkForwarder - Splunk
Function Get-SecurityAgents{
    
    ## Bingding Parameters
    [CmdletBinding()]

    # Parameters
    param (
        [Parameter(Mandatory)][String[]]$ComputerName,[string]$Remediation="1"
    )
    $Services = @(
        "CiscoAMP_7.1.5",
        "CiscoAMP_7.2.3",
        "CiscoAMP_7.2.7",
        "CiscoAMP_7.3.9",
        "CiscoAMP_7.3.15",
        "CSFalconService",
        "ir_agent",
        "SplunkForwarder"
    )

    # Get currently services status
    # Ignore any errors
    # Print out the result
    
    $ServicesStatus = Get-Service -ComputerName $ComputerName -Name $Services -ErrorAction SilentlyContinue | Select Name,Status,StartType,DisplayName,MachineName
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
        $ServicesStatus_Fixed = Get-Service -ComputerName $ComputerName -Name $Services -ErrorAction SilentlyContinue | Select Name,Status,StartType,DisplayName,MachineName
        $ServicesStatus_Fixed | Format-Table
    }
}

# For Test
Get-SecurityAgents 