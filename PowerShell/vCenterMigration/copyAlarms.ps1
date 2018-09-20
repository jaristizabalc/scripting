param(  
        [string]$sourceVcenter,
        [string]$targetVcenter,
        [string]$datacenter
)
<#
Copy all Datacenter alarms between two datacenters. The DCs can either be in the same vCenter
or in different vCenters. 
#>

$sourcevi = $sourceVcenter
$destvi = $targetVcenter
$vis = @($sourcevi, $destvi)

#Connect-VIServer $vis -WarningAction:SilentlyContinue

Set-Variable -Name alarmLength -Value 80 -Option "constant"
Get-Datacenter -Server $sourcevi | Select Name
$fromdc = $datacenter
Get-Datacenter -Server $destvi | Select Name
$todc = $datacenter
$from = Get-Datacenter -Name $fromdc -Server $sourcevi | Get-View
$to1 = Get-Datacenter -Name $todc -Server $destvi | Get-View
 
function Move-Alarm{
  param($Alarm, $From, $To, [switch]$DeleteOriginal = $false)
  $alarmObj = Get-View $Alarm -Server $sourcevi
  $alarmMgr = Get-View AlarmManager -Server $destvi
 
  if($deleteOriginal){
    #$alarmObj.RemoveAlarm()
  }
  $newAlarm = New-Object VMware.Vim.AlarmSpec
  $newAlarm = $alarmObj.Info
  $oldName = $alarmObj.Info.Name
  $oldDescription = $alarmObj.Info.Description
 
  foreach($destination in $To){
    $newAlarm.Expression.Expression | %{
      if($_.GetType().Name -eq "EventAlarmExpression"){
         $needsChange = $true
      }
    }
 
    $alarmMgr.CreateAlarm($destination.MoRef,$newAlarm)
    $newAlarm.Name = $oldName
    $newAlarm.Description = $oldDescription
  }
}
 
$alarmMgr = Get-View AlarmManager -Server $sourcevi
 
$alarms = $alarmMgr.GetAlarm($from.MoRef)
$alarms | % {
  Move-Alarm -Alarm $_ -From (Get-View $_) -To $to1 -DeleteOriginal:$false
}