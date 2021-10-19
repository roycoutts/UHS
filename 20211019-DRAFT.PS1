$Path = 'C:\Users\royco\Downloads\test\text\test.csv'
$Source = Get-Content -Path $Path
$BlankIndex = @()
$NoDataIndex = @()
$DataIndex = @()
$MissingIndex = @()
$SourceCount = ''
$BlankIndexCount = ''
$NoDataIndexCount = ''
$DataIndexCount = ''
$MissingIndexCount = ''
$Date = @()
$Time = @()
$LName = @()
$FName = @()
$Name = @()
$MRN  = @()
$Desc = @()
$PStf = @()
$Loc  = @()
$MD   = @()
$Sts  = @()




For ($i = 0; $i -lt $Source.Count;$i++) {
    if     ($Source[$i].length -eq 0)                           {$BlankIndex += $i}
    elseif ($source[$i].StartsWith('"UHS Radiation Oncology"')) {$NoDataIndex += $i}
    elseif ($source[$i].StartsWith('* on Diagnosis'))           {$DataIndex += $i}
    else {$MissingIndex += $i}
}
$SourceCount       = $Source.Count
$BlankIndexCount   = $BlankIndex.Count
$NoDataIndexCount  = $NoDataIndex.Count
$DataIndexCount    = $DataIndex.Count 
$MissingIndexCount = $MissingIndex.Count 

$AllIndexesCount = [int]$BlankIndexCount + [int]$NoDataIndexCount + [int]$DataIndexCount + [int]$MissingIndexCount
if ($SourceCount -eq $AllIndexesCount) {$PassOrFail = 'PASS'}
else{$PassOrFail = 'FAIL'}

Write-Host "  Source Count: $SourceCount  "
Write-Host "- - - - - - - - - - - - - - - - - - - - -"
Write-Host "   Blank Index: $BlankIndexCount  "
Write-Host " No Data Index: $NoDataIndexCount "
Write-Host "    Data Index: $DataIndexCount   "
Write-Host " Missing Index: $MissingIndexCount"
Write-Host "- - - - - - - - - - - - - - - - - - - - -"
Write-Host "   All Indexes: $AllIndexesCount"
Write-Host "              : $PassOrFail"


For ($i = 0; $i -lt $DataIndexCount; $i++) {
    $Date  += $Source[$DataIndex[$i]].Split(',')[17]
    $Time  += $source[$dataindex[$i]].Split(',')[18]
    $LName += $Source[$DataIndex[$i]].Split(',')[19]
    $FName += $source[$dataindex[$i]].Split(',')[20]
    $Name  += $Source[$DataIndex[$i]].Split(',')[19],$Source[$DataIndex[$i]].Split(',')[20] -join ','
    $MRN   += $source[$dataindex[$i]].Split(',')[21]
    $Desc  += $source[$dataindex[$i]].Split(',')[22]
    $PStf  += $source[$dataindex[$i]].Split(',')[23]
    $Loc   += $source[$dataindex[$i]].Split(',')[24]
    $MD    += $source[$dataindex[$i]].Split(',')[25]
    $Sts   += $source[$dataindex[$i]].Split(',')[26]
}

Write-Host " Date: $($Date.Count)"
Write-Host " Time: $($Time.Count)"
Write-Host "LName: $($LName.Count)"
Write-Host "FName: $($FName.count)"
Write-Host " Name: $($Name.Count)"
Write-Host "  MRN: $($MRN.Count)"
Write-Host " Desc: $($Desc.Count)"
Write-Host " PStf: $($PStf.Count)"
Write-Host "  Loc: $($Loc.Count)"
Write-Host "   MD: $($MD.Count)"
Write-Host " PStf: $($PStf.Count)"



