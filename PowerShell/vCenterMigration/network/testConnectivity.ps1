param(  
        [string]$vcenter,
        [string]$cluster
)
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

$results | Export-Csv -Path .\Connectivity_testX.csv –NoTypeInformation