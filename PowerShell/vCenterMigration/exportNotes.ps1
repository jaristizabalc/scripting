param(  
        [string]$vcenter
)
$vmList = Get-VM -Server $vcenter
$noteList = @()
foreach ($vm in $vmList) {
$row = “” | Select Name, Notes
$row.name = $vm.Name
$row.Notes = $vm | select Notes
$notelist += $row
}
$noteList | Export-Csv "exported_notes_$vcenter.csv” –NoTypeInformation