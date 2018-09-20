param(  
        [string]$vcenter,
        [string]$cluster,
        [string]$dvs1_name,
        [string]$dvs2_name
)
###############
# Restore redundancy on the VSS once VMs have been moved
# When blade has 1 adapter  vmnic2/3 belong to DVS1, and vmnic4/5 to DVS2
# When blade has 2 adapters vmnic1/4 belong to DVS1, and vmnic2/5 to DVS2
#
###############
$dvs1 = Get-VDSwitch -Name $dvs1_name -Server $vcenter
$dvs2 = Get-VDSwitch -Name $dvs2_name -Server $vcenter
$hosts = Get-VMHost -Location (Get-Cluster -Name $cluster -Server $vcenter)
foreach ($esxi in $hosts)
{
    $singleAdapter = $true
    #Identify if blade has more than one VIC
    switch($esxi.Name.Substring(0,4)){
        "edvp" {
                    if([int]$esxi.Name.Substring(4,4) -ge 6019) {$singleAdapter = $false} 
               }
        "ewvp" {
                    $var = [int]$esxi.Name.Substring(4,4)
                    if($var -ge 6020) {$singleAdapter = $false}
                    else 
                    {
                        if(($var -eq 0100) -or ($var -eq 0101) -or ($var -eq 0102) -or ($var -eq 0103)) {$singleAdapter = $false}
                        else {$singleAdapter = $true}
                    }
                }
        "vpvp" {
                    $var = [int]$esxi.Name.Substring(4,4)
                    if($var -ge 6020) {$singleAdapter = $false}
                    else 
                    {
                        if(($var -eq 0100) -or ($var -eq 0101) -or ($var -eq 0102) -or ($var -eq 0103) -or ($var -eq 1004) -or ($var -eq 1005) -or ($var -eq 1006)) {$singleAdapter = $false}
                        else {$singleAdapter = $true}
                    }
                }
        default { $singleAdapter = $true }
     }
    if($singleAdapter -eq $true){
        #Remove NIC from VSS
        Write-Host "Single VIC, breaking redundancy on" $esxi.Name
        $networkAdapter = $esxi | Get-VMHostNetworkAdapter -Physical -Name vmnic2 
        Remove-VirtualSwitchPhysicalNetworkAdapter -VMHostNetworkAdapter $networkAdapter -Confirm:$false
        #Add NIC to DVS
        Add-VDSwitchPhysicalNetworkAdapter -DistributedSwitch $dvs1 -VMHostPhysicalNic $networkAdapter -Confirm:$false
        #Repeat for second DVS
        $networkAdapter = $esxi | Get-VMHostNetworkAdapter -Physical -Name vmnic4 
        Remove-VirtualSwitchPhysicalNetworkAdapter -VMHostNetworkAdapter $networkAdapter -Confirm:$false
        #Add NIC to DVS
        Add-VDSwitchPhysicalNetworkAdapter -DistributedSwitch $dvs2 -VMHostPhysicalNic $networkAdapter -Confirm:$false
    }
    else{
        #Remove NIC from VSS
        Write-Host "Multiple VICs, breaking redundancy on" $esxi.Name
        $networkAdapter = $esxi | Get-VMHostNetworkAdapter -Physical -Name vmnic1 
        Remove-VirtualSwitchPhysicalNetworkAdapter -VMHostNetworkAdapter $networkAdapter -Confirm:$false
        #Add NIC to DVS
        Add-VDSwitchPhysicalNetworkAdapter -DistributedSwitch $dvs1 -VMHostPhysicalNic $networkAdapter -Confirm:$false
        #Repeat for second DVS
        $networkAdapter = $esxi | Get-VMHostNetworkAdapter -Physical -Name vmnic2 
        Remove-VirtualSwitchPhysicalNetworkAdapter -VMHostNetworkAdapter $networkAdapter -Confirm:$false
        #Add NIC to DVS
        Add-VDSwitchPhysicalNetworkAdapter -DistributedSwitch $dvs2 -VMHostPhysicalNic $networkAdapter -Confirm:$false
    }
}

#run  a connectivity test on all VMs
$results = @()
$vms = Get-VM -Location (Get-Cluster -Name $cluster -Server $vcenter)
foreach($vm in $vms)
{
    if($vm.PowerState -eq "PoweredOn")
    {
        if(!(Test-Connection -Cn $vm -Count 1 -ea 0 -quiet))
        {
            Write-Host "Trying second option for" $vm.Name
            if(!(Test-Connection -Cn $vm.Guest.IPAddress[0] -Count 1 -ea 0 -quiet))
            {
                Write-Host $vm "BOOOO!!!"
                $pass = "false"
            }
            else 
            {
                Write-Host $vm "NICE!!!"
                $pass = "true"

            }
        }
        else
        {
            Write-Host $vm "NICE!!!"
            $pass = "true"
        }
        $details = @{ 
            Pass = $pass
            VM = $vm
                    }
        $results += New-Object PSObject -Property $details  
    }  
}
$results | Export-Csv -Path .\Connectivity_test3_$cluster.csv