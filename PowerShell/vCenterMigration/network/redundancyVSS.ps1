param(  
        [string]$vcenter,
        [string]$cluster
)
###############
# Restore redundancy on the VSS once VMs have been moved
# When blade has 1 adapter  vmnic2/3 belong to DVS1, and vmnic4/5 to DVS2
# When blade has 2 adapters vmnic1/4 belong to DVS1, and vmnic2/5 to DVS2
#
###############

$hosts = Get-VMHost -Location (Get-Cluster -Name $cluster -Server $vcenter)
foreach ($esxi in $hosts)
{
    $singleAdapter = $true
    #Identify if blade has more than one VIC
    switch($esxi.Name.Substring(0,4)){
        "edvp" {
                    if(([int]$esxi.Name.Substring(4,4) -ge 6019) -and ([int]$esxi.Name.Substring(4,4) -le 6900)) {$singleAdapter = $false} 
               }
        "ewvp" {
                    $var = [int]$esxi.Name.Substring(4,4)
                    if(($var -ge 6020) -and ($var -le 6900)) {$singleAdapter = $false}
                    else 
                    {
                        if(($var -eq 0100) -or ($var -eq 0101) -or ($var -eq 0102) -or ($var -eq 0103)) {$singleAdapter = $false}
                        else {$singleAdapter = $true}
                    }
                }
        "vpvp" {
                    $var = [int]$esxi.Name.Substring(4,4)
                    if(($var -ge 6020) -and ($var -le 6900)) {$singleAdapter = $false}
                    else 
                    {
                        if(($var -eq 0100) -or ($var -eq 0101) -or ($var -eq 0102) -or ($var -eq 0103) -or ($var -eq 1004) -or ($var -eq 1005) -or ($var -eq 1006)) {$singleAdapter = $false}
                        else {$singleAdapter = $true}
                    }
                }
        default { $singleAdapter = $true }
     }
    if($singleAdapter -eq $true){
        #Remove NIC from DVS
        Write-Host "Single VIC, breaking redundancy on" $esxi.Name
        $networkAdapter = $esxi | Get-VMHostNetworkAdapter -Physical -Name vmnic2 
        Remove-VDSwitchPhysicalNetworkAdapter -VMHostNetworkAdapter $networkAdapter -Confirm:$false
        #Add NIC to VSS
        $vss1 = Get-VirtualSwitch -VMHost $esxi -Name vSwitch1
        Add-VirtualSwitchPhysicalNetworkAdapter -VirtualSwitch $vss1 -VMHostPhysicalNic $networkAdapter -Confirm:$false
        #Repeat for second VSS
        $networkAdapter = $esxi | Get-VMHostNetworkAdapter -Physical -Name vmnic4 
        Remove-VDSwitchPhysicalNetworkAdapter -VMHostNetworkAdapter $networkAdapter -Confirm:$false
        #Add NIC to VSS
        $vss2 = Get-VirtualSwitch -VMHost $esxi -Name vSwitch2
        Add-VirtualSwitchPhysicalNetworkAdapter -VirtualSwitch $vss2 -VMHostPhysicalNic $networkAdapter -Confirm:$false
    }
    else{
        #Remove NIC from DVS
        Write-Host "Multiple VICs, breaking redundancy on" $esxi.Name
        $networkAdapter = $esxi | Get-VMHostNetworkAdapter -Physical -Name vmnic1 
        Remove-VDSwitchPhysicalNetworkAdapter -VMHostNetworkAdapter $networkAdapter -Confirm:$false
        #Add NIC to VSS
        $vss1 = Get-VirtualSwitch -VMHost $esxi -Name vSwitch1
        Add-VirtualSwitchPhysicalNetworkAdapter -VirtualSwitch $vss1 -VMHostPhysicalNic $networkAdapter -Confirm:$false
        #Repeat for second VSS
        $networkAdapter = $esxi | Get-VMHostNetworkAdapter -Physical -Name vmnic2 
        Remove-VDSwitchPhysicalNetworkAdapter -VMHostNetworkAdapter $networkAdapter -Confirm:$false
        #Add NIC to VSS
        $vss2 = Get-VirtualSwitch -VMHost $esxi -Name vSwitch2
        Add-VirtualSwitchPhysicalNetworkAdapter -VirtualSwitch $vss2 -VMHostPhysicalNic $networkAdapter -Confirm:$false
    }
}

#run  a connectivity test on all VMs
$results = @()
$vms = Get-VM -Location (Get-Cluster -Name $cluster -Server $vcenter)
foreach($vm in $vms)
{
  if($vm.PowerState -eq "PoweredOn")
  {
    Write-Host "Pinging" $vm
    if(!(Test-Connection -Cn $vm -Count 1 -ea 0 -quiet))
    {
            Write-Host "Trying second option for" $vm.Name
            if(!(Test-Connection -Cn $vm.Guest.IPAddress[0] -Count 1 -ea 0 -quiet))
            {
                $pass = "false"
                Write-Host "BOOOOOO!!!!!!"
            }
            else 
            {
                $pass = "true"
            }
    }
    else
    {
        $pass = "true"
    } 
    $details = @{ 
        Pass = $pass
        VM = $vm
               }
    $results += New-Object PSObject -Property $details 
    }
}

$results | Export-Csv -Path .\Connectivity_test3.csv –NoTypeInformation