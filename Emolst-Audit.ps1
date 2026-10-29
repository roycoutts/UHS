#Requires -Version 5.1
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Windows.Forms

# ---------- XAML ----------
[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="eMOLST &amp; Employee Directory Reconciliation Audit Tool"
        Height="820" Width="960" WindowStartupLocation="CenterScreen"
        ResizeMode="CanResizeWithGrip" MinHeight="700" MinWidth="780">
  <Window.Resources>
    <Style TargetType="Button">
      <Setter Property="Padding" Value="12,6"/>
      <Setter Property="Margin" Value="0,0,8,0"/>
      <Setter Property="FontFamily" Value="Segoe UI"/>
      <Setter Property="FontSize" Value="13"/>
      <Setter Property="Background" Value="#0078D4"/>
      <Setter Property="Foreground" Value="White"/>
      <Setter Property="BorderThickness" Value="0"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Style.Triggers>
        <Trigger Property="IsMouseOver" Value="True">
          <Setter Property="Background" Value="#106EBE"/>
        </Trigger>
        <Trigger Property="IsEnabled" Value="False">
          <Setter Property="Background" Value="#CCCCCC"/>
          <Setter Property="Foreground" Value="#666666"/>
        </Trigger>
      </Style.Triggers>
    </Style>
    <Style TargetType="TextBox">
      <Setter Property="Padding" Value="6,4"/>
      <Setter Property="FontFamily" Value="Segoe UI"/>
      <Setter Property="FontSize" Value="13"/>
      <Setter Property="VerticalContentAlignment" Value="Center"/>
    </Style>
    <Style TargetType="TextBlock">
      <Setter Property="FontFamily" Value="Segoe UI"/>
      <Setter Property="FontSize" Value="13"/>
    </Style>
  </Window.Resources>

  <Grid Margin="16">
    <Grid.RowDefinitions>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="*"/>
      <RowDefinition Height="Auto"/>
    </Grid.RowDefinitions>

    <!-- Title -->
    <TextBlock Grid.Row="0" Text="eMOLST &amp; Employee Directory Reconciliation Audit Tool" 
               FontSize="20" FontWeight="SemiBold" Margin="0,0,0,12"/>

    <!-- File pickers -->
    <Border Grid.Row="1" BorderBrush="#E0E0E0" BorderThickness="1" CornerRadius="4" Padding="12" Margin="0,0,0,12">
      <Grid>
        <Grid.RowDefinitions>
          <RowDefinition Height="Auto"/>
          <RowDefinition Height="Auto"/>
          <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>
        <Grid.ColumnDefinitions>
          <ColumnDefinition Width="200"/>
          <ColumnDefinition Width="*"/>
          <ColumnDefinition Width="Auto"/>
        </Grid.ColumnDefinitions>

        <TextBlock Grid.Row="0" Grid.Column="0" Text="eMOLST Users (CSV):" VerticalAlignment="Center"/>
        <TextBox   Grid.Row="0" Grid.Column="1" Name="txtEmolst" Margin="8,4"/>
        <Button    Grid.Row="0" Grid.Column="2" Name="btnBrowseEmolst" Content="Browse..." Width="100"/>

        <TextBlock Grid.Row="1" Grid.Column="0" Text="Employee List (Excel):" VerticalAlignment="Center" Margin="0,8,0,0"/>
        <TextBox   Grid.Row="1" Grid.Column="1" Name="txtEmployee" Margin="8,8,8,4"/>
        <Button    Grid.Row="1" Grid.Column="2" Name="btnBrowseEmployee" Content="Browse..." Width="100" Margin="0,8,0,0"/>

        <TextBlock Grid.Row="2" Grid.Column="0" Text="Export Folder:" VerticalAlignment="Center" Margin="0,8,0,0"/>
        <TextBox   Grid.Row="2" Grid.Column="1" Name="txtExport" Margin="8,8,8,4"/>
        <Button    Grid.Row="2" Grid.Column="2" Name="btnBrowseExport" Content="Select Folder" Width="100" Margin="0,8,0,0"/>
      </Grid>
    </Border>

    <!-- Options + Run -->
    <StackPanel Grid.Row="2" Orientation="Horizontal" Margin="0,0,0,12">
      <CheckBox Name="chkDoAD" Content="Perform Active Directory lookups for conflicts" IsChecked="True" VerticalAlignment="Center" Margin="0,0,20,0"/>
      <Button Name="btnRun" Content="Begin Reconciliation" Width="220" Height="36" FontWeight="SemiBold"/>
      <Button Name="btnReset" Content="Reset" Width="90" Height="36" Background="#6C757D"/>
    </StackPanel>

    <!-- Metrics -->
    <Border Grid.Row="3" BorderBrush="#E0E0E0" BorderThickness="1" CornerRadius="4" Padding="12" Margin="0,0,0,12">
      <Grid Name="gridMetrics">
        <Grid.ColumnDefinitions>
          <ColumnDefinition Width="*"/>
          <ColumnDefinition Width="140"/>
          <ColumnDefinition Width="*"/>
          <ColumnDefinition Width="140"/>
        </Grid.ColumnDefinitions>
        <Grid.RowDefinitions>
          <RowDefinition Height="Auto"/>
          <RowDefinition Height="Auto"/>
          <RowDefinition Height="Auto"/>
          <RowDefinition Height="Auto"/>
          <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>

        <TextBlock Grid.Row="0" Grid.Column="0" Text="eMOLST Records:" Margin="0,2"/>
        <TextBlock Grid.Row="0" Grid.Column="1" Name="lblEmolstTotal" Text="--" FontWeight="Bold" HorizontalAlignment="Right" Margin="0,2"/>
        <TextBlock Grid.Row="0" Grid.Column="2" Text="Employee Records:" Margin="16,2,0,2"/>
        <TextBlock Grid.Row="0" Grid.Column="3" Name="lblEmpTotal" Text="--" FontWeight="Bold" HorizontalAlignment="Right" Margin="0,2"/>

        <TextBlock Grid.Row="1" Grid.Column="0" Text="eMOLST Active Users:" Margin="0,2"/>
        <TextBlock Grid.Row="1" Grid.Column="1" Name="lblEmolstActive" Text="--" FontWeight="Bold" HorizontalAlignment="Right" Margin="0,2"/>
        <TextBlock Grid.Row="1" Grid.Column="2" Text="Matched Users:" Margin="16,2,0,2"/>
        <TextBlock Grid.Row="1" Grid.Column="3" Name="lblMatched" Text="--" FontWeight="Bold" HorizontalAlignment="Right" Margin="0,2"/>

        <TextBlock Grid.Row="2" Grid.Column="0" Text="Unmatched Users:" Margin="0,2"/>
        <TextBlock Grid.Row="2" Grid.Column="1" Name="lblUnmatched" Text="--" FontWeight="Bold" HorizontalAlignment="Right" Margin="0,2"/>
        <TextBlock Grid.Row="2" Grid.Column="2" Text="Status Conflicts:" Margin="16,2,0,2"/>
        <TextBlock Grid.Row="2" Grid.Column="3" Name="lblConflict" Text="--" FontWeight="Bold" HorizontalAlignment="Right" Margin="0,2" Foreground="#D83B01"/>

        <TextBlock Grid.Row="3" Grid.Column="0" Text="AD Enabled (Conflicts):" Margin="0,2"/>
        <TextBlock Grid.Row="3" Grid.Column="1" Name="lblAdEnabled" Text="--" FontWeight="Bold" HorizontalAlignment="Right" Margin="0,2"/>
        <TextBlock Grid.Row="3" Grid.Column="2" Text="AD Disabled (Conflicts):" Margin="16,2,0,2"/>
        <TextBlock Grid.Row="3" Grid.Column="3" Name="lblAdDisabled" Text="--" FontWeight="Bold" HorizontalAlignment="Right" Margin="0,2"/>

        <TextBlock Grid.Row="4" Grid.Column="0" Text="AD Not Found (Conflicts):" Margin="0,2"/>
        <TextBlock Grid.Row="4" Grid.Column="1" Name="lblAdNotFound" Text="--" FontWeight="Bold" HorizontalAlignment="Right" Margin="0,2"/>
        <TextBlock Grid.Row="4" Grid.Column="2" Text="AD Other/Error (Conflicts):" Margin="16,2,0,2"/>
        <TextBlock Grid.Row="4" Grid.Column="3" Name="lblAdOther" Text="--" FontWeight="Bold" HorizontalAlignment="Right" Margin="0,2"/>
      </Grid>
    </Border>

    <!-- Progress -->
    <StackPanel Grid.Row="4" Margin="0,0,0,8">
      <ProgressBar Name="progressBar" Height="18" Minimum="0" Maximum="100" Value="0"/>
      <TextBlock Name="txtStatus" Text="Ready." Margin="0,4,0,0" Foreground="#555"/>
    </StackPanel>

    <!-- Log -->
    <TextBox Grid.Row="5" Name="txtLog" IsReadOnly="True" TextWrapping="Wrap" VerticalScrollBarVisibility="Auto"
             FontFamily="Consolas" FontSize="12" Background="#F8F8F8" Padding="8" Margin="0,0,0,12"/>

    <!-- Bottom buttons -->
    <StackPanel Grid.Row="6" Orientation="Horizontal" HorizontalAlignment="Right">
      <Button Name="btnOpenFolder" Content="Open Export Folder" IsEnabled="False" Background="#28A745"/>
      <Button Name="btnViewConflicts" Content="View Conflicts" IsEnabled="False" Background="#17A2B8"/>
    </StackPanel>
  </Grid>
</Window>
"@

$reader = New-Object System.Xml.XmlNodeReader $xaml
$window = [Windows.Markup.XamlReader]::Load($reader)

# ---------- Named controls ----------
$txtEmolst       = $window.FindName("txtEmolst")
$txtEmployee     = $window.FindName("txtEmployee")
$txtExport       = $window.FindName("txtExport")
$btnBrowseEmolst = $window.FindName("btnBrowseEmolst")
$btnBrowseEmployee = $window.FindName("btnBrowseEmployee")
$btnBrowseExport = $window.FindName("btnBrowseExport")
$chkDoAD         = $window.FindName("chkDoAD")
$btnRun          = $window.FindName("btnRun")
$btnReset        = $window.FindName("btnReset")
$lblEmolstTotal  = $window.FindName("lblEmolstTotal")
$lblEmpTotal     = $window.FindName("lblEmpTotal")
$lblEmolstActive = $window.FindName("lblEmolstActive")
$lblMatched      = $window.FindName("lblMatched")
$lblUnmatched    = $window.FindName("lblUnmatched")
$lblConflict     = $window.FindName("lblConflict")
$lblAdEnabled    = $window.FindName("lblAdEnabled")
$lblAdDisabled   = $window.FindName("lblAdDisabled")
$lblAdNotFound   = $window.FindName("lblAdNotFound")
$lblAdOther      = $window.FindName("lblAdOther")
$progressBar     = $window.FindName("progressBar")
$txtStatus       = $window.FindName("txtStatus")
$txtLog          = $window.FindName("txtLog")
$btnOpenFolder   = $window.FindName("btnOpenFolder")
$btnViewConflicts= $window.FindName("btnViewConflicts")

# ---------- Helpers ----------
function Write-Log {
    param([string]$Message)
    $ts = Get-Date -Format "HH:mm:ss"
    $txtLog.AppendText("[$ts] $Message`r`n")
    $txtLog.ScrollToEnd()
    [System.Windows.Forms.Application]::DoEvents()
}

function Set-Status {
    param([string]$Message, [int]$Progress = -1)
    $txtStatus.Text = $Message
    if ($Progress -ge 0) { $progressBar.Value = $Progress }
    [System.Windows.Forms.Application]::DoEvents()
}

function Reset-UI {
    $lblEmolstTotal.Text = "--"
    $lblEmpTotal.Text = "--"
    $lblEmolstActive.Text = "--"
    $lblMatched.Text = "--"
    $lblUnmatched.Text = "--"
    $lblConflict.Text = "--"
    $lblAdEnabled.Text = "--"
    $lblAdDisabled.Text = "--"
    $lblAdNotFound.Text = "--"
    $lblAdOther.Text = "--"
    $progressBar.Value = 0
    $txtStatus.Text = "Ready."
    $txtLog.Clear()
    $btnOpenFolder.IsEnabled = $false
    $btnViewConflicts.IsEnabled = $false
    $script:lastExportFolder = $null
    $script:lastConflictPath = $null
}

# ---------- File dialogs ----------
$btnBrowseEmolst.Add_Click({
    $dlg = New-Object Microsoft.Win32.OpenFileDialog
    $dlg.Filter = "CSV Files (*.csv)|*.csv"
    $dlg.Title = "Select eMOLST Users CSV"
    if ($dlg.ShowDialog() -eq $true) { $txtEmolst.Text = $dlg.FileName }
})

$btnBrowseEmployee.Add_Click({
    $dlg = New-Object Microsoft.Win32.OpenFileDialog
    $dlg.Filter = "Excel Files (*.xlsx)|*.xlsx|All Files (*.*)|*.*"
    $dlg.Title = "Select Employee List Excel"
    if ($dlg.ShowDialog() -eq $true) { $txtEmployee.Text = $dlg.FileName }
})

$btnBrowseExport.Add_Click({
    $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
    $dlg.Description = "Select Export Folder"
    if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $txtExport.Text = $dlg.SelectedPath
    }
})

