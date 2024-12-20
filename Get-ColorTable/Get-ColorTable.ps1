function Get-ColorTable {
    # Initialize the array to hold color information
    $ColorTable = @()

    # Get all static properties of System.Windows.Media.Brushes
    $brushes = [System.Windows.Media.Brushes].GetProperties()

    foreach ($brush in $brushes) {
        # Get the color name
        $colorName = $brush.Name
        
        # Retrieve the color associated with the brush
        $brushInstance = $brush.GetValue($null)
        $color = $brushInstance.Color

        # Create the custom object with color properties
        $ColorObject = [PSCustomObject]@{
            Color = $colorName
            A     = $color.A
            R     = $color.R
            G     = $color.G
            B     = $color.B
            Hex   = "#{0:X2}{1:X2}{2:X2}{3:X2}" -f $color.A, $color.R, $color.G, $color.B
            Dec   = "{0},{1},{2},{3}" -f $color.A, $color.R, $color.G, $color.B
            HTML  = "#{0:X2}{1:X2}{2:X2}" -f $color.R, $color.G, $color.B
        }

        # Add the custom object to the array
        $ColorTable += $ColorObject
    }

    return $ColorTable
}

function Export-ColorTableToHTML {
    param (
        [Parameter(Mandatory)]
        [array]$ColorTable,

        [string]$OutputFilePath = "$([System.IO.Path]::GetTempPath())ColorTable.html"
    )

    # Start building the HTML content
    $htmlContent = @"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Color Table</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            margin: 20px;
        }
        body.light-mode {
            background-color: white;
            color: black;
        }
        body.dark-mode {
            background-color: black;
            color: white;
        }
        table {
            border-collapse: collapse;
            width: 100%;
            margin-top: 20px;
        }
        th, td {
            border: 1px solid #ddd;
            padding: 8px;
        }
        th {
            text-align: left;
        }
        .color-swatch {
            width: 40px;
            height: 20px;
            display: inline-block;
        }
        .mode-toggle {
            padding: 10px 20px;
            background-color: gray;
            color: white;
            border: none;
            cursor: pointer;
            font-size: 16px;
        }
        .mode-toggle:hover {
            background-color: darkgray;
        }
    </style>
    <script>
        function toggleMode() {
            const body = document.body;
            if (body.classList.contains('light-mode')) {
                body.classList.remove('light-mode');
                body.classList.add('dark-mode');
            } else {
                body.classList.remove('dark-mode');
                body.classList.add('light-mode');
            }
        }
    </script>
</head>
<body class="light-mode">
    <button class="mode-toggle" onclick="toggleMode()">Toggle Dark Mode</button>
    <h1>Color Table</h1>
    <table>
        <tr>
            <th>Color</th>
            <th>Swatch</th>
            <th>Alpha (A)</th>
            <th>Red (R)</th>
            <th>Green (G)</th>
            <th>Blue (B)</th>
            <th>Hex</th>
            <th>Decimal</th>
            <th>HTML</th>
        </tr>
"@

    # Add table rows for each color
    foreach ($color in $ColorTable) {
        $htmlContent += @"
        <tr>
            <td>$($color.Color)</td>
            <td><div class="color-swatch" style="background-color:$($color.HTML);"></div></td>
            <td>$($color.A)</td>
            <td>$($color.R)</td>
            <td>$($color.G)</td>
            <td>$($color.B)</td>
            <td>$($color.Hex)</td>
            <td>$($color.Dec)</td>
            <td>$($color.HTML)</td>
        </tr>
"@
    }

    # Close the HTML
    $htmlContent += @"
    </table>
</body>
</html>
"@

    # Write the HTML to the output file
    Set-Content -Path $OutputFilePath -Value $htmlContent -Encoding UTF8

    # Return the path of the saved file
    return $OutputFilePath
}

# Generate the color table
$ColorTable = Get-ColorTable

# Export it to an HTML file in the user's temp folder
$outputPath = Export-ColorTableToHTML -ColorTable $ColorTable

& $outputPath
