[System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")

function Get-FilePath {
    $OpenFileDialog =  New-Object System.Windows.Forms.OpenFileDialog
    $OpenFileDialog.InitialDirectory = "c:\\"
    $OpenFileDialog.Filter           = "CSV files (*.csv)|*.csv|All files (*.*)|*.*"
    $OpenFileDialog.FilterIndex      = 2
    $OpenFileDialog.RestoreDirectory = $true

    if ($OpenFileDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        # Get the path of the specified file
        $filepath = $OpenFileDialog.FileName
    }
    Return $filepath
}

$DateTimePattern = '"Sts",(?<Date>\d+\/\d+\/\d\d\d\d),"(?<Time>.?\d+:\d{2}...)",'
$Pattern = '"Sts",(?<Date>\d+\/\d+\/\d\d\d\d),"(?<Time>.?\d+:\d{2}...)","(?<Name>\w*,[^"]*)",'
$Pattern = '"Sts",(?<Date>\d+\/\d+\/\d\d\d\d),"(?<Time>.?\d+:\d{2}...)","(?<Name>\w*,[^"]*)","(?<MRN>\d*)",'
$Pattern = '"Sts",(?<Date>\d+\/\d+\/\d\d\d\d),"(?<Time>.?\d+:\d{2}...)","(?<Name>\w*,[^"]*)","(?<MRN>\d*)","(?<Desc>[^"]*)",'
$Pattern = '"Sts",(?<Date>\d+\/\d+\/\d\d\d\d),"(?<Time>.?\d+:\d{2}...)","(?<Name>\w*,[^"]*)","(?<MRN>\d*)","(?<Desc>[^"]*)","(?<PStf>[^"]*)","(?<Loc>[^"]*)","(?<MD>[^"]*)","(?<Sts>[^"]*)",'

function Get-List ($data) {
    $DateList = @()
    $NameList = @()
    $MrnList  = @()
    $DescList = @()
    $PStfList = @()
    $LocList  = @()
    $MDList   = @()
    $StsList  = @()

    (0..($data.Count-1)) | ForEach ({
        $count = [int]$PSItem
        #if ($data[$count] -match $DateTimePattern) {$DateList += Get-Date ($Matches.Date + " " + $Matches.Time)}
        if ($data[$count] -match $Pattern) {
            $DateList += Get-Date ($Matches.Date + " " + $Matches.Time)
            $NameList += $Matches.Name
            $MrnList  += $Matches.MRN
            $DescList += $Matches.Desc
            $PStfList += $Matches.PStf
            $LocList  += $Matches.Loc
            $MDList   += $Matches.MD
            $StsList  += $Matches.Sts
        }
    })
    Return $DateList, $NameList, $MrnList, $DescList, $PStfList, $LocList, $MDList, $StsList
}



$csv = Get-Content -Path (Get-FilePath)

$a = Get-List $csv


$Date, $PtName, $MRN, $Desc, $PStf = @()
(0..($csv.Count-1)) | ForEach ({
    $count = [int]$PSItem
    if ($csv[$count].Contains($findPatientStart)) {
        $indexPatientStart = $csv[$count].IndexOf($findPatientStart)
        $patientInfo = $csv[$count].Substring($indexPatientStart + $findPatientStart.Length)
        # GET DATE/TIME
        $Date += ($patientInfo.Split(',')[0].ToString() + " " + $patientInfo.Split(',')[1].Replace('"','').Trim().ToString())
        $PtName += $patientInfo.Split(',')[2,3].Replace('"','') -join ','
        $MRN += $patientInfo.Split(',')[4].Replace('"','')
        $Desc += $patientInfo.Split(',')[5].Replace('"','')
        $PStf += $patientInfo.Split(',')[6].Replace('"','')
    }
})

$list = @(); $i=0; $csv.ForEach({ if ( $_.Contains('Location(s): Simulator') ) {$list += $i,$_ ; $i++} }) 

(0..($list.Count-1)) | 


function Delete-Column {
    $col = $objExcel.ActiveWindow.Selection.EntireColumn
    if ($col.Value()[1,1].Contains('ICD-9 Diagnosis')) {
        $objExcel.ActiveWindow.Selection.EntireColumn.Delete()
        Return $true
    }
    elseif ($col.Value()[1,1].Contains('Schedule for Department:  RO')) {
        $objExcel.ActiveWindow.Selection.EntireColumn.Delete()
        Return $true    
    }
    elseif ($col.Value()[1,1].Contains('Schedule Date:')) {
        $objExcel.ActiveWindow.Selection.EntireColumn.Delete()
        Return $true        
    }
    else {
        Return $false
    }
}


$objExcel = New-Object -ComObject Excel.Application
$objExcel.Workbooks.Open($filepath)

$WasColumnDeleted = Delete-Column
if ($WasColumnDeleted ) {}

$objExcel.Save()


    $excel = New-Object -ComObject Excel.Application
$excel.visible = $true #you don't need this if you don't need to see it in action
$workbook = $excel.workbooks.add("c:\test.xls") | Out-Null
$workbook.worksheets.item("Sheet1").Copy([System.Reflection.Missing]::Value, $workbook.worksheets.item("Sheet3"))
$workbook
$workbook.worksheets.item("Sheet1 (2)").name = "SheetNew"
$workbook.save() | Out-Null
$workbook.close()
$excel.quit()

$Type1 = @()
$Type2 = @()
$Type3 = @()
(0..($csv.Count-1)) | ForEach ({ 
    if ($csv[$_].StartsWith("""UHS Radiation Oncology"""))            {$Type1 += [PSCustomObject]@{Line = $_; Name = "UHS Radiation Oncology"; Content = $csv[$_] } }
    if ($csv[$_].Length -eq 0)                                        {$Type2 += [PSCustomObject]@{Line = $_; Name = "Blank Line"            ; Content = $csv[$_] } }
    if ($csv[$_].Contains("\\Mosaiqserver01\mosaiq_app\sch_sts.rpt")) {$Type3 += [PSCustomObject]@{Line = $_; Name = "Report"                ; Content = $csv[$_] } }
 })
 $Type1.Count
 $Type2.Count
 $Type3.Count

2088
6264
2088
$BadPattern3 = @()
$P9Count = 0
$P8Count = 0
$P7Count = 0
$P6Count = 0
$P5Count = 0
$P4Count = 0
$P3Count = 0
$P2Count = 0
$P1Count = 0
$Type3.ForEach({
    $Pattern9 = '"Sts",(?<Date>\d+\/\d+\/\d\d\d\d),"(?<Time>.?\d+:\d{2}...)","(?<Name>\w*,[^"]*)","(?<MRN>\d*)","(?<Desc>[^"]*)","(?<PStf>[^"]*)","(?<Loc>[^"]*)","(?<MD>[^"]*)","(?<Sts>[^"]*)",'
    $Pattern8 = '"Sts",(?<Date>\d+\/\d+\/\d\d\d\d),"(?<Time>.?\d+:\d{2}...)","(?<Name>\w*,[^"]*)","(?<MRN>\d*)","(?<Desc>[^"]*)","(?<PStf>[^"]*)","(?<Loc>[^"]*)","(?<MD>[^"]*)",'
    $Pattern7 = '"Sts",(?<Date>\d+\/\d+\/\d\d\d\d),"(?<Time>.?\d+:\d{2}...)","(?<Name>\w*,[^"]*)","(?<MRN>\d*)","(?<Desc>[^"]*)","(?<PStf>[^"]*)","(?<Loc>[^"]*)",'
    $Pattern6 = '"Sts",(?<Date>\d+\/\d+\/\d\d\d\d),"(?<Time>.?\d+:\d{2}...)","(?<Name>\w*,[^"]*)","(?<MRN>\d*)","(?<Desc>[^"]*)","(?<PStf>[^"]*)",'
    $Pattern5 = '"Sts",(?<Date>\d+\/\d+\/\d\d\d\d),"(?<Time>.?\d+:\d{2}...)","(?<Name>\w*,[^"]*)","(?<MRN>\d*)","(?<Desc>[^"]*)",'
    $Pattern4 = '"Sts",(?<Date>\d+\/\d+\/\d\d\d\d),"(?<Time>.?\d+:\d{2}...)","(?<Name>\w*,[^"]*)","(?<MRN>\d*)",'
    $Pattern3 = '"Sts",(?<Date>\d+\/\d+\/\d\d\d\d),"(?<Time>.?\d+:\d{2}...)","(?<Name>\w*,[^"]*)",'
    $Pattern2 = '"Sts",(?<Date>\d+\/\d+\/\d\d\d\d),"(?<Time>.?\d+:\d{2}...)",'
    $Pattern1 = '"Sts",(?<Date>\d+\/\d+\/\d\d\d\d),'

    if ($_.Content -match $Pattern9) {$P9Count = $P9Count + 1}
    if ($_.Content -match $Pattern8) {$P8Count = $P8Count + 1}
    if ($_.Content -match $Pattern7) {$P7Count = $P7Count + 1}
    if ($_.Content -match $Pattern6) {$P6Count = $P6Count + 1}
    if ($_.Content -match $Pattern5) {$P5Count = $P5Count + 1}
    if ($_.Content -match $Pattern4) {$P4Count = $P4Count + 1}
    if ($_.Content -match $Pattern3) {$P3Count = $P3Count + 1}Else{$BadPattern3 += $_.Content}
    if ($_.Content -match $Pattern2) {$P2Count = $P2Count + 1}
    if ($_.Content -match $Pattern1) {$P1Count = $P1Count + 1}
})

Write-Host "Pattern9 Count = "$P9Count
Write-Host "Pattern8 Count = "$P8Count
Write-Host "Pattern7 Count = "$P7Count
Write-Host "Pattern6 Count = "$P6Count
Write-Host "Pattern5 Count = "$P5Count
Write-Host "Pattern4 Count = "$P4Count
Write-Host "Pattern3 Count = "$P3Count
Write-Host "Pattern2 Count = "$P2Count
Write-Host "Pattern1 Count = "$P1Count

function Get-QaStats {
    [CmdletBinding()]
    param(
    $InputObject, 
    [switch]$QA_Content,
    [switch]$QA_LineCount
    )
    if ($QA_Content)   {$Content = $InputObject}
    if ($QA_Counts)    {$Count = $InputObject.Count; $Length = $InputObject.Length}

    Write-Host "  LENGTH: "$($InputObject.Length)
    Write-Host "   COUNT: "$($InputObject.Count)
    

}
Get-QaStats ($ReportCsv)

$ReportCsv = Get-Content -Path $filepath
$a.ForEach({ if ($_.IndexOf('"Sts",') -gt -1) { $out = ($_.Substring($_.IndexOf('"Sts",')+6).split(',',11))[0..9] -join ','; $out >> C:\Temp\out.txt }  })

function Get-ValidLine ($line) { if (($line.Split(''))[17]) {$true}else{$false} }

function Get-ValidDate ($line) {
    $StartIndex  = $line.IndexOf('"Date"')
    $DatePattern = '(?<Date>\d+\/\d+\/\d\d\d\d)' 
    if ($StartIndex -gt -1) {
        if ($line.Substring($StartIndex) -match $DatePattern) {
            $Result = $Matches.Date
        }
        else{ 
            $Result = (Fail-Data -FailName "DATE" -FailMessage "Date Format Failure" -FailData $line) 
        }
    }
    Return $Result    
}

$Fail = @()
function Fail-Data {
    [CmdletBinding()]
    param(
    $FailName,
    $FailMessage, 
    $FailData
    )
    $Fail += [PSCustomObject]@{
        FailName = $FailName
        FailMessage = $FailMessage
        FailData = $FailData
    }
    Return "FAIL"
}

function Get-Fields ($line) {

}

$ReportWithValidLines2 = @( 
    $ReportCsv | ForEach ({ if (Get-ValidLine ($PSItem)) {$PSItem} })
)
# GET VALID LINES - REMOVE LINES WITHOUT DATA
$Lines2 = @( $ReportCsv | ForEach ({ if (Get-ValidLine ($PSItem)) {$PSItem} }) )
$Lines[0] | Add-Member -MemberType NoteProperty -Name Loop -Value (Get-Loop $Lines)

$DateList = @(
    $Loop = (0..($ReportWithValidLines.Count-1))
     | 
    ForEach ({ Get-ValidDate ($ReportWithValidLines[$PSItem]) })
)


$Date = ($ReportCsv[4].Split(','))[17]
$DatePattern = '(?<Date>\d+\/\d+\/\d\d\d\d)'
$Date = if (($ReportCsv[4].Split(','))[17] -match $DatePattern) {$Matches.Date}else{}

$ReportWithValidLines[0].Split(',')[17..26]

$ReportWithValidLines[0] | Add-Member -MemberType NoteProperty -Name LoopX -Value (0..($ReportWithValidLines.Count-1))

Function Get-Loop ($data) {
    $LOOP = @()
    (0..($data.Count - 1)) | ForEach ({ $LOOP += $_ })
    Return $LOOP
}
