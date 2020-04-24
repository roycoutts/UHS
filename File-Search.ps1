$filter = "*mosaiq*.*"                    # <-- ENTER Search Criteria
$output = "c:\temp\mosaiq-search.txt"     # <-- ENTER Path to Output File

$driveF = "F:\"                             # <-- ENTER Drive Letters to Search (ex: "C:\")
$driveG = "G:\"
$driveH = "H:\"
$driveI = "I:\"
$driveN = "N:\"
$driveO = "O:\"
$driveZ = "Z:\"

$uncF = "\\wmhfilesrv\USERSHARES\E26414"    # <-- ENTER UNC Paths to Match Drive Letters (ex: "\\server\folder\folder")
$uncG = "\\BGHFILESRV\groupshares"
$uncH = "\\WMHFILESRV\groupshares"
$uncI = "\\Wmhfilesrv\idriveapps"
$uncN = "\\Wmhfilesrv\apps"
$uncO = "\\PHYSRVC01\grpdata"
$uncZ = "\\UHSH.uhs.org\NETLOGON"

File-Search $driveF $uncF $filter           # <-- File Search Drive Using Configuration From Above
File-Search $driveG $uncG $filter
File-Search $driveH $uncH $filter
File-Search $driveI $uncI $filter
File-Search $driveN $uncN $filter
File-Search $driveO $uncO $filter
File-Search $driveZ $uncZ $filter

# SEARCH Function - Write to File
Function File-Search ($drive,$unc,$filter){
    $items   = dir -Path $drive -Filter $filter -Recurse | %{$_.FullName}
    $itemCount = $items.Count
    $header = @()
    $header += "                                                                                "
    $header += "********************************************************************************"
    $header += "********************************************************************************"
    $header += "          DRIVE: " + $drive
    $header += "            UNC: " + $unc
    $header += "  SEARCH FILTER: " + $filter
    $header += "    ITEMS FOUND: " + $itemCount
    $header += "********************************************************************************"
    $header += "********************************************************************************"
    $header += "                                                                                "
    Add-Content -Path $output -Value $header
    Add-Content -Path $output -Value $items

}