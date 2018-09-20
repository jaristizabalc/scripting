param(  
        [string]$sourceVcenter,
        [string]$targetVcenter
)
$noteList = Import-Csv "exported_notes_$sourceVcenter.csv”
foreach($nLine in $noteList){
    if ( $nLine.Notes -ne “”){
        #Write-Host $vm.Name
        $vm = Get-VM -Name $nLine.Name -Server $targetVcenter
        Set-VM -VM $vm -Notes $nLine.Notes -Confirm:$false
    }
}