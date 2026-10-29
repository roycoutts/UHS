Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Safely initialize each variable separately to prevent array linking in PowerShell 5.1
$txtEmolst = $null
$txtEmployee = $null
$txtExport = $null
$lblEmolstTotal = $null
$lblEmpTotal = $null
$lblEmolstActive = $null
$lblMatched = $null
$lblUnmatched = $null
$lblConflict = $null
$lblAdEnabled = $null
$lblAdDisabled = $null
$lblAdNotFound = $null
$lblAdOther = $null

# Create main window form
$form = New-Object System.Windows.Forms.Form
$form.Text = "eMOLST & Employee Directory Reconciliation Audit Tool"
$form.Size = New-Object System.Drawing.Size(650, 680)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false

# Helper Font styles
$fontHeader = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$fontNormal = New-Object System.Drawing.Font("Segoe UI", 9)
$fontLabel  = New-Object System.Drawing.Font("Consolas", 10, [System.Drawing.FontStyle]::Bold)

# --- 1. FILE PICKER & UI SECTION CONTROLS ---

function Add-FilePicker {
    param(
        [int]$Top, 
        [string]$LabelText, 
        [string]$ButtonText, 
        [ref]$TxtVariable, 
        [bool]$IsFolder=$false
    )
    
    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Text = $LabelText
    $lbl.Location = New-Object System.Drawing.Point(20, $Top)
    $lbl.Size = New-Object System.Drawing.Size(150, 23)
    $lbl.Font = $fontNormal
    $form.Controls.Add($lbl)

    $txt = New-Object System.Windows.Forms.TextBox
    $txt.Location = New-Object System.Drawing.Point(180, $Top)
    $txt.Size = New-Object System.Drawing.Size(320, 23)
    $txt.Font = $fontNormal
    $form.Controls.Add($txt)
    $TxtVariable.Value = $txt

    $btnTop = $Top - 2
    $btn = New-Object System.Windows.Forms.Button
    $btn.Text = $ButtonText
    $btn.Location = New-Object System.Drawing.Point(510, $btnTop)
    $btn.Size = New-Object System.Drawing.Size(95, 25)
    $btn.Font = $fontNormal
    
    # Anchor the textbox and configurations directly to the button object
    $btn.Tag = $txt
    
    if ($IsFolder) {
        $btn.Add_Click({
            $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
            $dialog.Description = "Select Target Export Folder"
            if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) { 
                $this.Tag.Text = $dialog.SelectedPath 
            }
        })
    } else {
        # Establish the explicit file filter on creation while scope is alive
        $fileFilter = if ($LabelText -match "eMOLST") { "CSV Files (*.csv)|*.csv" } else { "Excel Files (*.xlsx)|*.xlsx" }
        
        $btn.Add_Click({
            $dialog = New-Object System.Windows.Forms.OpenFileDialog
            $dialog.Filter = $fileFilter
            if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) { 
                $this.Tag.Text = $dialog.FileName 
            }
        })
    }
    
    $form.Controls.Add($btn)
}

# Generate input elements with distinct integer coordinates
Add-FilePicker -Top 30  -LabelText "Select eMOLST Users File:" -ButtonText "Browse CSV..." -TxtVariable ([ref]$txtEmolst)
Add-FilePicker -Top 70  -LabelText "Select EMPLOYEE LIST File:" -ButtonText "Browse Excel..." -TxtVariable ([ref]$txtEmployee)
Add-FilePicker -Top 110 -LabelText "Select Export Folder:"      -ButtonText "Select Folder..." -TxtVariable ([ref]$txtExport) -IsFolder $true

# Execution Action Button
$btnRun = New-Object System.Windows.Forms.Button
$btnRun.Text = "Begin Reconciliation Process"
$btnRun.Location = New-Object System.Drawing.Point(20, 155)
$btnRun.Size = New-Object System.Drawing.Size(585, 35)
$btnRun.Font = $fontHeader
$btnRun.BackColor = [System.Drawing.Color]::LightBlue
$form.Controls.Add($btnRun)

# --- 2. LIVE DASHBOARD METRICS DISPLAY PANEL ---

$grpDashboard = New-Object System.Windows.Forms.GroupBox
$grpDashboard.Text = "Live Data Reconciliation Audit Metrics"
$grpDashboard.Location = New-Object System.Drawing.Point(20, 205)
$grpDashboard.Size = New-Object System.Drawing.Size(585, 410)
$grpDashboard.Font = $fontHeader
$form.Controls.Add($grpDashboard)

