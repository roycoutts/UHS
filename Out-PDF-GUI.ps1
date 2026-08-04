Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

function Out-PDF {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string]$Text,

        [Parameter(Mandatory = $true)]
        [string]$OutputPath,

        [Parameter(Mandatory = $false)]
        [string]$Header,

        [Parameter(Mandatory = $false)]
        [switch]$PageNumbers,

        [Parameter(Mandatory = $false)]
        [switch]$LineNumbers
    )

    process {
        # Ensure the output directory exists
        $absolutePath = [System.IO.Path]::GetFullPath($OutputPath)
        $directory = Split-Path $absolutePath
        if (-not (Test-Path $directory)) {
            New-Item -ItemType Directory -Path $directory -Force | Out-Null
        }

        # Initialize the print document
        Add-Type -AssemblyName System.Drawing
        $doc = New-Object System.Drawing.Printing.PrintDocument
        $doc.PrinterSettings.PrinterName = "Microsoft Print to PDF"
        $doc.PrinterSettings.PrintToFile = $true
        $doc.PrinterSettings.PrintFileName = $absolutePath
        
        # Force Landscape orientation
        $doc.DefaultPageSettings.Landscape = $true

        # Use a synchronized/reference object to preserve tracking state across page refreshes
        $state = [pscustomobject]@{
            CharIndex         = 0
            PageCount         = 1
            CurrentLineNum    = 1
            IsFirstCharOfLine = $true
            CleanText         = $Text -replace "`r", ""
        }

        # Define the print layout logic
        $doc.Add_PrintPage({
            param($sender, $ev)
            
            # Setup layout constraints and force Cascadia Code font at size 10
            $font = New-Object System.Drawing.Font("Cascadia Code", 10)
            $brush = [System.Drawing.Brushes]::Black
            
            # Margins adapt to the Landscape setting
            $leftMargin   = $ev.MarginBounds.Left
            $rightMargin  = $ev.MarginBounds.Right
            $topMargin    = $ev.MarginBounds.Top
            $bottomMargin = $ev.MarginBounds.Bottom
            
            $lineHeight   = $font.GetHeight($ev.Graphics)
            
            # Pre-calculate margins based on line numbers
            $charSize = $ev.Graphics.MeasureString("X", $font)
            $charWidth = $charSize.Width * 0.65
            $lineNumberPrefixWidth = $charWidth * 7
            
            # Determine horizontal start position
            $textStartMargin = if ($LineNumbers) { $leftMargin + $lineNumberPrefixWidth } else { $leftMargin }
            
            # Handle Header Logic
            if (-not [string]::IsNullOrEmpty($Header)) {
                # Draw the header text slightly above the standard top margin
                $headerYPos = $topMargin - ($lineHeight * 1.5)
                $ev.Graphics.DrawString($Header, $font, [System.Drawing.Brushes]::DarkGray, $leftMargin, $headerYPos)
                
                # Draw a subtle separator line under the header text
                $lineYPos = $topMargin - ($lineHeight * 0.5)
                $pen = New-Object System.Drawing.Pen([System.Drawing.Color]::LightGray, 1)
                $ev.Graphics.DrawLine($pen, $leftMargin, $lineYPos, $rightMargin, $lineYPos)
                $pen.Dispose()
            }
            
            $xPos = $textStartMargin
            $yPos = $topMargin

            # Process characters sequentially using the tracked persistent state object
            while ($state.CharIndex -lt $state.CleanText.Length) {
                $char = $state.CleanText[$state.CharIndex]

                # Print line number prefix if starting a brand new text file line
                if ($LineNumbers -and $state.IsFirstCharOfLine) {
                    $prefixStr = "{0:D4} | " -f $state.CurrentLineNum
                    $ev.Graphics.DrawString($prefixStr, $font, [System.Drawing.Brushes]::Gray, $leftMargin, $yPos)
                    $state.IsFirstCharOfLine = $false
                }

                # Check if we hit a native newline character
                if ($char -eq "`n") {
                    $xPos = $textStartMargin
                    $yPos += $lineHeight
                    $state.CharIndex++
                    $state.CurrentLineNum++
                    $state.IsFirstCharOfLine = $true
                    
                    # Check for page overflow after a newline
                    if (($yPos + $lineHeight) -gt $bottomMargin) {
                        if ($PageNumbers) {
                            $pageText = "Page $($state.PageCount)"
                            $textSize = $ev.Graphics.MeasureString($pageText, $font)
                            $ev.Graphics.DrawString($pageText, $font, $brush, ($rightMargin - $textSize.Width), ($bottomMargin + $lineHeight))
                        }
                        $state.PageCount++
                        $ev.HasMorePages = $true
                        return
                    }
                    continue
                }

                # Force a line wrap if the character exceeds the right margin
                if (($xPos + $charWidth) -gt $rightMargin) {
                    $xPos = $textStartMargin
                    $yPos += $lineHeight

                    # Check for page overflow during wrapping
                    if (($yPos + $lineHeight) -gt $bottomMargin) {
                        if ($PageNumbers) {
                            $pageText = "Page $($state.PageCount)"
                            $textSize = $ev.Graphics.MeasureString($pageText, $font)
                            $ev.Graphics.DrawString($pageText, $font, $brush, ($rightMargin - $textSize.Width), ($bottomMargin + $lineHeight))
                        }
                        $state.PageCount++
                        $ev.HasMorePages = $true
                        return
                    }
                }

                # Draw the text character and advance the cursor position
                $ev.Graphics.DrawString($char, $font, $brush, $xPos, $yPos)
                $xPos += $charWidth
                $state.CharIndex++
            }

            # Print page number on the final page if requested
            if ($PageNumbers) {
                $pageText = "Page $($state.PageCount)"
                $textSize = $ev.Graphics.MeasureString($pageText, $font)
                $ev.Graphics.DrawString($pageText, $font, $brush, ($rightMargin - $textSize.Width), ($bottomMargin + $lineHeight))
            }

            # Loop cleanly finished everything; cease creating new pages
            $ev.HasMorePages = $false
        })

        # Execute printing to file
        Write-Verbose "Generating landscape PDF..."
        $doc.Print()
        
        # Clean up object
        $doc.Dispose()
    }
}

