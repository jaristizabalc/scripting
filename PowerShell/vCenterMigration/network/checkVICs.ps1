param(  
        [string]$vcenter,
        [string]$cluster
)
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
     if($singleAdapter -eq $true){Write-Host "Single VIC on " $esxi}
     else {Write-Host "Multiple VIC on " $esxi}
}