function Add-MetricLabel {
    param(
        [int]$Top, 
        [string]$Description, 
        [ref]$LblVariable
    )
    
    $lblDesc = New-Object System.Windows.Forms.Label
    $lblDesc.Text = $Description
    $lblDesc.Location = New-Object System.Drawing.Point(20, $Top)
    $lblDesc.Size = New-Object System.Drawing.Size(420, 23)
    $lblDesc.Font = $fontNormal
    $grpDashboard.Controls.Add($lblDesc)

    $lblVal = New-Object System.Windows.Forms.Label
    $lblVal.Text = "--"
    $lblVal.Location = New-Object System.Drawing.Point(450, $Top)
    $lblVal.Size = New-Object System.Drawing.Size(115, 23)
    $lblVal.Font = $fontLabel
    $lblVal.TextAlign = [System.Drawing.ContentAlignment]::MiddleRight
    $grpDashboard.Controls.Add($lblVal)
    $LblVariable.Value = $lblVal
}

# Generate structured text placeholders matching requirements
Add-MetricLabel -Top 35  -Description "Load eMOLST Data... `n         eMOLST Records:" -LblVariable ([ref]$lblEmolstTotal)
Add-MetricLabel -Top 75  -Description "Load EMPLOYEE Data... `n       EMPLOYEE Records:" -LblVariable ([ref]$lblEmpTotal)
Add-MetricLabel -Top 115 -Description "Select eMOLST Active Users (Disenrolled = 'FALSE') `n    eMOLST Active Users:" -LblVariable ([ref]$lblEmolstActive)
Add-MetricLabel -Top 155 -Description "Match eMOLST Active Users to EMPLOYEE Data `n         MATCHED Users:" -LblVariable ([ref]$lblMatched)
Add-MetricLabel -Top 195 -Description "       UNMATCHED Users:" -LblVariable ([ref]$lblUnmatched)
Add-MetricLabel -Top 235 -Description "Compare MATCHED Users' Status `n    User Status Conflict (eMOLST Active/EMPLOYEE Terminated):" -LblVariable ([ref]$lblConflict)
Add-MetricLabel -Top 275 -Description "Validate User Status Conflict in Active Directory `n     AD Enabled/Status Conflict:" -LblVariable ([ref]$lblAdEnabled)
Add-MetricLabel -Top 315 -Description "    AD Disabled/Status Conflict:" -LblVariable ([ref]$lblAdDisabled)
Add-MetricLabel -Top 355 -Description "   AD Not Found/Status Conflict:" -LblVariable ([ref]$lblAdNotFound)
Add-MetricLabel -Top 385 -Description "       AD Other/Status Conflict:" -LblVariable ([ref]$lblAdOther)

# --- 3. RECONCILIATION LOGIC PIPELINE ---