# 1. Main Form Window Setup
$form = New-Object System.Windows.Forms.Form
$form.Text = "PowerShell Text-to-PDF Converter"
$form.Size = New-Object System.Drawing.Size(550, 360)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false

# Font styling
$textFont = New-Object System.Drawing.Font("Segoe UI", 10)
$labelFont = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)

# 2. Input File Selection Layout
$lblInput = New-Object System.Windows.Forms.Label
$lblInput.Text = "Select Input Text File:"
$lblInput.Location = New-Object System.Drawing.Point(20, 20)
$lblInput.Size = New-Object System.Drawing.Size(200, 23)
$lblInput.Font = $labelFont
$form.Controls.Add($lblInput)

$txtInput = New-Object System.Windows.Forms.TextBox
$txtInput.Location = New-Object System.Drawing.Point(20, 45)
$txtInput.Size = New-Object System.Drawing.Size(400, 23)
$txtInput.Font = $textFont
$form.Controls.Add($txtInput)

$btnBrowseInput = New-Object System.Windows.Forms.Button
$btnBrowseInput.Text = "Browse..."
$btnBrowseInput.Location = New-Object System.Drawing.Point(430, 44)
$btnBrowseInput.Size = New-Object System.Drawing.Size(80, 25)
$btnBrowseInput.Font = $textFont
$btnBrowseInput.Add_Click({
    $openDialog = New-Object System.Windows.Forms.OpenFileDialog
    $openDialog.Filter = "Text Files (*.txt;*.log)|*.txt;*.log|All Files (*.*)|*.*"
    if ($openDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $txtInput.Text = $openDialog.FileName
    }
})
$form.Controls.Add($btnBrowseInput)

# 3. Output Path Selection Layout
$lblOutput = New-Object System.Windows.Forms.Label
$lblOutput.Text = "Select Output PDF Path:"
$lblOutput.Location = New-Object System.Drawing.Point(20, 85)
$lblOutput.Size = New-Object System.Drawing.Size(200, 23)
$lblOutput.Font = $labelFont
$form.Controls.Add($lblOutput)

$txtOutput = New-Object System.Windows.Forms.TextBox
$txtOutput.Location = New-Object System.Drawing.Point(20, 110)
$txtOutput.Size = New-Object System.Drawing.Size(400, 23)
$txtOutput.Font = $textFont
$form.Controls.Add($txtOutput)

