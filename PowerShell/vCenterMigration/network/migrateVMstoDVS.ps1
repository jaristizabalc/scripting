param(  
        [string]$vcenter,
        [string]$cluster
)

#Migrate Guest Network
$vms = Get-VM -Location (Get-Cluster -Name $cluster -Server $vcenter)
foreach($vm in $vms){
    $netadapters = Get-NetworkAdapter $vm 
    foreach ($adapter in $netadapters) {
        Write-Host "Setting adapter" $adapter.NetworkName on $vm $adapter
        Set-NetworkAdapter -NetworkAdapter $adapter -PortGroup (Get-VDPortgroup -Name $adapter.NetworkName) -Confirm:$false
    }
}


#run  a connectivity test on all VMs
$results = @()
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

$results | Export-Csv -Path .\Connectivity_test2_$cluster.csv