$btnRun.Add_Click({
    # Validate paths have been provided before starting
    if ([string]::IsNullOrWhiteSpace($txtEmolst.Text) -or [string]::IsNullOrWhiteSpace($txtEmployee.Text) -or [string]::IsNullOrWhiteSpace($txtExport.Text)) {
        [System.Windows.Forms.MessageBox]::Show("Please supply all source file locations and output export directory.", "Missing Configuration Paths", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
        return
    }

    $btnRun.Enabled = $false
    $btnRun.Text = "Processing Datasets... Please Wait"
    [System.Windows.Forms.Application]::DoEvents()

    # Define dynamic target files
    $matchedPath   = Join-Path $txtExport.Text "eMOLST_Matched_Employees.csv"
    $unmatchedPath = Join-Path $txtExport.Text "eMOLST_Unmatched_Employees.csv"
    $conflictPath  = Join-Path $txtExport.Text "eMOLST_Active_Employee_Terminated_Conflicts.csv"

    # Stage 1: eMOLST Data Loading & Raw Record Profiling
    $rawEmolst = Import-Csv -Path $txtEmolst.Text
    $lblEmolstTotal.Text = "{0:N0}" -f $rawEmolst.Count
    [System.Windows.Forms.Application]::DoEvents()

    # Stage 2: eMOLST Disenrolled Filtering
    $emolstActiveData = $rawEmolst | Where-Object { $_.Disenrolled -eq 'FALSE' }
    $lblEmolstActive.Text = "{0:N0}" -f $emolstActiveData.Count
    [System.Windows.Forms.Application]::DoEvents()

    # Stage 3: Load Employee File (NoHeader processing using Row index 4 offset)
    $rawExcelData = Import-Excel -Path $txtEmployee.Text -NoHeader
    $lblEmpTotal.Text = "{0:N0}" -f ($rawExcelData.Count - 5)
    [System.Windows.Forms.Application]::DoEvents()

    # Stage 4: Index Header Array Mappings
    $headerRowIndex = 4
    $headersArray = $rawExcelData[$headerRowIndex].PSObject.Properties.Value

    $colEmpNo  = [array]::IndexOf($headersArray, "EmpNumber") + 1
    $colLogin  = [array]::IndexOf($headersArray, "LoginName") + 1
    $colStatus = [array]::IndexOf($headersArray, "PersonnelStatus") + 1
    $colTerm   = [array]::IndexOf($headersArray, "TerminationDate") + 1
    $colMgr    = [array]::IndexOf($headersArray, "Manager Preferred Name") + 1
    $colHire   = [array]::IndexOf($headersArray, "SystemHireDate") + 1

    # Stage 5: Construct Search Dictionary Array Mapping
    $employeeLookup = @{}
    for ($i = $headerRowIndex + 1; $i -lt $rawExcelData.Count; $i++) {
        $empRow = $rawExcelData[$i]
        $rawLogin = $empRow."P$colLogin"
        if ($rawLogin) {
            $cleanLogin = ($rawLogin -replace '^.*\\').Trim()
            if (-not $employeeLookup.ContainsKey($cleanLogin)) {
                $employeeLookup[$cleanLogin] = $empRow
            }
        }
    }

    # Stage 6: Structural Reconciliation and Variable Extraction
    $matchedRecords   = [System.Collections.Generic.List[PSCustomObject]]::new()
    $unmatchedRecords = [System.Collections.Generic.List[PSCustomObject]]::new()
    $conflictRecords  = [System.Collections.Generic.List[PSCustomObject]]::new()

    $cntConflict = 0
    $cntAdEnabled = 0; $cntAdDisabled = 0; $cntAdNotFound = 0; $cntAdOther = 0

    foreach ($user in $emolstActiveData) {
        $username = $user.'Desired Username'
        if ($username) { $username = $username.Trim() }

        if ($employeeLookup.ContainsKey($username)) {
            $empMatch = $employeeLookup[$username]
            $empNumber       = $empMatch."P$colEmpNo"
            $terminationDate = $empMatch."P$colTerm"
            $disenrolled     = $user.Disenrolled
            $adUserEnabled   = "N/A"

            # Check for Status Conflict Criteria
            $hasTermDate = -not [string]::IsNullOrWhiteSpace($terminationDate)
            
            if ($hasTermDate) {
                $cntConflict++
                
                # Reach out to Active Directory to resolve status mismatch
                if ($empNumber) {
                    try {
                        $adUser = Get-ADUser -Filter "EmployeeID -like '$empNumber'" -ErrorAction Stop
                        if ($adUser) {
                            if ($adUser.Enabled) {
                                $adUserEnabled = "Enabled"
                                $cntAdEnabled++
                            } else {
                                $adUserEnabled = "Disabled"
                                $cntAdDisabled++
                            }
                        } else {
                            $adUserEnabled = "Not Found"
                            $cntAdNotFound++
                        }
                    } catch {
                        $adUserEnabled = "Other/Error"
                        $cntAdOther++
                    }
                } else {
                    $adUserEnabled = "Not Found"
                    $cntAdNotFound++
                }
            }

            # Compile standard structure values
            $recordObj = [PSCustomObject]@{
                'eMOLST_Username'     = $user.'Desired Username'
                'eMOLST_FirstName'    = $user.'First Name'
                'eMOLST_MiddleName'   = $user.'Middle Name/Initial'
                'eMOLST_LastName'     = $user.'Last Name'
                'eMOLST_Title'        = $user.'Title'
                'eMOLST_Email'        = $user.'Email'
                'eMOLST_NPI'          = $user.'NPI #'
                'eMOLST_License'      = $user.'State License #'
                'eMOLST_Disenrolled'  = $disenrolled
                'EmpNumber'           = $empNumber
                'Employee_LoginName'  = $empMatch."P$colLogin"
                'PersonnelStatus'     = $empMatch."P$colStatus"
                'TerminationDate'     = $terminationDate
                'ManagerName'         = $empMatch."P$colMgr"
                'SystemHireDate'      = $empMatch."P$colHire"
                'AD_Status_Conflict'  = $adUserEnabled
            }

            $matchedRecords.Add($recordObj)
            if ($hasTermDate) { $conflictRecords.Add($recordObj) }

        } else {
            $unmatchedRecords.Add($user)
        }
    }

    # Finalize screen metric counts
    $lblMatched.Text    = "{0:N0}" -f $matchedRecords.Count
    $lblUnmatched.Text  = "{0:N0}" -f $unmatchedRecords.Count
    $lblConflict.Text   = "{0:N0}" -f $cntConflict
    $lblAdEnabled.Text  = "{0:N0}" -f $cntAdEnabled
    $lblAdDisabled.Text = "{0:N0}" -f $cntAdDisabled
    $lblAdNotFound.Text = "{0:N0}" -f $cntAdNotFound
    $lblAdOther.Text    = "{0:N0}" -f $cntAdOther
    [System.Windows.Forms.Application]::DoEvents()

    # Stage 8: Direct Disk Export Pipelines
    $matchedRecords   | Export-Csv -Path $matchedPath -NoTypeInformation -Encoding UTF8
    $unmatchedRecords | Export-Csv -Path $unmatchedPath -NoTypeInformation -Encoding UTF8
    $conflictRecords  | Export-Csv -Path $conflictPath -NoTypeInformation -Encoding UTF8

    # Reset GUI Control Elements
    $btnRun.Enabled = $true
    $btnRun.Text = "Begin Reconciliation Process"
    
    [System.Windows.Forms.MessageBox]::Show("Audit complete and exports successfully compiled inside target folder!", "Process Finalized", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
})

# Display window form frame
$form.ShowDialog()
