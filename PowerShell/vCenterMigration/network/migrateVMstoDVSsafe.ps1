param(  
        [string]$vcenter,
        [string]$cluster,
        [string]$dvs1_name,
        [string]$dvs2_name
)

$dvs1 = Get-VDSwitch -Name $dvs1_name -Server $vcenter
$dvs2 = Get-VDSwitch -Name $dvs2_name -Server $vcenter
$excludeList = ""
#Migrate Guest Network
$vms = Get-VM -Location (Get-Cluster -Name $cluster -Server $vcenter)
$results = @()
foreach($vm in $vms){
    if(!$excludeList.Contains($vm)){  
        $netadapters = Get-NetworkAdapter $vm 
        foreach ($adapter in $netadapters) {
            Write-Host "Setting adapter" $adapter.NetworkName on $vm $adapter      
            #get unique portgroup
            $pg = Get-VDPortgroup -Name $adapter.NetworkName -VDSwitch $dvs1
            if(!$pg) {
                $pg = Get-VDPortgroup -Name $adapter.NetworkName -VDSwitch $dvs2
            }
            if($pg) {
                Set-NetworkAdapter -NetworkAdapter $adapter -PortGroup $pg -Confirm:$false
            }
            else {Write-Host "Can't find unique portgroup, skip network change"}
        }
        #Test connectivity
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
}

$results | Export-Csv -Path .\Connectivity_test2_$cluster.csv