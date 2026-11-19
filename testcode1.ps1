#requires -Version 5.1
<#
.SYNOPSIS
    Non-interactive Phase 4 regression checks; does not start the WPF GUI.
.DESCRIPTION
    Verifies PowerShell parser, embedded XAML, expected Phase 4 entrypoints,
    report mapping, and spreadsheet formula-injection protection with mock data.
    Does not access AD, Clavier, UHS sites, or live session files.
#>
[CmdletBinding()]
param([string]$ScriptPath = (Join-Path $PSScriptRoot 'Clinical_Task_Workbench.ps1'))
$ErrorActionPreference = 'Stop'
$failures = New-Object 'System.Collections.Generic.List[string]'
$passed = 0
function Assert-Phase4 {
    param([bool]$Condition,[string]$Message)
    if ($Condition) { $script:passed++; Write-Host ('PASS: ' + $Message) -ForegroundColor Green }
    else { $script:failures.Add($Message); Write-Host ('FAIL: ' + $Message) -ForegroundColor Red }
}
if (-not (Test-Path -LiteralPath $ScriptPath -PathType Leaf)) { throw ('Script not found: {0}' -f $ScriptPath) }
$tokens = $null
$parseErrors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile($ScriptPath,[ref]$tokens,[ref]$parseErrors)
Assert-Phase4 ($parseErrors.Count -eq 0) ('PowerShell parse errors: {0}' -f $parseErrors.Count)
foreach ($entry in $parseErrors) { Write-Host $entry -ForegroundColor Red }
$source = Get-Content -LiteralPath $ScriptPath -Raw
$blocks = [regex]::Matches($source,"(?s)\[xml\]\$\w+\s*=\s*@'\s*\r?\n(.*?)\r?\n'@")
$allXamlValid = ($blocks.Count -ge 10)
foreach ($match in $blocks) {
    try { $doc = New-Object System.Xml.XmlDocument; $doc.LoadXml($match.Groups[1].Value) }
    catch { $allXamlValid = $false; Write-Host ('Invalid XAML: ' + $_.Exception.Message) -ForegroundColor Red }
}
Assert-Phase4 $allXamlValid ('Embedded XAML sections valid ({0} found)' -f $blocks.Count)
$functions = @{}
$nodes = $ast.FindAll({param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst]},$true)
foreach ($node in $nodes) { $functions[$node.Name] = $node }
foreach ($name in @('Write-WorkbenchAudit','Protect-CsvCell','Get-WorkbenchReportRows','Export-WorkbenchCompletionReport','Show-WorkbenchAuditHistory','Read-WorkbenchSettings','Save-WorkbenchSettings','Save-WorkbenchSession','Invoke-EmolstClavier')) {
    Assert-Phase4 ($functions.ContainsKey($name)) ('Function present: ' + $name)
}
foreach ($name in @('btnExportReport','btnAuditHistory','btnAppSettings')) {
    Assert-Phase4 ($source.Contains(('x:Name="{0}"' -f $name))) ('GUI control present: ' + $name)
}
# Compile ONLY the pure report helper functions into this isolated test scope.
# Do not dot-source the WPF workbench; doing so would start the GUI.
if ($functions.ContainsKey('Protect-CsvCell') -and $functions.ContainsKey('Get-WorkbenchReportRows')) {
    . ([scriptblock]::Create($functions['Protect-CsvCell'].Extent.Text))
    . ([scriptblock]::Create($functions['Get-WorkbenchReportRows'].Extent.Text))
    Assert-Phase4 ((Protect-CsvCell '=HYPERLINK("https://bad.example")') -eq "'=HYPERLINK(`"https://bad.example`")") 'CSV formula protection: equals sign'
    Assert-Phase4 ((Protect-CsvCell '+SUM(1,1)') -eq "'+SUM(1,1)") 'CSV formula protection: leading plus'
    Assert-Phase4 ((Protect-CsvCell 'Normal') -eq 'Normal') 'CSV normal text unchanged'
    $script:Tasks = @([pscustomobject]@{
        TaskID='12345';TaskType='Clinical';ClinicalLocationDisplay='WMC';ProviderLocationDisplay='';
        EmolstSSOUsername='00123456';EmolstReviewApplied=$true;EmolstSummaryCopied=$true;
        EmolstSummaryFile='C:\Temp\~EMOLST\sample.txt'
    })
    function Get-TaskUser { param($Task)
        [pscustomobject]@{ DisplayName='Example Person';SamAccountName='e12345';EmployeeID='12345';Status='Access Granted' }
    }
    function Get-TaskProgress { param($Task) 'Work Completed' }
    $rows = @(Get-WorkbenchReportRows)
    Assert-Phase4 ($rows.Count -eq 1) 'One report row generated for one mock task'
    if ($rows.Count -eq 1) {
        Assert-Phase4 ($rows[0].'Task ID' -eq '12345' -and $rows[0].'SamAccount' -eq 'e12345') 'Report task and identity mapping'
        Assert-Phase4 ($rows[0].'SSO Assigned' -eq $true -and $rows[0].'Summary Saved' -eq $true) 'Report SSO and summary flags'
        Assert-Phase4 ($rows[0].'Progress' -eq 'Work Completed') 'Report progress mapping'
    }
}
Write-Host ''
Write-Host ('Phase 4 tests: {0} passed, {1} failed.' -f $passed,$failures.Count)
if ($failures.Count -gt 0) { exit 1 }
exit 0
