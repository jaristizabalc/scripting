param(  
        [string]$vcenter,
        [string]$cluster,
        [string]$dvs1_name,
        [string]$dvs2_name
)

$dvs1 = Get-VDSwitch -Name $dvs1_name -Server $vcenter
$dvs2 = Get-VDSwitch -Name $dvs2_name -Server $vcenter
$allPG1 = Get-VDPortgroup -VDSwitch $dvs1
$allPG2 = Get-VDPortgroup -VDSwitch $dvs2
$hosts = Get-VMHost -Location (Get-Cluster -Name $cluster -Server $vcenter)
foreach ($esxi in $hosts)
{
  #create Standard Switches, assume host only has 1 VSS for management and vMotion (vSwitch0)
  $vss1= New-VirtualSwitch -Name vSwitch1  -Mtu 1500 -VMHost $esxi
  $vss2= New-VirtualSwitch -Name vSwitch2  -Mtu 9000 -VMHost $esxi
  #create portgroups on vSwitch1
  foreach ($thisPG in $allPG1)
  {
    new-virtualportgroup -virtualswitch $vss1 -name $thisPG.Name
    #Ensure that we don't try to tag an untagged VLAN
    if ($thisPG.vlanconfiguration.vlanid)
    {
        Get-virtualportgroup -virtualswitch $vss1 -name $thisPG.Name | Set-VirtualPortGroup -vlanid $thisPG.vlanconfiguration.vlanid
    }
    if($thisPG.Name -eq "vlan_10_prod_promiscuous"){
        Write-Host "Changing to Promiscuous Mode" $thisPG.Name
        Get-virtualportgroup -virtualswitch $vss1 -name $thisPG.Name | Set-SecurityPolicy -AllowPromiscuous $true
    }
  }
  #create portgroups on vSwitch2
  foreach ($thisPG in $allPG2)
  {
    new-virtualportgroup -virtualswitch $vss2 -name $thisPG.Name
    #Ensure that we don't try to tag an untagged VLAN
    if ($thisPG.vlanconfiguration.vlanid)
    {
        Get-virtualportgroup -virtualswitch $vss2 -name $thisPG.Name | Set-VirtualPortGroup -vlanid $thisPG.vlanconfiguration.vlanid
    }
  }
}