$btnBrowseOutput = New-Object System.Windows.Forms.Button
$btnBrowseOutput.Text = "Browse..."
$btnBrowseOutput.Location = New-Object System.Drawing.Point(430, 109)
$btnBrowseOutput.Size = New-Object System.Drawing.Size(80, 25)
$btnBrowseOutput.Font = $textFont
$btnBrowseOutput.Add_Click({
    $saveDialog = New-Object System.Windows.Forms.SaveFileDialog
    $saveDialog.Filter = "PDF Files (*.pdf)|*.pdf"
    if ($saveDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $txtOutput.Text = $saveDialog.FileName
    }
})
$form.Controls.Add($btnBrowseOutput)

# 4. Header Input Layout
$lblHeader = New-Object System.Windows.Forms.Label
$lblHeader.Text = "Page Header Text (Optional):"
$lblHeader.Location = New-Object System.Drawing.Point(20, 150)
$lblHeader.Size = New-Object System.Drawing.Size(200, 23)
$lblHeader.Font = $labelFont
$form.Controls.Add($lblHeader)

$txtHeader = New-Object System.Windows.Forms.TextBox
$txtHeader.Location = New-Object System.Drawing.Point(20, 175)
$txtHeader.Size = New-Object System.Drawing.Size(490, 23)
$txtHeader.Font = $textFont
$form.Controls.Add($txtHeader)

# 5. Checkboxes Layout
$chkPageNumbers = New-Object System.Windows.Forms.CheckBox
$chkPageNumbers.Text = "Enable Page Numbers"
$chkPageNumbers.Location = New-Object System.Drawing.Point(25, 215)
$chkPageNumbers.Size = New-Object System.Drawing.Size(200, 23)
$chkPageNumbers.Font = $textFont
$form.Controls.Add($chkPageNumbers)

$chkLineNumbers = New-Object System.Windows.Forms.CheckBox
$chkLineNumbers.Text = "Enable Line Numbers"
$chkLineNumbers.Location = New-Object System.Drawing.Point(25, 245)
$chkLineNumbers.Size = New-Object System.Drawing.Size(200, 23)
$chkLineNumbers.Font = $textFont
$form.Controls.Add($chkLineNumbers)

# 6. Action Button Layout
$btnConvert = New-Object System.Windows.Forms.Button
$btnConvert.Text = "Generate PDF"
$btnConvert.Location = New-Object System.Drawing.Point(360, 275)
$btnConvert.Size = New-Object System.Drawing.Size(150, 35)
$btnConvert.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$btnConvert.BackColor = [System.Drawing.Color]::LightBlue

# Button Click Event connecting Form Data directly to Out-PDF
$btnConvert.Add_Click({
    # Error checking
    if ([string]::IsNullOrWhiteSpace($txtInput.Text) -or -not (Test-Path $txtInput.Text)) {
        [System.Windows.Forms.MessageBox]::Show("Please select a valid input text file.", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        return
    }
    if ([string]::IsNullOrWhiteSpace($txtOutput.Text)) {
        [System.Windows.Forms.MessageBox]::Show("Please choose an output destination for your PDF.", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        return
    }

    try {
        $btnConvert.Enabled = $false
        $btnConvert.Text = "Processing..."
        $form.Refresh()

        # Read content from the chosen text file path
        $fileText = Get-Content -Path $txtInput.Text -Raw

        # Prepare parameters dynamically based on UI values
        $params = @{
            Text       = $fileText
            OutputPath = $txtOutput.Text
        }
        if (-not [string]::IsNullOrEmpty($txtHeader.Text)) { $params["Header"] = $txtHeader.Text }
        if ($chkPageNumbers.Checked) { $params["PageNumbers"] = $true }
        if ($chkLineNumbers.Checked) { $params["LineNumbers"] = $true }

        # Call your Out-PDF function
        Out-PDF @params

        [System.Windows.Forms.MessageBox]::Show("PDF compiled and generated successfully!", "Success", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
    }
    catch {
        [System.Windows.Forms.MessageBox]::Show("An error occurred during generation:`n$($_.Exception.Message)", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    }
    finally {
        $btnConvert.Enabled = $true
        $btnConvert.Text = "Generate PDF"
    }
})
$form.Controls.Add($btnConvert)

# 7. Execute Application Window
$form.ShowDialog() | Out-Null