$btnReset.Add_Click({ Reset-UI })

$btnOpenFolder.Add_Click({
    if ($script:lastExportFolder -and (Test-Path $script:lastExportFolder)) {
        Start-Process explorer.exe -ArgumentList $script:lastExportFolder
    }
})

$btnViewConflicts.Add_Click({
    if (-not $script:lastConflictPath -or -not (Test-Path $script:lastConflictPath)) {
        [System.Windows.MessageBox]::Show("No conflict file available.", "View Conflicts")
        return
    }
    try {
        $data = Import-Csv $script:lastConflictPath
        if (-not $data) {
            [System.Windows.MessageBox]::Show("Conflict file is empty.", "View Conflicts")
            return
        }

        $gridXaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        Title="Status Conflicts" Height="500" Width="1100" WindowStartupLocation="CenterScreen">
  <Grid>
    <DataGrid Name="dg" AutoGenerateColumns="True" IsReadOnly="True" Margin="8"/>
  </Grid>
</Window>
"@
        $r = New-Object System.Xml.XmlNodeReader ([xml]$gridXaml)
        $w = [Windows.Markup.XamlReader]::Load($r)
        $dg = $w.FindName("dg")
        $dg.ItemsSource = $data
        $w.ShowDialog() | Out-Null
    } catch {
        [System.Windows.MessageBox]::Show("Failed to open conflicts: $($_.Exception.Message)", "Error")
    }
})

