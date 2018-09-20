param(  
        [string]$vcenter,
        [string]$esxi,
        [string]$vss_name,
        [string]$dvs_name
)
###############
$vmhost = Get-VMHost $esxi -Server $vcenter
$vss = Get-VirtualSwitch -Name $vss_name -VMHost $vmhost
$vssNumPorts = $vss.NumPorts
$standardpg =  Get-VirtualPortGroup -VirtualSwitch $vss 
$dvs = Get-VDSwitch $dvs_name -Server $vcenter

foreach ($i in $standardpg) {
    $pvgname = $i.name.ToString()
    $pvg = $pvgname
    $vlan = $i.VLANID
    #create a Static DvS PG with the same VLAN
    $dvs | New-VDPortGroup -Name $pvg -VLanId $vlan -PortBinding "Static" 
}