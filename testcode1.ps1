I use this file when I need to update my clinical locations table.
It returns:
- Name
- Location
- Phone
- Address1
- Address2
- Locality
- State
- Zip

It creates 2 output files:
\\radcalcqa3\ITShare\SCRIPTS\Get-UHSLocations\Master-UHS-Locations.json
C:\Users\E26414\AppData\Local\Get-UHSLocations\Local-UHS-Locations.json

The 'Location' field is blank. I want to use this field where I store my alias for the location.  For instance, 'UHS Wilson Medical Center' I will put 'WMC' in the location field.
I would like that when I update the location the new data, I would like to merge my 'Location' data into the new data.


<#
.SYNOPSIS
    Scrapes facility addresses using native PowerShell commands.
.DESCRIPTION
    Uses Invoke-WebRequest to fetch data and decodes HTML entities 
    back into regular plain-text characters.
#>


$MasterLocationsPath         = "\\radcalcqa3\ITShare\SCRIPTS\Get-UHSLocations\"
$LocalLocationsPath          = "$env:LOCALAPPDATA\Get-UHSLocations\"

$MasterLocationsJsonFileName = "Master-UHS-Locations.json"
$LocalLocationsJsonFileName  = "Local-UHS-Locations.json"



$BaseUrl = "https://www.nyuhs.org/location-search?title=&field_services=All&field_location_type=All&city=&page="
$CurrentPage = 0
$ResultsList = [System.Collections.Generic.List[PSCustomObject]]::new()

Write-Host "Starting lightweight data extraction with text decoding..." -ForegroundColor Cyan

while ($true) {
    $TargetUrl = "$BaseUrl$CurrentPage"
    Write-Host "Fetching Page $CurrentPage..." -ForegroundColor Yellow

    try {
        # Fetch the plain HTML page directly
        $Response = Invoke-WebRequest -Uri $TargetUrl -UseBasicParsing
        $HtmlText = $Response.Content

        # End criteria 1: Check for termination text string
        if ($HtmlText -match "No matching results") {
            Write-Host "Reached the end of records. Stop text found." -ForegroundColor Green
            break
        }

        # Find all facility media block containers using string regex
        $Blocks = [regex]::Matches($HtmlText, '(?s)<div[^>]*class="[^"]*media-block__body[^"]*"[^>]*>(.*?)<\/div>\s*<\/div>')

        # End criteria 2: Stop if zero blocks are found
        if ($Blocks.Count -eq 0) {
            Write-Host "No facility cards found on this page. Stopping." -ForegroundColor Orange
            break
        }

        foreach ($Match in $Blocks) {
            $BlockContent = $Match.Groups[1].Value

            # Helper function to extract inner text and decode HTML characters safely
            function Get-ElementText ($Class) {
                if ($BlockContent -match "(?s)class=`"[^`"]*$Class[^`"]*`"[^>]*>(.*?)<\/") {
                    # Strip residual inner HTML tags
                    $CleanText = [regex]::Replace($Matches[1], "<[^>]*>", "").Trim()
                    # Convert items like &amp; or &#39; into & or '
                    return [System.Net.WebUtility]::HtmlDecode($CleanText)
                }
                return $null
            }

            # Extract fields directly matching your layout schema
            $Name     = Get-ElementText "media-block__title"
            $Phone    = Get-ElementText "phone-link"
            $Address1 = Get-ElementText "address-line1"
            $Address2 = Get-ElementText "address-line2"
            $Locality = Get-ElementText "locality"
            $State    = Get-ElementText "administrative-area"
            $Zip      = Get-ElementText "postal-code"

            # Parse and decode the standalone Location city string
            $Location = $null
            if ($BlockContent -match "(?s)<\/h3>\s*<div>\s*([^<\r\n]+)") {
                $RawLocation = $Matches[1].Trim()
                $Location = [System.Net.WebUtility]::HtmlDecode($RawLocation)
            }

            # Compile properties into your target structure
            if (-not [string]::IsNullOrWhiteSpace($Name)) {
                $ResultsList.Add([PSCustomObject]@{
                    Name     = $Name
                    Location = $Location
                    Phone    = $Phone
                    Address1 = $Address1
                    Address2 = $Address2
                    Locality = $Locality
                    State    = $State
                    Zip      = $Zip
                })
            }
        }

        # Increment to page the next collection
        $CurrentPage++
        
        # Polite 1-second pause to prevent hammering the server
        Start-Sleep -Seconds 1
    }
    catch {
        Write-Error "An unexpected problem occurred while fetching data: $_"
        break
    }
}

# Create File Path for JSON file (Master and Local Paths)
$MasterLocationsJsonFilePath = Join-Path -Path $MasterLocationsPath -ChildPath $MasterLocationsJsonFileName
$LocalLocationsJsonFilePath  = Join-Path -Path $LocalLocationsPath -ChildPath $LocalLocationsJsonFileName

New-Item -Path $LocalLocationsJsonFilePath -ItemType File -Force

# Export JSON
$ResultsListJson = ConvertTo-Json -InputObject $ResultsList
$ResultsListJson | Out-File -FilePath $MasterLocationsJsonFilePath -Encoding utf8 -Force
$ResultsListJson | Out-File -FilePath $LocalLocationsJsonFilePath -Encoding utf8 -Force

Write-Host "Success! Saved $($ResultsList.Count) cleaned records to: $OutputPath" -ForegroundColor Green
Write-Host "  MASTER FILE: " -ForegroundColor Cyan -NoNewline
Write-Host "$MasterLocationsJsonFilePath" -ForegroundColor Green
Write-Host "   LOCAL FILE: " -ForegroundColor Cyan -NoNewline
Write-Host "$LocalLocationsJsonFilePath" -ForegroundColor Green

