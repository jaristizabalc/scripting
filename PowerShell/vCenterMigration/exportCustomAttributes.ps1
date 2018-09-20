param(  
        [string]$vcenter
)
Get-VM -Server $vcenter | ForEach-Object {
  $VM = $_
  $VM | Get-Annotation |`
    ForEach-Object {
      $Report = "" | Select-Object VM,Name,Value
      $Report.VM = $VM.Name
      $Report.Name = $_.Name
      $Report.Value = $_.Value
      $Report
    }
} | Export-Csv -Path "exported_custom_att_$vcenter.csv” –NoTypeInformation