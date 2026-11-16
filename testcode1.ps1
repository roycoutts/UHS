#requires -Version 5.1
<#
.SYNOPSIS
 Refresh UHS facility listings without losing manually assigned Location aliases.
.DESCRIPTION
 Reads existing local and (optionally) master JSON, scrapes the published UHS
 location listing, merges aliases by facility identity, and writes JSON safely.
 A failed or empty scrape never overwrites an existing file.
#>
[CmdletBinding()]
param(
    [string]$LocalPath = (Join-Path $env:LOCALAPPDATA 'Get-UHSLocations\Local-UHS-Locations.json'),
    [string]$MasterPath = '\\radcalcqa3\ITShare\SCRIPTS\Get-UHSLocations\Master-UHS-Locations.json',
    [switch]$SkipMaster
)
$ErrorActionPreference = 'Stop'

function Read-LocationJson([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return @() }
    $raw = [System.IO.File]::ReadAllText($Path)
    if ([string]::IsNullOrWhiteSpace($raw)) { return @() }
    $data = ConvertFrom-Json -InputObject $raw -ErrorAction Stop
    return @($data | Where-Object { $null -ne $_ -and -not [string]::IsNullOrWhiteSpace([string]$_.Name) })
}
function Key([string]$Text) {
    return (([string]$Text).Trim() -replace '\s+',' ').ToUpperInvariant()
}
function Merge-LocationData([object[]]$Fresh, [object[]]$Existing) {
    $byExact = @{}
    $byName = @{}
    foreach ($r in $Existing) {
        if (-not [string]::IsNullOrWhiteSpace([string]$r.Location)) {
            $name = Key $r.Name
            $exact = '{0}|{1}|{2}' -f $name,(Key $r.Address1),(Key $r.Locality)
            if (-not $byExact.ContainsKey($exact)) { $byExact[$exact] = [string]$r.Location }
            if (-not $byName.ContainsKey($name)) { $byName[$name] = @() }
            $byName[$name] += [string]$r.Location
        }
    }
    $output = [System.Collections.Generic.List[object]]::new()
    foreach ($r in $Fresh) {
        $name = Key $r.Name
        $exact = '{0}|{1}|{2}' -f $name,(Key $r.Address1),(Key $r.Locality)
        $alias = [string]$r.Location
        if ($byExact.ContainsKey($exact)) { $alias = $byExact[$exact] }
        elseif ($byName.ContainsKey($name) -and @($byName[$name]).Count -eq 1) { $alias = [string]$byName[$name][0] }
        $output.Add([pscustomobject][ordered]@{
            Name = [string]$r.Name; Location = $alias; Phone = [string]$r.Phone
            Address1 = [string]$r.Address1; Address2 = [string]$r.Address2
            Locality = [string]$r.Locality; State = [string]$r.State; Zip = [string]$r.Zip
        })
    }
    return $output.ToArray()
}
function Save-LocationJson([string]$Path,[object[]]$Records) {
    $folder = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $folder)) { $null = New-Item -ItemType Directory -Path $folder -Force }
    $temp = Join-Path $folder ('.locations-{0}.tmp' -f [guid]::NewGuid().ToString('N'))
    try {
        $json = ConvertTo-Json -InputObject @($Records) -Depth 8
        [System.IO.File]::WriteAllText($temp,$json,[System.Text.UTF8Encoding]::new($true))
        if (Test-Path -LiteralPath $Path) {
            Copy-Item -LiteralPath $Path -Destination ($Path + '.bak') -Force -ErrorAction Stop
        }
        Move-Item -LiteralPath $temp -Destination $Path -Force -ErrorAction Stop
    }
    finally { if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Force -ErrorAction SilentlyContinue } }
}

$localExisting = @(Read-LocationJson $LocalPath)
$masterExisting = @()
if (-not $SkipMaster -and (Test-Path -LiteralPath $MasterPath)) {
    try { $masterExisting = @(Read-LocationJson $MasterPath) }
    catch { Write-Warning ('Could not read master file: {0}' -f $_.Exception.Message) }
}
$results = [System.Collections.Generic.List[object]]::new()
$baseUrl = 'https://www.nyuhs.org/location-search?title=&field_services=All&field_location_type=All&city=&page='
$endConfirmed = $false
for ($page=0; $page -lt 100; $page++) {
    Write-Host ('Fetching locations page {0}...' -f $page) -ForegroundColor Cyan
    try { $response = Invoke-WebRequest -Uri ($baseUrl + $page) -UseBasicParsing -TimeoutSec 30 -ErrorAction Stop }
    catch { throw ('Scrape failed on page {0}; existing JSON remains unchanged. {1}' -f $page,$_.Exception.Message) }
    $html = [string]$response.Content
    if ($html -match 'No matching results') { $endConfirmed = $true; break }
    $blocks = [regex]::Matches($html,'(?s)<div[^>]*class="[^"]*media-block__body[^"]*"[^>]*>(.*?)<\/div>\s*<\/div>')
    if ($blocks.Count -eq 0) {
        if ($results.Count -gt 0) { $endConfirmed = $true; break }
        throw 'No location cards were found. The website layout may have changed; existing files were not touched.'
    }
    foreach ($match in $blocks) {
        $block = $match.Groups[1].Value
        $values = @{}
        foreach ($entry in @(
            @('Name','media-block__title'),@('Phone','phone-link'),@('Address1','address-line1'),
            @('Address2','address-line2'),@('Locality','locality'),@('State','administrative-area'),@('Zip','postal-code')
        )) {
            $m = [regex]::Match($block, '(?s)class="[^"]*' + [regex]::Escape($entry[1]) + '[^"]*"[^>]*>(.*?)<\/')
            $values[$entry[0]] = if ($m.Success) {
                [System.Net.WebUtility]::HtmlDecode(([regex]::Replace($m.Groups[1].Value,'<[^>]*>','')).Trim())
            } else { '' }
        }
        if (-not [string]::IsNullOrWhiteSpace($values.Name)) {
            # Location is exclusively a user-maintained alias: never scrape a city into it.
            $results.Add([pscustomobject]@{
                Name=$values.Name; Location=''; Phone=$values.Phone; Address1=$values.Address1
                Address2=$values.Address2; Locality=$values.Locality; State=$values.State; Zip=$values.Zip
            })
        }
    }
    Start-Sleep -Seconds 1
}
if (-not $endConfirmed -or $results.Count -eq 0) {
    throw 'The scrape did not reach a safe ending or returned no facilities; no JSON was overwritten.'
}
# Always prefer local aliases; add master-only aliases as fallback where local is empty.
$masterMerged = @(Merge-LocationData -Fresh $results.ToArray() -Existing $masterExisting)
$localMerged = @(Merge-LocationData -Fresh $masterMerged -Existing $localExisting)
Save-LocationJson -Path $LocalPath -Records $localMerged
Write-Host ('Updated LOCAL: {0} ({1} facilities)' -f $LocalPath,$localMerged.Count) -ForegroundColor Green
if (-not $SkipMaster) {
    try {
        # Master aliases are preserved independently; local aliases are also promoted if master is blank.
        $forMaster = @(Merge-LocationData -Fresh $localMerged -Existing $masterExisting)
        Save-LocationJson -Path $MasterPath -Records $forMaster
        Write-Host ('Updated MASTER: {0}' -f $MasterPath) -ForegroundColor Green
    }
    catch { Write-Warning ('Local file updated; master write failed: {0}' -f $_.Exception.Message) }
}