# ---------- Main processing ----------
$btnRun.Add_Click({
    if ([string]::IsNullOrWhiteSpace($txtEmolst.Text) -or 
        [string]::IsNullOrWhiteSpace($txtEmployee.Text) -or 
        [string]::IsNullOrWhiteSpace($txtExport.Text)) {
        [System.Windows.MessageBox]::Show("Please select all three paths.", "Missing Paths", "OK", "Warning")
        return
    }

    if (-not (Test-Path $txtEmolst.Text)) { [System.Windows.MessageBox]::Show("eMOLST file not found."); return }
    if (-not (Test-Path $txtEmployee.Text)) { [System.Windows.MessageBox]::Show("Employee file not found."); return }
    if (-not (Test-Path $txtExport.Text)) { [System.Windows.MessageBox]::Show("Export folder not found."); return }

    # Module checks
    if (-not (Get-Module -ListAvailable -Name ImportExcel)) {
        [System.Windows.MessageBox]::Show("The ImportExcel module is required.`nRun: Install-Module ImportExcel -Scope CurrentUser", "Missing Module")
        return
    }
    $doAD = $chkDoAD.IsChecked
    if ($doAD -and -not (Get-Module -ListAvailable -Name ActiveDirectory)) {
        [System.Windows.MessageBox]::Show("Active Directory module not available. Uncheck the AD option or install RSAT.", "Missing Module")
        return
    }

    $btnRun.IsEnabled = $false
    $btnReset.IsEnabled = $false
    Reset-UI
    Write-Log "Starting reconciliation..."
    Set-Status "Loading eMOLST data..." 5

    try {
        $matchedPath   = Join-Path $txtExport.Text "eMOLST_Matched_Employees.csv"
        $unmatchedPath = Join-Path $txtExport.Text "eMOLST_Unmatched_Employees.csv"
        $conflictPath  = Join-Path $txtExport.Text "eMOLST_Active_Employee_Terminated_Conflicts.csv"

        # Stage 1 – eMOLST
        $rawEmolst = Import-Csv -Path $txtEmolst.Text
        $lblEmolstTotal.Text = "{0:N0}" -f $rawEmolst.Count
        Write-Log "Loaded $($rawEmolst.Count) eMOLST records."
        Set-Status "Filtering active eMOLST users..." 15

        $emolstActiveData = $rawEmolst | Where-Object { $_.Disenrolled -eq 'FALSE' }
        $lblEmolstActive.Text = "{0:N0}" -f $emolstActiveData.Count
        Write-Log "Active eMOLST users (Disenrolled = FALSE): $($emolstActiveData.Count)"
        Set-Status "Loading Employee Excel..." 25

        # Stage 2 – Excel
        Import-Module ImportExcel -ErrorAction Stop
        $rawExcelData = Import-Excel -Path $txtEmployee.Text -NoHeader
        $empRecordCount = [Math]::Max(0, $rawExcelData.Count - 5)
        $lblEmpTotal.Text = "{0:N0}" -f $empRecordCount
        Write-Log "Loaded Excel data (approx. $empRecordCount employee rows after header offset)."
        Set-Status "Mapping Excel columns..." 35

        $headerRowIndex = 4
        if ($rawExcelData.Count -le $headerRowIndex) { throw "Excel file does not contain expected header row at index $headerRowIndex." }
        $headersArray = $rawExcelData[$headerRowIndex].PSObject.Properties.Value

        $colEmpNo  = [array]::IndexOf($headersArray, "EmpNumber") + 1
        $colLogin  = [array]::IndexOf($headersArray, "LoginName") + 1
        $colStatus = [array]::IndexOf($headersArray, "PersonnelStatus") + 1
        $colTerm   = [array]::IndexOf($headersArray, "TerminationDate") + 1
        $colMgr    = [array]::IndexOf($headersArray, "Manager Preferred Name") + 1
        $colHire   = [array]::IndexOf($headersArray, "SystemHireDate") + 1

        if ($colEmpNo -lt 1 -or $colLogin -lt 1 -or $colTerm -lt 1) {
            throw "Required columns (EmpNumber, LoginName, TerminationDate) not found in Excel header row."
        }
        Write-Log "Column mapping complete (LoginName column index $colLogin, etc.)."
        Set-Status "Building employee lookup..." 45

        # Stage 3 – Lookup
        $employeeLookup = @{}
        for ($i = $headerRowIndex + 1; $i -lt $rawExcelData.Count; $i++) {
            $empRow = $rawExcelData[$i]
            $rawLogin = $empRow."P$colLogin"
            if ($rawLogin) {
                $cleanLogin = ($rawLogin -replace '^.*\\').Trim()
                if ($cleanLogin -and -not $employeeLookup.ContainsKey($cleanLogin)) {
                    $employeeLookup[$cleanLogin] = $empRow
                }
            }
        }
        Write-Log "Employee lookup built with $($employeeLookup.Count) unique logins."
        Set-Status "Matching records..." 55

        # Stage 4 – Match
        $matchedRecords   = [System.Collections.Generic.List[PSCustomObject]]::new()
        $unmatchedRecords = [System.Collections.Generic.List[PSCustomObject]]::new()
        $conflictRecords  = [System.Collections.Generic.List[PSCustomObject]]::new()

        $cntConflict = 0
        $cntAdEnabled = 0; $cntAdDisabled = 0; $cntAdNotFound = 0; $cntAdOther = 0
        $total = $emolstActiveData.Count
        $idx = 0

        foreach ($user in $emolstActiveData) {
            $idx++
            if ($idx % 50 -eq 0 -or $idx -eq $total) {
                $pct = 55 + [int](($idx / [Math]::Max(1,$total)) * 30)
                Set-Status "Matching... $idx / $total" $pct
            }

            $username = $user.'Desired Username'
            if ($username) { $username = $username.Trim() }

            if ($username -and $employeeLookup.ContainsKey($username)) {
                $empMatch = $employeeLookup[$username]
                $empNumber       = $empMatch."P$colEmpNo"
                $terminationDate = $empMatch."P$colTerm"
                $adUserEnabled   = "N/A"

                $hasTermDate = -not [string]::IsNullOrWhiteSpace($terminationDate)
                if ($hasTermDate) {
                    $cntConflict++
                    if ($doAD -and $empNumber) {
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
                    } elseif ($doAD) {
                        $adUserEnabled = "Not Found"
                        $cntAdNotFound++
                    } else {
                        $adUserEnabled = "Skipped"
                    }
                }

                $recordObj = [PSCustomObject]@{
                    'eMOLST_Username'     = $user.'Desired Username'
                    'eMOLST_FirstName'    = $user.'First Name'
                    'eMOLST_MiddleName'   = $user.'Middle Name/Initial'
                    'eMOLST_LastName'     = $user.'Last Name'
                    'eMOLST_Title'        = $user.'Title'
                    'eMOLST_Email'        = $user.'Email'
                    'eMOLST_NPI'          = $user.'NPI #'
                    'eMOLST_License'      = $user.'State License #'
                    'eMOLST_Disenrolled'  = $user.Disenrolled
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

        # Update metrics
        $lblMatched.Text    = "{0:N0}" -f $matchedRecords.Count
        $lblUnmatched.Text  = "{0:N0}" -f $unmatchedRecords.Count
        $lblConflict.Text   = "{0:N0}" -f $cntConflict
        $lblAdEnabled.Text  = "{0:N0}" -f $cntAdEnabled
        $lblAdDisabled.Text = "{0:N0}" -f $cntAdDisabled
        $lblAdNotFound.Text = "{0:N0}" -f $cntAdNotFound
        $lblAdOther.Text    = "{0:N0}" -f $cntAdOther

        Write-Log "Matching complete. Matched: $($matchedRecords.Count), Unmatched: $($unmatchedRecords.Count), Conflicts: $cntConflict"
        if ($doAD) {
            Write-Log "AD results – Enabled: $cntAdEnabled, Disabled: $cntAdDisabled, Not Found: $cntAdNotFound, Other: $cntAdOther"
        } else {
            Write-Log "AD lookups were skipped."
        }
        Set-Status "Exporting CSV files..." 90

        # Export
        $matchedRecords   | Export-Csv -Path $matchedPath   -NoTypeInformation -Encoding UTF8
        $unmatchedRecords | Export-Csv -Path $unmatchedPath -NoTypeInformation -Encoding UTF8
        $conflictRecords  | Export-Csv -Path $conflictPath  -NoTypeInformation -Encoding UTF8

        Write-Log "Exports written:"
        Write-Log "  $matchedPath"
        Write-Log "  $unmatchedPath"
        Write-Log "  $conflictPath"

        $script:lastExportFolder = $txtExport.Text
        $script:lastConflictPath = $conflictPath
        $btnOpenFolder.IsEnabled = $true
        $btnViewConflicts.IsEnabled = ($conflictRecords.Count -gt 0)

        Set-Status "Complete." 100
        Write-Log "Reconciliation finished successfully."
        [System.Windows.MessageBox]::Show("Audit complete.`nExports written to:`n$($txtExport.Text)", "Success")
    }
    catch {
        Write-Log "ERROR: $($_.Exception.Message)"
        Set-Status "Failed." 0
        [System.Windows.MessageBox]::Show("Error during processing:`n$($_.Exception.Message)", "Error", "OK", "Error")
    }
    finally {
        $btnRun.IsEnabled = $true
        $btnReset.IsEnabled = $true
    }
})

# ---------- Show ----------
Reset-UI
$window.ShowDialog() | Out-Null
