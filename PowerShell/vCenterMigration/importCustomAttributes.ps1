param(  
        [string]$sourceVcenter,
        [string]$targetVcenter
)
Import-Csv -Path "exported_custom_att_$sourceVcenter.csv” | Where-Object {$_.Value} | ForEach-Object {
  Get-VM $_.VM -Server $targetVcenter | Set-Annotation -CustomAttribute $_.Name -Value $_.Value
}