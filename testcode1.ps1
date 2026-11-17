#requires -Version 5.1
<#
.SYNOPSIS
    Clinical Task Workbench - PowerShell 5.1 / WPF
.DESCRIPTION
    Topmost GUI for staging Task IDs, associating AD users, and later
    integrating Clinical Locations, Professional Locations, SSO, Ivanti,
    Doctor Master, EPIC, and EMOLST.

    Includes local clinical-location aliases, task assignments, safe refresh,
    and session-cached DoctorMaster .xls/.xlsx/.csv provider lookup via Excel COM, ACE, or CSV.
    Integrations without supplied specifications are deliberately placeholders.

.NOTES
    Run with Windows PowerShell 5.1 in STA mode:
    powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File .\Clinical_Task_Workbench.ps1
    Add Users requires the ActiveDirectory module and domain connectivity.
#>

if ([System.Threading.Thread]::CurrentThread.GetApartmentState() -ne 'STA') {
    $exe = Join-Path $PSHOME 'powershell.exe'
    if (-not (Test-Path -LiteralPath $exe)) { throw 'Windows PowerShell 5.1 is required.' }
    Start-Process -FilePath $exe -ArgumentList @(
        '-NoProfile', '-STA', '-ExecutionPolicy', 'Bypass', '-File',
        ('"{0}"' -f $PSCommandPath)
    )
    return
}

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase
Add-Type -AssemblyName System.Xaml

[xml]$mainXaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Clinical Task Workbench" Width="1240" Height="835"
        MinWidth="920" MinHeight="620" WindowStartupLocation="CenterScreen"
        Background="#101827" Foreground="#E6EDF7" Topmost="True">
    <Window.Resources>
        <Style TargetType="Button">
            <Setter Property="Background" Value="#253752"/>
            <Setter Property="Foreground" Value="#F1F5FB"/>
            <Setter Property="Padding" Value="13,8"/>
            <Setter Property="Margin" Value="0,0,8,8"/>
            <Setter Property="BorderBrush" Value="#456080"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="MinHeight" Value="35"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Style.Triggers>
                <Trigger Property="IsMouseOver" Value="True">
                    <Setter Property="Background" Value="#35557D"/>
                </Trigger>
            </Style.Triggers>
        </Style>
        <Style TargetType="DataGrid">
            <Setter Property="Background" Value="#172339"/>
            <Setter Property="Foreground" Value="#E6EDF7"/>
            <Setter Property="RowBackground" Value="#172339"/>
            <Setter Property="AlternatingRowBackground" Value="#20314A"/>
            <Setter Property="BorderBrush" Value="#3B526D"/>
            <Setter Property="GridLinesVisibility" Value="Horizontal"/>
            <Setter Property="HorizontalGridLinesBrush" Value="#33455F"/>
            <Setter Property="HeadersVisibility" Value="Column"/>
            <Setter Property="CanUserAddRows" Value="False"/>
            <Setter Property="CanUserDeleteRows" Value="False"/>
            <Setter Property="SelectionMode" Value="Single"/>
            <Setter Property="SelectionUnit" Value="FullRow"/>
            <Setter Property="IsReadOnly" Value="True"/>
            <Setter Property="AutoGenerateColumns" Value="False"/>
        </Style>
        <Style TargetType="DataGridColumnHeader">
            <Setter Property="Background" Value="#304764"/>
            <Setter Property="Foreground" Value="White"/>
            <Setter Property="Padding" Value="9,7"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
        </Style>
        <Style TargetType="DataGridRow">
            <Setter Property="Foreground" Value="#E6EDF7"/>
        </Style>
    </Window.Resources>
    <DockPanel Margin="16">
        <Border DockPanel.Dock="Top" BorderBrush="#36506F" BorderThickness="0,0,0,1" Padding="0,0,0,12" Margin="0,0,0,14">
            <StackPanel>
                <TextBlock FontSize="25" FontWeight="SemiBold" Text="Clinical Task Workbench"/>
                <TextBlock Foreground="#9FB5D0" Margin="0,3,0,0"
                           Text="Task staging, Active Directory lookup, and clinical application integrations"/>
            </StackPanel>
        </Border>
        <Border DockPanel.Dock="Bottom" Background="#1D2D43" Padding="10,8" CornerRadius="5" Margin="0,10,0,0">
            <DockPanel>
                <TextBlock x:Name="txtStatus" Text="Ready." Foreground="#C6D8EC" TextWrapping="Wrap"/>
                <TextBlock DockPanel.Dock="Right" Text="TOPMOST" Foreground="#8FA7C6" HorizontalAlignment="Right" Margin="12,0,0,0"/>
            </DockPanel>
        </Border>
        <Grid>
            <Grid.RowDefinitions>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="*"/>
            </Grid.RowDefinitions>
            <WrapPanel Grid.Row="0" Margin="0,0,0,3">
                <Button x:Name="btnAddTasks" Content="Add Tasks" Background="#17657A"/>
                <Button x:Name="btnAddUsers" Content="Add Users" Background="#17657A"/>
                <Button x:Name="btnAddLocations" Content="Add Locations" Background="#17657A"/>
                <Button x:Name="btnAddSSO" Content="Add SSO"/>
                <Button x:Name="btnLaunchIvanti" Content="Launch Ivanti"/>
                <Button x:Name="btnLaunchDrMaster" Content="Launch Dr Master"/>
                <Button x:Name="btnLaunchEMOLST" Content="Launch EMOLST"/>
                <Button x:Name="btnLoadEPICUser" Content="Load EPIC User"/>
                <Button x:Name="btnLoadEMOLSTUser" Content="Load EMOLST User"/>
                <Button x:Name="btnLoadDrMasterUser" Content="Load Dr Master User"/>
                <Button x:Name="btnLoadIvantiSummary" Content="Load Ivanti Summary"/>
            </WrapPanel>
            <Border Grid.Row="1" Background="#192A40" CornerRadius="4" Padding="8" Margin="0,2,0,9">
                <DockPanel>
                    <StackPanel Orientation="Horizontal" DockPanel.Dock="Right">
                        <Button x:Name="btnEditAliases" Content="Edit Location Aliases" Padding="9,4" MinHeight="27"/>
                        <Button x:Name="btnRefreshLocations" Content="Update Locations" Padding="9,4" MinHeight="27"/>
                    </StackPanel>
                    <StackPanel>
                        <TextBlock x:Name="txtLocationInfo" Text="Clinical Locations: not loaded" FontWeight="SemiBold"/>
                        <TextBlock x:Name="txtLocationLastWrite" Text="LastWriteDate: N/A" Foreground="#A9BCD4"/>
                    </StackPanel>
                </DockPanel>
            </Border>
            <Grid Grid.Row="2" Margin="0,3,0,10">
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="*"/>
                </Grid.ColumnDefinitions>
                <TextBlock Grid.Column="0" x:Name="txtTaskCount" Text="Tasks (0)" FontWeight="SemiBold" FontSize="17"/>
                <TextBlock Grid.Column="1" x:Name="txtUserCount" Text="Users (0)" FontWeight="SemiBold" FontSize="17"/>
            </Grid>
            <Grid Grid.Row="3">
                <Grid.RowDefinitions>
                    <RowDefinition Height="2*" MinHeight="150"/>
                    <RowDefinition Height="6"/>
                    <RowDefinition Height="*" MinHeight="120"/>
                </Grid.RowDefinitions>
                <Grid Grid.Row="0">
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="*" MinWidth="350"/>
                        <ColumnDefinition Width="7"/>
                        <ColumnDefinition Width="*" MinWidth="350"/>
                    </Grid.ColumnDefinitions>
                    <DataGrid x:Name="gridTasks" Grid.Column="0">
                        <DataGrid.Columns>
                            <DataGridTextColumn Header="Task ID" Binding="{Binding TaskID}" Width="110"/>
                            <DataGridTextColumn Header="Task Type" Binding="{Binding TaskType}" Width="125"/>
                            <DataGridTextColumn Header="Task Note" Binding="{Binding TaskNote}" Width="*"/>
                            <DataGridTextColumn Header="Clinical Location" Binding="{Binding ClinicalLocationDisplay}" Width="170"/>
                            <DataGridTextColumn Header="Provider Location" Binding="{Binding ProviderLocationDisplay}" Width="170"/>
                            <DataGridTextColumn Header="EMOLST User" Binding="{Binding EmolstUserName}" Width="140"/>
                        </DataGrid.Columns>
                    </DataGrid>
                    <GridSplitter Grid.Column="1" Width="7" HorizontalAlignment="Stretch" Background="#354B68"/>
                    <DataGrid x:Name="gridUsers" Grid.Column="2">
                        <DataGrid.Columns>
                            <DataGridTextColumn Header="Task ID" Binding="{Binding TaskID}" Width="90"/>
                            <DataGridTextColumn Header="Display Name" Binding="{Binding DisplayName}" Width="*"/>
                            <DataGridTextColumn Header="SamAccount" Binding="{Binding SamAccountName}" Width="120"/>
                            <DataGridTextColumn Header="Employee ID" Binding="{Binding EmployeeID}" Width="105"/>
                            <DataGridTextColumn Header="Title" Binding="{Binding Title}" Width="130"/>
                            <DataGridTextColumn Header="Email" Binding="{Binding EmailAddress}" Width="190"/>
                        </DataGrid.Columns>
                    </DataGrid>
                </Grid>
                <GridSplitter Grid.Row="1" Height="6" HorizontalAlignment="Stretch" Background="#354B68"/>
                <Grid Grid.Row="2">
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="*"/>
                        <ColumnDefinition Width="*"/>
                    </Grid.ColumnDefinitions>
                    <GroupBox Grid.Column="0" Header="Selected Task — All Properties" Foreground="#D7E6F8" Margin="0,6,5,0">
                        <DataGrid x:Name="gridTaskProperties" Margin="5">
                            <DataGrid.Columns>
                                <DataGridTextColumn Header="Property" Binding="{Binding Property}" Width="180"/>
                                <DataGridTextColumn Header="Value" Binding="{Binding Value}" Width="*"/>
                            </DataGrid.Columns>
                        </DataGrid>
                    </GroupBox>
                    <GroupBox Grid.Column="1" Header="Activity Log" Foreground="#D7E6F8" Margin="5,6,0,0">
                        <TextBox x:Name="txtLog" Margin="5" Background="#121C2C" Foreground="#C7D7ED"
                                 BorderThickness="0" FontFamily="Consolas" FontSize="12"
                                 IsReadOnly="True" VerticalScrollBarVisibility="Auto"
                                 HorizontalScrollBarVisibility="Auto" TextWrapping="NoWrap"/>
                    </GroupBox>
                </Grid>
            </Grid>
        </Grid>
    </DockPanel>
</Window>
'@

function ConvertFrom-WpfXaml {
    param([Parameter(Mandatory)][xml]$Xaml)
    $reader = [System.Xml.XmlNodeReader]::new($Xaml)
    try { return [Windows.Markup.XamlReader]::Load($reader) }
    finally { $reader.Close() }
}

$window = ConvertFrom-WpfXaml $mainXaml
$controlNames = @(
    'btnAddTasks','btnAddUsers','btnAddLocations','btnAddSSO',
    'btnLaunchIvanti','btnLaunchDrMaster','btnLaunchEMOLST',
    'btnLoadEPICUser','btnLoadEMOLSTUser','btnLoadDrMasterUser','btnLoadIvantiSummary',
    'txtTaskCount','txtUserCount','txtStatus','txtLog','txtLocationInfo','txtLocationLastWrite',
    'btnEditAliases','btnRefreshLocations',
    'gridTasks','gridUsers','gridTaskProperties'
)
foreach ($name in $controlNames) { Set-Variable -Name $name -Value $window.FindName($name) -Scope Script }

$script:Tasks = [System.Collections.ObjectModel.ObservableCollection[object]]::new()
$script:Users = [System.Collections.ObjectModel.ObservableCollection[object]]::new()
$script:TaskProperties = [System.Collections.ObjectModel.ObservableCollection[object]]::new()
$script:Locations = [System.Collections.ObjectModel.ObservableCollection[object]]::new()
$script:LocationsPath = Join-Path $env:LOCALAPPDATA 'Get-UHSLocations\Local-UHS-Locations.json'
$script:UpdaterPath = Join-Path $PSScriptRoot 'Update-UHSLocations.ps1'
# DoctorMaster is deliberately loaded once per application session, on first use.
$script:DoctorMasterPath = $null
$script:DoctorMasterRecords = @()
$script:DoctorMasterIndex = @{}
$script:DoctorMasterLoadedAt = $null
$gridTasks.ItemsSource = $script:Tasks
$gridUsers.ItemsSource = $script:Users
$gridTaskProperties.ItemsSource = $script:TaskProperties

$script:TaskFieldNames = @(
    'TaskID','TaskType','TaskNote','EmolstUserName','EmolstAdminRole',
    'EmolstClinicalRole','EmolstTitle','EmolstPrefix','EmolstFirstName',
    'EmolstMiddleName','EmolstLastName','EmolstSuffix','EmolstStreet',
    'EmolstCity','EmolstState','EmolstZip','EmolstPhone','EmolstEmail',
    'EmolstNPI','EmolstProvStateLic','EmolstSSOUsername','EmolstIdentityProvider',
    'ClinicalLocationName','ClinicalLocationAlias','ClinicalLocationDisplay','ClinicalLocationAddress',
    'ClinicalLocationPhone',
    'ProviderLocationName','ProviderLocationAlias','ProviderLocationDisplay','ProviderLocationAddress',
    'ProviderLocationPhone',
    'ProviderNumber','ProviderLastName','ProviderFirstName','ProviderMiddleName',
    'ProviderSuffix','ProviderTitle','ProviderNPI','ProviderAddress1','ProviderAddress2',
    'ProviderCity','ProviderState','ProviderZip','ProviderStateLic','ProviderSourceFile'
)

function Write-Activity {
    param([string]$Message)
    $stamp = Get-Date -Format 'HH:mm:ss'
    $line = '[{0}] {1}' -f $stamp, $Message
    $txtLog.AppendText($line + [Environment]::NewLine)
    $txtLog.ScrollToEnd()
    $txtStatus.Text = $Message
}

function Update-Counters {
    $txtTaskCount.Text = 'Tasks ({0})' -f $script:Tasks.Count
    $txtUserCount.Text = 'Users ({0})' -f $script:Users.Count
}

function New-Task {
    param([Parameter(Mandatory)][string]$TaskID)
    $properties = [ordered]@{}
    foreach ($field in $script:TaskFieldNames) { $properties[$field] = '' }
    $properties['TaskID'] = $TaskID.Trim()
    return [pscustomobject]$properties
}

function Show-TextPrompt {
    param(
        [Parameter(Mandatory)][string]$Title,
        [Parameter(Mandatory)][string]$Message,
        [string]$DefaultValue = '',
        [switch]$Multiline,
        $DialogOwner = $window
    )
    [xml]$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Width="570" Height="250" MinWidth="430" MinHeight="210"
        WindowStartupLocation="CenterOwner" ResizeMode="CanResizeWithGrip"
        Background="#152237" Foreground="White" ShowInTaskbar="False">
    <Grid Margin="17">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>
        <TextBlock x:Name="promptText" TextWrapping="Wrap" FontSize="14" Margin="0,0,0,10"/>
        <TextBox x:Name="responseBox" Grid.Row="1" MinHeight="40" Padding="9,7"
                 Background="#F5F8FD" Foreground="#172437" FontSize="14"
                 VerticalScrollBarVisibility="Auto"/>
        <StackPanel Grid.Row="2" Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,12,0,0">
            <Button x:Name="cancelButton" Content="Cancel" MinWidth="90" Padding="12,7" Margin="0,0,8,0"/>
            <Button x:Name="okButton" Content="OK" MinWidth="90" Padding="12,7" IsDefault="True"/>
        </StackPanel>
    </Grid>
</Window>
'@
    $dlg = ConvertFrom-WpfXaml $xaml
    $dlg.Title = $Title
    $dlg.Owner = $DialogOwner
    $dlg.Topmost = $true
    $messageLabel = $dlg.FindName('promptText')
    $textbox = $dlg.FindName('responseBox')
    $messageLabel.Text = $Message
    $textbox.Text = $DefaultValue
    $textbox.AcceptsReturn = [bool]$Multiline
    $textbox.TextWrapping = if ($Multiline) { 'Wrap' } else { 'NoWrap' }
    $ok = $dlg.FindName('okButton')
    $cancel = $dlg.FindName('cancelButton')
    $ok.Add_Click({ $dlg.DialogResult = $true; $dlg.Close() })
    $cancel.Add_Click({ $dlg.DialogResult = $false; $dlg.Close() })
    $dlg.Add_ContentRendered({ $textbox.Focus(); $textbox.SelectAll() })
    if ($dlg.ShowDialog() -eq $true) { return $textbox.Text }
    return $null
}

function Show-UserPicker {
    param([object[]]$Matches, [string]$TaskID)
    [xml]$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Width="850" Height="430" MinWidth="650" MinHeight="320"
        WindowStartupLocation="CenterOwner" Background="#152237" Foreground="White"
        ShowInTaskbar="False">
    <DockPanel Margin="14">
        <TextBlock x:Name="intro" DockPanel.Dock="Top" FontSize="14" Margin="0,0,0,12"/>
        <StackPanel DockPanel.Dock="Bottom" Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,12,0,0">
            <Button x:Name="cancelButton" Content="Skip Task" MinWidth="110" Padding="12,7" Margin="0,0,8,0"/>
            <Button x:Name="selectButton" Content="Use Selected User" MinWidth="145" Padding="12,7" IsDefault="True"/>
        </StackPanel>
        <DataGrid x:Name="matchesGrid" AutoGenerateColumns="False" IsReadOnly="True"
                  SelectionMode="Single" CanUserAddRows="False" HeadersVisibility="Column"
                  Background="#EDF3FA" Foreground="#122039" AlternatingRowBackground="#DCE6F4"
                  RowBackground="#EDF3FA" GridLinesVisibility="Horizontal">
            <DataGrid.Columns>
                <DataGridTextColumn Header="Display Name" Binding="{Binding DisplayName}" Width="*"/>
                <DataGridTextColumn Header="SamAccountName" Binding="{Binding SamAccountName}" Width="140"/>
                <DataGridTextColumn Header="EmployeeID" Binding="{Binding EmployeeID}" Width="120"/>
                <DataGridTextColumn Header="Email" Binding="{Binding EmailAddress}" Width="230"/>
            </DataGrid.Columns>
        </DataGrid>
    </DockPanel>
</Window>
'@
    $dlg = ConvertFrom-WpfXaml $xaml
    $dlg.Owner = $window
    $dlg.Topmost = $true
    $dlg.Title = 'Select Active Directory User'
    $dlg.FindName('intro').Text = 'Task {0}: multiple AD matches. Select the correct user.' -f $TaskID
    $matchesGrid = $dlg.FindName('matchesGrid')
    $matchesGrid.ItemsSource = @($Matches)
    $matchesGrid.SelectedIndex = 0
    $selected = $null
    $dlg.FindName('selectButton').Add_Click({
        if ($null -ne $matchesGrid.SelectedItem) {
            $dlg.Tag = $matchesGrid.SelectedItem
            $dlg.DialogResult = $true
            $dlg.Close()
        }
    })
    $dlg.FindName('cancelButton').Add_Click({ $dlg.DialogResult = $false; $dlg.Close() })
    $matchesGrid.Add_MouseDoubleClick({
        if ($null -ne $matchesGrid.SelectedItem) {
            $dlg.Tag = $matchesGrid.SelectedItem
            $dlg.DialogResult = $true
            $dlg.Close()
        }
    })
    if ($dlg.ShowDialog() -eq $true) { $selected = $dlg.Tag }
    return $selected
}

function Update-TaskDetails {
    $script:TaskProperties.Clear()
    $task = $gridTasks.SelectedItem
    if ($null -eq $task) { return }
    foreach ($field in $script:TaskFieldNames) {
        $script:TaskProperties.Add([pscustomobject]@{
            Property = $field
            Value = [string]$task.$field
        })
    }
}

function Add-TaskIDs {
    param([string]$InputText)
    # Commas split the input. New lines are supported as a convenience.
    $ids = @($InputText -split '[,\r\n]+' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    $added = 0
    foreach ($id in $ids) {
        if (@($script:Tasks | Where-Object { $_.TaskID -ieq $id }).Count -gt 0) {
            Write-Activity ('Task {0} already exists; skipped.' -f $id)
            continue
        }
        $script:Tasks.Add((New-Task -TaskID $id))
        $added++
    }
    Update-Counters
    Update-WorkflowButtons
    if ($added -gt 0) {
        $gridTasks.SelectedItem = $script:Tasks[$script:Tasks.Count - 1]
    }
    Write-Activity ('Added {0} task(s); total {1}.' -f $added, $script:Tasks.Count)
}

function Find-AdUserExact {
    param([Parameter(Mandatory)][string]$SearchTerm)
    # Preserve the multi-attribute exact-match filter requested for this tool.
    $filter = "SamAccountName -eq '{0}' -or CN -eq '{0}' -or Name -eq '{0}' -or DisplayName -eq '{0}' -or EmailAddress -eq '{0}' -or EmployeeID -eq '{0}' -or mail -eq '{0}' -or mailNickname -eq '{0}' -or GivenName -eq '{0}' -or OtherName -eq '{0}' -or MiddleName -eq '{0}' -or sn -eq '{0}' -or surname -eq '{0}' -or UserPrincipalName -eq '{0}'" -f ($SearchTerm -replace "'", "''")
    return @(Get-ADUser -Filter $filter -Properties * -ErrorAction Stop)
}

function Add-AdUserForTask {
    param([Parameter(Mandatory)]$Task, [Parameter(Mandatory)][string]$SearchTerm)
    try {
        $matches = @(Find-AdUserExact -SearchTerm $SearchTerm)
    }
    catch {
        Write-Activity ('AD lookup failed for task {0}: {1}' -f $Task.TaskID, $_.Exception.Message)
        [System.Windows.MessageBox]::Show($window,
            ('AD search failed for task {0}.{1}{2}' -f $Task.TaskID, [Environment]::NewLine, $_.Exception.Message),
            'Active Directory Error', 'OK', 'Error') | Out-Null
        return
    }
    if ($matches.Count -eq 0) {
        Write-Activity ('No exact AD match: task {0}, search "{1}".' -f $Task.TaskID, $SearchTerm)
        return
    }
    $user = if ($matches.Count -eq 1) { $matches[0] } else { Show-UserPicker -Matches $matches -TaskID $Task.TaskID }
    if ($null -eq $user) { Write-Activity ('Skipped user association for task {0}.' -f $Task.TaskID); return }

    $sid = if ($null -ne $user.SID) { [string]$user.SID.Value } else { [string]$user.DistinguishedName }
    $existing = @($script:Users | Where-Object { $_.TaskID -eq $Task.TaskID -and $_.Identifier -eq $sid })
    if ($existing.Count -gt 0) {
        Write-Activity ('User {0} is already assigned to task {1}.' -f $user.SamAccountName, $Task.TaskID)
        return
    }
    $record = [pscustomobject]@{
        TaskID = [string]$Task.TaskID
        DisplayName = [string]$user.DisplayName
        SamAccountName = [string]$user.SamAccountName
        EmployeeID = [string]$user.EmployeeID
        Title = [string]$user.Title
        EmailAddress = [string]$user.EmailAddress
        UserPrincipalName = [string]$user.UserPrincipalName
        GivenName = [string]$user.GivenName
        Surname = [string]$user.Surname
        DistinguishedName = [string]$user.DistinguishedName
        Identifier = $sid
        ADObject = $user
    }
    $script:Users.Add($record)
    if ([string]::IsNullOrWhiteSpace($Task.EmolstUserName)) {
        $Task.EmolstUserName = [string]$user.SamAccountName
        $gridTasks.Items.Refresh()
        Update-TaskDetails
    }
    Update-Counters
    Update-WorkflowButtons
    Write-Activity ('Linked {0} to task {1} ({2} AD match(es)).' -f $user.SamAccountName, $Task.TaskID, $matches.Count)
}

function Expand-UhsLocationRecords {
    param($Data)
    # Older UHS exports serialized a Generic.List as a wrapper with SyncRoot.
    # Arrays also expose a SyncRoot .NET property, so check for arrays FIRST.
    if ($null -eq $Data) { return }
    if ($Data -is [array]) {
        foreach ($record in $Data) { Expand-UhsLocationRecords -Data $record }
        return
    }
    if ($Data -is [System.Collections.IDictionary]) {
        if ($Data.Contains('Name')) { Write-Output ([pscustomobject]$Data); return }
        if ($Data.Contains('SyncRoot')) { Expand-UhsLocationRecords -Data $Data['SyncRoot']; return }
    }
    $properties = $Data.PSObject.Properties
    if ($null -ne $properties['Name'] -and -not [string]::IsNullOrWhiteSpace([string]$Data.Name)) {
        Write-Output $Data
        return
    }
    if ($null -ne $properties['SyncRoot']) {
        Expand-UhsLocationRecords -Data $Data.SyncRoot
        return
    }
    if ($Data -is [System.Collections.IEnumerable] -and $Data -isnot [string]) {
        foreach ($record in $Data) { Expand-UhsLocationRecords -Data $record }
    }
}

function Read-ClinicalLocations {
    $script:Locations.Clear()
    if (-not (Test-Path -LiteralPath $script:LocationsPath -PathType Leaf)) {
        $txtLocationInfo.Text = 'Clinical Locations: file not found'
        $txtLocationLastWrite.Text = 'LastWriteDate: N/A'
        Write-Activity ('Locations file not found: {0}' -f $script:LocationsPath)
        return
    }
    try {
        $raw = [System.IO.File]::ReadAllText($script:LocationsPath)
        $parsed = ConvertFrom-Json -InputObject $raw -ErrorAction Stop
        $records = @(Expand-UhsLocationRecords -Data $parsed)
        foreach ($r in $records) {
            if ($null -eq $r -or $r.Name -is [array] -or [string]::IsNullOrWhiteSpace([string]$r.Name)) { continue }
            $script:Locations.Add([pscustomobject]@{
                Name=[string]$r.Name; Location=[string]$r.Location; Phone=[string]$r.Phone
                Address1=[string]$r.Address1; Address2=[string]$r.Address2
                Address=(@([string]$r.Address1,[string]$r.Address2) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }) -join ", "
                Locality=[string]$r.Locality; State=[string]$r.State; Zip=[string]$r.Zip
            })
        }
        $date = (Get-Item -LiteralPath $script:LocationsPath).LastWriteTime
        $txtLocationInfo.Text = 'Clinical Locations: {0} loaded' -f $script:Locations.Count
        $txtLocationLastWrite.Text = 'LastWriteDate: {0:yyyy-MM-dd HH:mm:ss}    |    {1}' -f $date,$script:LocationsPath
        Write-Activity ('Loaded {0} clinical locations. Last modified {1:yyyy-MM-dd HH:mm:ss}.' -f $script:Locations.Count,$date)
    }
    catch {
        $txtLocationInfo.Text = 'Clinical Locations: load error'
        Write-Activity ('Location JSON load failed: {0}' -f $_.Exception.Message)
    }
}
function Save-ClinicalAliases {
    $folder = Split-Path -Parent $script:LocationsPath
    if (-not (Test-Path -LiteralPath $folder)) { $null = New-Item -ItemType Directory -Path $folder -Force }
    $tmp = Join-Path $folder ('.alias-{0}.tmp' -f [guid]::NewGuid().ToString('N'))
    try {
        # Serialize individual facility objects as a JSON array, not a collection wrapper.
        $rows = @($script:Locations | ForEach-Object {
            [pscustomobject][ordered]@{
                Name=[string]$_.Name; Location=[string]$_.Location; Phone=[string]$_.Phone
                Address1=[string]$_.Address1; Address2=[string]$_.Address2
                Locality=[string]$_.Locality; State=[string]$_.State; Zip=[string]$_.Zip
            }
        })
        $json = ConvertTo-Json -InputObject $rows -Depth 8
        [System.IO.File]::WriteAllText($tmp,$json,[System.Text.UTF8Encoding]::new($true))
        if (Test-Path -LiteralPath $script:LocationsPath) {
            Copy-Item -LiteralPath $script:LocationsPath -Destination ($script:LocationsPath + '.bak') -Force
        }
        Move-Item -LiteralPath $tmp -Destination $script:LocationsPath -Force
        $txtLocationLastWrite.Text = 'LastWriteDate: {0:yyyy-MM-dd HH:mm:ss}    |    {1}' -f (Get-Item -LiteralPath $script:LocationsPath).LastWriteTime,$script:LocationsPath
    }
    finally { if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue } }
}
function Set-TaskClinicalLocation {
    param($Task,$Location)
    $Task.ClinicalLocationName = [string]$Location.Name
    $Task.ClinicalLocationAlias = [string]$Location.Location
    $Task.ClinicalLocationDisplay = if ([string]::IsNullOrWhiteSpace([string]$Location.Location)) { [string]$Location.Name } else { '{0} ({1})' -f $Location.Location,$Location.Name }
    $Task.ClinicalLocationAddress = (@([string]$Location.Address1,[string]$Location.Address2,[string]$Location.Locality,[string]$Location.State,[string]$Location.Zip) | Where-Object { $_ }) -join ', '
    $Task.ClinicalLocationPhone = [string]$Location.Phone
    $gridTasks.Items.Refresh()
    Update-TaskDetails
    Write-Activity ('Task {0}: clinical location set to {1}.' -f $Task.TaskID,$Task.ClinicalLocationDisplay)
}
function Show-ClinicalLocationDetails {
    param($Task)
    if (-not $Task -or [string]::IsNullOrWhiteSpace([string]$Task.ClinicalLocationName)) {
        [System.Windows.MessageBox]::Show($window,'No clinical location has been assigned to this task.','Show Clin Loc','OK','Information') | Out-Null
        return
    }
    $message = "Task: $($Task.TaskID)`nFacility: $($Task.ClinicalLocationName)`nAlias: $($Task.ClinicalLocationAlias)`nAddress: $($Task.ClinicalLocationAddress)`nPhone: $($Task.ClinicalLocationPhone)"
    [System.Windows.MessageBox]::Show($window,$message,'Show Clin Loc','OK','Information') | Out-Null
}
function Show-LocationPicker {
    param([string]$Title,[switch]$AliasEditor,$Task,$DialogOwner = $window)
    [xml]$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Width="1150" Height="580" MinWidth="780" MinHeight="370"
        WindowStartupLocation="CenterOwner" Background="#152237" Foreground="White" ShowInTaskbar="False">
    <DockPanel Margin="12">
        <TextBlock x:Name="lblIntro" DockPanel.Dock="Top" TextWrapping="Wrap" Margin="0,0,0,8"/>
        <TextBox x:Name="txtSearch" DockPanel.Dock="Top" Margin="0,0,0,9" Padding="8,6"
                 Background="#F0F5FB" Foreground="#142337" ToolTip="Search name, alias, address, city, state or ZIP"/>
        <StackPanel DockPanel.Dock="Bottom" Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,10,0,0">
            <Button x:Name="btnAlias" Content="Edit Alias" Padding="10,7" Margin="0,0,7,0"/>
            <Button x:Name="btnCancel" Content="Cancel" Padding="10,7" Margin="0,0,7,0"/>
            <Button x:Name="btnChoose" Content="Use Selected Location" IsDefault="True" Padding="10,7"/>
        </StackPanel>
        <DataGrid x:Name="gridLocations" AutoGenerateColumns="False" IsReadOnly="True"
                  CanUserAddRows="False" SelectionMode="Single" HeadersVisibility="Column"
                  Background="#EDF3FA" Foreground="#122039" RowBackground="#EDF3FA"
                  AlternatingRowBackground="#DCE6F4" GridLinesVisibility="Horizontal">
            <DataGrid.Columns>
                <DataGridTextColumn Header="Alias" Binding="{Binding Location}" Width="100"/>
                <DataGridTextColumn Header="Name" Binding="{Binding Name}" Width="260"/>
                <DataGridTextColumn Header="Address" Binding="{Binding Address}" Width="260"/>
                <DataGridTextColumn Header="ZIP" Binding="{Binding Zip}" Width="90"/>
                <DataGridTextColumn Header="City" Binding="{Binding Locality}" Width="125"/>
                <DataGridTextColumn Header="State" Binding="{Binding State}" Width="60"/>
                <DataGridTextColumn Header="Phone" Binding="{Binding Phone}" Width="140"/>
            </DataGrid.Columns>
        </DataGrid>
    </DockPanel>
</Window>
'@
    $dlg = ConvertFrom-WpfXaml $xaml
    $dlg.Title = $Title
    $dlg.Owner = $DialogOwner
    $dlg.Topmost = $true
    $lbl = $dlg.FindName('lblIntro')
    $lbl.Text = if ($AliasEditor) { 'Edit aliases in the Location field. Changes are saved in local JSON immediately.' } else { 'Task {0}: search and select a location. Use Edit Alias to assign a short name.' -f $Task.TaskID }
    $grid = $dlg.FindName('gridLocations')
    $search = $dlg.FindName('txtSearch')
    $view = [System.Windows.Data.CollectionViewSource]::GetDefaultView($script:Locations)
    $grid.ItemsSource = $view
    $filterHandler = [System.Predicate[object]]{
        param($item)
        $term = [string]$search.Text
        if ([string]::IsNullOrWhiteSpace($term)) { return $true }
        foreach ($field in @('Name','Location','Address1','Address2','Locality','State','Zip')) {
            if ([string]$item.$field -like ('*' + [WildcardPattern]::Escape($term.Trim()) + '*')) { return $true }
        }
        return $false
    }
    $view.Filter = $filterHandler
    $search.Add_TextChanged({ $view.Refresh() })
    $dlg.FindName('btnAlias').Add_Click({
        $loc = $grid.SelectedItem
        if ($null -eq $loc) { return }
        $alias = Show-TextPrompt -Title ('Alias: {0}' -f $loc.Name) -Message 'Set the Location alias (for example, WMC). Leave blank to clear:' -DefaultValue $loc.Location -DialogOwner $dlg
        if ($null -eq $alias) { return }
        $previous = [string]$loc.Location
        try {
            $loc.Location = $alias.Trim()
            Save-ClinicalAliases
            $grid.Items.Refresh()
            $view.Refresh()
            Write-Activity ('Saved alias "{0}" for "{1}".' -f $loc.Location,$loc.Name)
        }
        catch {
            $loc.Location = $previous
            [System.Windows.MessageBox]::Show($dlg,$_.Exception.Message,'Alias Save Failed','OK','Error') | Out-Null
        }
    })
    $dlg.FindName('btnCancel').Add_Click({ $dlg.DialogResult = $false })
    $choose = $dlg.FindName('btnChoose')
    if ($AliasEditor) { $choose.Visibility = 'Collapsed' }
    $choose.Add_Click({ if ($null -ne $grid.SelectedItem) { $dlg.Tag = $grid.SelectedItem; $dlg.DialogResult = $true } })
    $dlg.Add_Closed({ $view.Filter = $null })
    $dlg.Add_ContentRendered({ $search.Focus() })
    if ($dlg.ShowDialog() -eq $true) { return $dlg.Tag }
    return $null
}

function Get-TaskUser {
    param($Task)
    return @($script:Users | Where-Object { $_.TaskID -eq $Task.TaskID } | Select-Object -First 1)[0]
}

function Update-WorkflowButtons {
    $hasTasks = ($script:Tasks.Count -gt 0)
    $btnAddUsers.IsEnabled = $hasTasks
    $complete = $hasTasks
    if ($complete) {
        foreach ($task in $script:Tasks) {
            if ($null -eq (Get-TaskUser -Task $task)) { $complete = $false; break }
        }
    }
    $btnAddLocations.IsEnabled = $complete
    # Clinical Locations maintenance is independent of Add Tasks/Add Users.
    # The click handlers handle missing location data or updater files.
    $btnEditAliases.IsEnabled = $true
    $btnRefreshLocations.IsEnabled = $true
    # Steps following Add Users cannot run until each task has an assigned AD user.
    foreach ($button in @($btnAddSSO,$btnLaunchIvanti,$btnLaunchDrMaster,$btnLaunchEMOLST,
                           $btnLoadEPICUser,$btnLoadEMOLSTUser,$btnLoadDrMasterUser,$btnLoadIvantiSummary)) {
        $button.IsEnabled = $complete
    }
}

function Get-DoctorMasterKey {
    param($Value)
    if ($null -eq $Value) { return '' }
    # Number and SamAccount are matched case-insensitively; never strip an E prefix
    # or leading zeroes from IDs, because those changes could match the wrong person.
    return ([string]$Value).Trim().ToUpperInvariant()
}

function Get-DoctorMasterHeaderKey {
    param($Value)
    return ([regex]::Replace(([string]$Value).Trim().ToLowerInvariant(), '[^a-z0-9]', ''))
}

function Select-DoctorMasterFile {
    $picker = New-Object Microsoft.Win32.OpenFileDialog
    $picker.Title = 'Select DoctorMaster export for this session'
    $picker.Filter = 'DoctorMaster exports (*.xls;*.xlsx;*.csv)|*.xls;*.xlsx;*.csv|Excel 97-2003 (*.xls)|*.xls|Excel Workbook (*.xlsx)|*.xlsx|CSV files (*.csv)|*.csv|All files (*.*)|*.*'
    $picker.CheckFileExists = $true
    $picker.Multiselect = $false
    if ($script:DoctorMasterPath) { $picker.InitialDirectory = Split-Path -Parent $script:DoctorMasterPath }
    if ($picker.ShowDialog($window) -ne $true) { return $null }
    return $picker.FileName
}

function ConvertTo-DoctorMasterRow {
    param($RawRow, [string[]]$Expected)
    $entry = [ordered]@{}
    foreach ($field in $Expected) {
        $prop = $RawRow.PSObject.Properties[$field]
        $entry[$field] = if ($null -ne $prop -and $null -ne $prop.Value) { ([string]$prop.Value).Trim() } else { '' }
    }
    if ([string]::IsNullOrWhiteSpace($entry['Number'])) { return $null }
    $entry['LastName'] = $entry['Last Name']
    $entry['FirstName'] = $entry['First Name']
    $entry['MiddleName'] = $entry['Middle Name']
    return [pscustomobject]$entry
}

function Read-DoctorMasterWithoutExcel {
    param([string]$Path, [string[]]$Expected)
    $extension = [System.IO.Path]::GetExtension($Path).ToLowerInvariant()
    $rows = New-Object 'System.Collections.Generic.List[object]'
    if ($extension -eq '.csv') {
        # Import-Csv is built into PowerShell 5.1 and does not require Excel or any add-on.
        $csv = @(Import-Csv -LiteralPath $Path -ErrorAction Stop)
        if ($csv.Count -eq 0) { throw 'The DoctorMaster CSV file is empty.' }
        $headers = @{}
        foreach ($prop in $csv[0].PSObject.Properties) {
            $headers[(Get-DoctorMasterHeaderKey $prop.Name)] = $prop.Name
        }
        foreach ($key in @('number','lastname','firstname')) {
            if (-not $headers.ContainsKey($key)) { throw ('DoctorMaster CSV is missing a required column: {0}.' -f $key) }
        }
        foreach ($row in $csv) {
            $values = [ordered]@{}
            foreach ($field in $Expected) {
                $key = Get-DoctorMasterHeaderKey $field
                $value = if ($headers.ContainsKey($key)) { $row.($headers[$key]) } else { '' }
                $values[$field] = if ($null -ne $value) { [string]$value } else { '' }
            }
            $rec = ConvertTo-DoctorMasterRow -RawRow ([pscustomobject]$values) -Expected $Expected
            if ($null -ne $rec) { $rows.Add($rec) }
        }
        return $rows.ToArray()
    }
    # ACE OleDb reads .xls/.xlsx directly without the Excel application, IF the
    # Microsoft Access Database Engine (matching the PowerShell process bitness) is installed.
    $props = if ($extension -eq '.xls') { 'Excel 8.0;HDR=No;IMEX=1' } else { 'Excel 12.0 Xml;HDR=No;IMEX=1' }
    $connection = $null
    $failures = @()
    foreach ($provider in @('Microsoft.ACE.OLEDB.16.0','Microsoft.ACE.OLEDB.12.0')) {
        $candidate = $null
        try {
            $connString = 'Provider={0};Data Source={1};Extended Properties="{2}";' -f $provider,$Path,$props
            $candidate = New-Object System.Data.OleDb.OleDbConnection($connString)
            $candidate.Open()
            $connection = $candidate
            break
        }
        catch { $failures += ('{0}: {1}' -f $provider,$_.Exception.Message); if ($candidate) { $candidate.Dispose() } }
    }
    if (-not $connection) {
        throw ('Excel is not installed and ACE OLEDB could not open this workbook. Export DoctorMaster as CSV on the Excel machine and select the CSV here (no Office required), or install a compatible Microsoft Access Database Engine. Details: {0}' -f ($failures -join ' | '))
    }
    try {
        $schema = $connection.GetOleDbSchemaTable([System.Data.OleDb.OleDbSchemaGuid]::Tables,$null)
        $found = $false
        foreach ($table in $schema.Rows) {
            $tableName = [string]$table['TABLE_NAME']
            if ($tableName -notmatch '\$$' -and $tableName -notmatch '\$\x27$') { continue }
            $escapedName = $tableName.Replace(']', ']]')
            $cmd = $connection.CreateCommand()
            $cmd.CommandText = 'SELECT * FROM [{0}]' -f $escapedName
            $adapter = New-Object System.Data.OleDb.OleDbDataAdapter($cmd)
            $data = New-Object System.Data.DataTable
            try { [void]$adapter.Fill($data) }
            finally { $adapter.Dispose(); $cmd.Dispose() }
            $map = @{}; $headerRow = -1
            for ($r=0; $r -lt [math]::Min(20,$data.Rows.Count); $r++) {
                $candidate = @{}
                for ($c=0; $c -lt $data.Columns.Count; $c++) {
                    $key = Get-DoctorMasterHeaderKey $data.Rows[$r][$c]
                    foreach ($field in $Expected) {
                        if ($key -eq (Get-DoctorMasterHeaderKey $field)) { $candidate[$field] = $c; break }
                    }
                }
                if ($candidate.ContainsKey('Number') -and $candidate.ContainsKey('Last Name') -and $candidate.ContainsKey('First Name')) {
                    $map = $candidate; $headerRow = $r; break
                }
            }
            if ($headerRow -lt 0) { continue }
            $found = $true
            for ($r=$headerRow+1; $r -lt $data.Rows.Count; $r++) {
                $values = [ordered]@{}
                foreach ($field in $Expected) {
                    $value = if ($map.ContainsKey($field)) { $data.Rows[$r][[int]$map[$field]] } else { $null }
                    $values[$field] = if ($null -eq $value -or $value -is [DBNull]) { '' } else { ([string]$value).Trim() }
                }
                $rec = ConvertTo-DoctorMasterRow -RawRow ([pscustomobject]$values) -Expected $Expected
                if ($null -ne $rec) { $rows.Add($rec) }
            }
            break
        }
        if (-not $found) { throw 'Could not locate Number, Last Name, and First Name headers in the DoctorMaster workbook.' }
    }
    finally { $connection.Dispose() }
    return $rows.ToArray()
}

function Import-DoctorMasterFile {
    param([Parameter(Mandatory)][string]$Path)
    $excel = $null; $workbook = $null; $sheet = $null; $usedRange = $null
    $newRows = New-Object 'System.Collections.Generic.List[object]'
    $expected = @('Number','Last Name','First Name','Middle Name','Suffix','Title','NPI',
                  'Address1','Address2','City','State','Zip','Phone','StateLic')
    $preferredHeaders = @{}
    foreach ($field in $expected) { $preferredHeaders[(Get-DoctorMasterHeaderKey $field)] = $field }
    $withoutExcel = $false
    if ([System.IO.Path]::GetExtension($Path).ToLowerInvariant() -eq '.csv') {
        $withoutExcel = $true
    }
    else {
        try { $excel = New-Object -ComObject Excel.Application -ErrorAction Stop }
        catch { $withoutExcel = $true }
    }
    if ($withoutExcel) {
        $fallbackRows = @(Read-DoctorMasterWithoutExcel -Path $Path -Expected $expected)
        foreach ($record in $fallbackRows) { if ($null -ne $record) { $newRows.Add($record) } }
    }
    else {
    try {
        $excel.Visible = $false
        $excel.DisplayAlerts = $false
        try { $excel.AutomationSecurity = 3 } catch { }
        $workbook = $excel.Workbooks.Open($Path,0,$true)
        # Look for the requested headers in the first 20 rows of each worksheet.
        $found = $false
        foreach ($ws in $workbook.Worksheets) {
            $sheet = $ws
            $usedRange = $sheet.UsedRange
            $data = $usedRange.Value2
            if ($null -eq $data) { [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($usedRange); $usedRange=$null; [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($sheet); $sheet=$null; continue }
            $rowCount = $usedRange.Rows.Count
            $colCount = $usedRange.Columns.Count
            $isMatrix = $data -is [System.Array] -and $data.Rank -eq 2
            if ($isMatrix) { $rowBase = $data.GetLowerBound(0); $colBase = $data.GetLowerBound(1) }
            else { $rowBase=1; $colBase=1 }
            $headerRow = 0
            $map = @{}
            for ($r=0; $r -lt [math]::Min($rowCount,20); $r++) {
                $candidate = @{}
                for ($c=0; $c -lt $colCount; $c++) {
                    $v = if ($isMatrix) { $data.GetValue(($r+$rowBase),($c+$colBase)) } elseif ($r -eq 0 -and $c -eq 0) { $data } else { $null }
                    $key = Get-DoctorMasterHeaderKey $v
                    if ($preferredHeaders.ContainsKey($key)) { $candidate[$preferredHeaders[$key]] = $c }
                }
                if ($candidate.ContainsKey('Number') -and $candidate.ContainsKey('Last Name') -and $candidate.ContainsKey('First Name')) {
                    $headerRow=$r+1; $map=$candidate; break
                }
            }
            if ($headerRow -eq 0) {
                [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($usedRange); $usedRange=$null
                [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($sheet); $sheet=$null
                continue
            }
            $found = $true
            $missing = @($expected | Where-Object { -not $map.ContainsKey($_) })
            if ($missing.Count -gt 0) { Write-Activity ('DoctorMaster: absent columns will be blank: {0}' -f ($missing -join ', ')) }
            for ($r=$headerRow; $r -lt $rowCount; $r++) {
                $entry = [ordered]@{}
                foreach ($field in $expected) {
                    $val = $null
                    if ($map.ContainsKey($field)) {
                        $c = [int]$map[$field]
                        if ($isMatrix) { $val = $data.GetValue(($r+$rowBase),($c+$colBase)) }
                        elseif ($r -eq 0 -and $c -eq 0) { $val=$data }
                    }
                    $entry[$field] = if ($null -eq $val) { '' } else { ([string]$val).Trim() }
                }
                if (-not [string]::IsNullOrWhiteSpace($entry['Number'])) {
                    # WPF bindings cannot reliably address PSCustomObject property names containing spaces.
                    $entry['LastName']   = $entry['Last Name']
                    $entry['FirstName']  = $entry['First Name']
                    $entry['MiddleName'] = $entry['Middle Name']
                    $newRows.Add([pscustomobject]$entry)
                }
            }
            break
        }
        if (-not $found) { throw 'Could not find a worksheet with Number, Last Name, and First Name column headers. Verify the selected DoctorMaster export.' }
    }
    finally {
        if ($null -ne $workbook) { try { $workbook.Close($false) } catch {} }
        if ($null -ne $usedRange) { [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($usedRange) }
        if ($null -ne $sheet) { [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($sheet) }
        if ($null -ne $workbook) { [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($workbook) }
        if ($null -ne $excel) { try { $excel.Quit() } catch {} ; [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($excel) }
    }
    }
    # Build the index only after successfully importing and closing the workbook.
    $newIndex = @{}
    foreach ($row in $newRows) {
        $key = Get-DoctorMasterKey $row.Number
        if (-not $newIndex.ContainsKey($key)) { $newIndex[$key] = New-Object 'System.Collections.Generic.List[object]' }
        $newIndex[$key].Add($row)
    }
    $script:DoctorMasterRecords = $newRows.ToArray()
    $script:DoctorMasterIndex = $newIndex
    $script:DoctorMasterPath = $Path
    $script:DoctorMasterLoadedAt = Get-Date
    Write-Activity ('DoctorMaster: loaded {0:N0} rows ({1:N0} distinct Numbers) from {2}.' -f $newRows.Count,$newIndex.Count,(Split-Path -Leaf $Path))
}

function Ensure-DoctorMasterLoaded {
    if ($script:DoctorMasterPath -and $script:DoctorMasterRecords.Count -gt 0) { return $true }
    $path = Select-DoctorMasterFile
    if (-not $path) { return $false }
    try {
        Import-DoctorMasterFile -Path $path
        return $true
    }
    catch {
        Write-Activity ('DoctorMaster import error: {0}' -f $_.Exception.Message)
        [System.Windows.MessageBox]::Show($window,$_.Exception.Message,'DoctorMaster Import Error','OK','Error') | Out-Null
        return $false
    }
}

function Show-DoctorMasterMatchDialog {
    param($Task, [object[]]$Matches, $DialogOwner)
    [xml]$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="DoctorMaster Provider Match" Width="1100" Height="570" MinWidth="740" MinHeight="380"
        WindowStartupLocation="CenterOwner" ShowInTaskbar="False" Topmost="True"
        Background="#152237" Foreground="White">
    <DockPanel Margin="14">
        <TextBlock x:Name="txtIntro" DockPanel.Dock="Top" TextWrapping="Wrap" Margin="0,0,0,10" FontSize="14"/>
        <StackPanel DockPanel.Dock="Bottom" Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,12,0,0">
            <Button x:Name="btnCancel" Content="Cancel" Padding="14,8" Margin="0,0,8,0"/>
            <Button x:Name="btnUse" Content="Use Selected Provider" Padding="14,8" IsDefault="True"/>
        </StackPanel>
        <TextBox x:Name="txtFilter" DockPanel.Dock="Top" Padding="8" Margin="0,0,0,10" ToolTip="Filter matching rows by name, NPI, title or address"/>
        <DataGrid x:Name="grid" IsReadOnly="True" AutoGenerateColumns="False" SelectionMode="Single"
                  CanUserAddRows="False" AlternatingRowBackground="#E7F0FA" RowBackground="White"
                  Foreground="Black" HeadersVisibility="Column" HorizontalScrollBarVisibility="Auto"
                  VerticalScrollBarVisibility="Auto">
            <DataGrid.Columns>
                <DataGridTextColumn Header="Number" Binding="{Binding Number}" Width="110"/>
                <DataGridTextColumn Header="Last Name" Binding="{Binding LastName}" Width="140"/>
                <DataGridTextColumn Header="First Name" Binding="{Binding FirstName}" Width="125"/>
                <DataGridTextColumn Header="Middle Name" Binding="{Binding MiddleName}" Width="105"/>
                <DataGridTextColumn Header="Suffix" Binding="{Binding Suffix}" Width="65"/>
                <DataGridTextColumn Header="Title" Binding="{Binding Title}" Width="130"/>
                <DataGridTextColumn Header="NPI" Binding="{Binding NPI}" Width="120"/>
                <DataGridTextColumn Header="Address1" Binding="{Binding Address1}" Width="200"/>
                <DataGridTextColumn Header="Address2" Binding="{Binding Address2}" Width="155"/>
                <DataGridTextColumn Header="City" Binding="{Binding City}" Width="125"/>
                <DataGridTextColumn Header="State" Binding="{Binding State}" Width="55"/>
                <DataGridTextColumn Header="ZIP" Binding="{Binding Zip}" Width="95"/>
                <DataGridTextColumn Header="Phone" Binding="{Binding Phone}" Width="120"/>
                <DataGridTextColumn Header="StateLic" Binding="{Binding StateLic}" Width="120"/>
            </DataGrid.Columns>
        </DataGrid>
    </DockPanel>
</Window>
'@
    $dlg = ConvertFrom-WpfXaml $xaml
    $dlg.Owner = $DialogOwner
    $dlg.FindName('txtIntro').Text = ('Task {0} | SamAccount: {1} | {2} matching DoctorMaster row(s). Confirm the correct provider.' -f $Task.TaskID,(Get-TaskUser -Task $Task).SamAccountName,$Matches.Count)
    $grid = $dlg.FindName('grid')
    $grid.ItemsSource = $Matches
    $grid.SelectedIndex = 0
    $search = $dlg.FindName('txtFilter')
    $view = [System.Windows.Data.CollectionViewSource]::GetDefaultView($grid.ItemsSource)
    $search.Add_TextChanged({
        $needle = $search.Text.Trim()
        $view.Filter = [Predicate[object]] {
            param($r)
            if (-not $needle) { return $true }
            foreach ($prop in $r.PSObject.Properties) {
                if ([string]$prop.Value -like ('*' + [System.Management.Automation.WildcardPattern]::Escape($needle) + '*')) { return $true }
            }
            return $false
        }
        $view.Refresh()
    })
    $dlg.FindName('btnUse').Add_Click({ if ($null -ne $grid.SelectedItem) { $dlg.Tag=$grid.SelectedItem; $dlg.DialogResult=$true } })
    $dlg.FindName('btnCancel').Add_Click({ $dlg.DialogResult=$false })
    $grid.Add_MouseDoubleClick({ if ($null -ne $grid.SelectedItem) { $dlg.Tag=$grid.SelectedItem; $dlg.DialogResult=$true } })
    if ($dlg.ShowDialog() -eq $true) { return $dlg.Tag }
    return $null
}

function Set-TaskProviderLocation {
    param($Task,$Provider)
    $Task.ProviderNumber     = [string]$Provider.Number
    $Task.ProviderLastName   = [string]$Provider.'Last Name'
    $Task.ProviderFirstName  = [string]$Provider.'First Name'
    $Task.ProviderMiddleName = [string]$Provider.'Middle Name'
    $Task.ProviderSuffix     = [string]$Provider.Suffix
    $Task.ProviderTitle      = [string]$Provider.Title
    $Task.ProviderNPI        = [string]$Provider.NPI
    $Task.ProviderAddress1   = [string]$Provider.Address1
    $Task.ProviderAddress2   = [string]$Provider.Address2
    $Task.ProviderCity       = [string]$Provider.City
    $Task.ProviderState      = [string]$Provider.State
    $Task.ProviderZip        = [string]$Provider.Zip
    $Task.ProviderLocationPhone = [string]$Provider.Phone
    $Task.ProviderStateLic   = [string]$Provider.StateLic
    $Task.ProviderSourceFile = [string]$script:DoctorMasterPath
    $Task.ProviderLocationName = (@($Task.ProviderFirstName,$Task.ProviderMiddleName,$Task.ProviderLastName,$Task.ProviderSuffix) | Where-Object { $_ }) -join ' '
    $Task.ProviderLocationAlias = ''
    $Task.ProviderLocationDisplay = '{0} (#{1})' -f $Task.ProviderLocationName,$Task.ProviderNumber
    $Task.ProviderLocationAddress = (@($Task.ProviderAddress1,$Task.ProviderAddress2,$Task.ProviderCity,$Task.ProviderState,$Task.ProviderZip) | Where-Object { $_ }) -join ', '
    $gridTasks.Items.Refresh()
    Update-TaskDetails
    Write-Activity ('Task {0}: DoctorMaster provider {1}; NPI {2}; Source {3}.' -f $Task.TaskID,$Task.ProviderLocationDisplay,$Task.ProviderNPI,(Split-Path -Leaf $script:DoctorMasterPath))
}

function Invoke-DoctorMasterLookup {
    param($Task,$DialogOwner)
    if (-not (Ensure-DoctorMasterLoaded)) { return $false }
    $user = Get-TaskUser -Task $Task
    $key = Get-DoctorMasterKey $user.SamAccountName
    if (-not $script:DoctorMasterIndex.ContainsKey($key)) {
        Write-Activity ('Task {0}: no DoctorMaster Number matches SamAccount {1}.' -f $Task.TaskID,$user.SamAccountName)
        $answer = [System.Windows.MessageBox]::Show($DialogOwner,
            ('No DoctorMaster Number matches SamAccount "{0}" in {1}. Select YES to load a different file, or NO to leave this task unchanged.' -f $user.SamAccountName,(Split-Path -Leaf $script:DoctorMasterPath)),
            'Provider Not Found','YesNo','Information')
        if ($answer -eq 'Yes') {
            $newPath = Select-DoctorMasterFile
            if ($newPath) {
                try { Import-DoctorMasterFile -Path $newPath }
                catch {
                    [System.Windows.MessageBox]::Show($DialogOwner,$_.Exception.Message,'DoctorMaster Import Error','OK','Error') | Out-Null
                    return $false
                }
            }
        }
        if (-not $script:DoctorMasterIndex.ContainsKey($key)) { return $false }
    }
    $rows = @($script:DoctorMasterIndex[$key].ToArray())
    $chosen = Show-DoctorMasterMatchDialog -Task $Task -Matches $rows -DialogOwner $DialogOwner
    if ($null -eq $chosen) { return $false }
    Set-TaskProviderLocation -Task $Task -Provider $chosen
    return $true
}

function Show-TaskLocationDialog {
    param($Task, [int]$Index, [int]$Total)
    $user = Get-TaskUser -Task $Task
    if ($null -eq $user) { return $false }
    [xml]$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Width="790" Height="460" MinWidth="680" MinHeight="410"
        WindowStartupLocation="CenterOwner" ShowInTaskbar="False"
        Background="#152237" Foreground="White">
    <DockPanel Margin="18">
        <TextBlock DockPanel.Dock="Top" x:Name="txtProgress" Foreground="#9FB5D0" FontSize="13" Margin="0,0,0,12"/>
        <StackPanel DockPanel.Dock="Bottom" Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,14,0,0">
            <Button x:Name="btnStop" Content="Stop" MinWidth="100" Padding="12,7" Margin="0,0,8,0"/>
            <Button x:Name="btnNext" Content="Next Task" MinWidth="110" Padding="12,7" IsDefault="True"/>
        </StackPanel>
        <StackPanel>
            <TextBlock FontSize="20" FontWeight="SemiBold" Text="Task &amp; User" Margin="0,0,0,12"/>
            <Grid>
                <Grid.ColumnDefinitions><ColumnDefinition Width="140"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
                <Grid.RowDefinitions>
                    <RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/>
                </Grid.RowDefinitions>
                <TextBlock Grid.Row="0" Text="Task ID" Margin="0,0,0,8"/>
                <TextBlock Grid.Row="1" Text="Display Name" Margin="0,0,0,8"/>
                <TextBlock Grid.Row="2" Text="SamAccount" Margin="0,0,0,8"/>
                <TextBlock Grid.Row="3" Text="Employee ID" Margin="0,0,0,8"/>
                <TextBlock Grid.Row="4" Text="Title" Margin="0,0,0,8"/>
                <TextBlock x:Name="valTask" Grid.Column="1" Grid.Row="0" FontWeight="SemiBold"/>
                <TextBlock x:Name="valName" Grid.Column="1" Grid.Row="1"/>
                <TextBlock x:Name="valSam" Grid.Column="1" Grid.Row="2"/>
                <TextBlock x:Name="valEmployee" Grid.Column="1" Grid.Row="3"/>
                <TextBlock x:Name="valTitle" Grid.Column="1" Grid.Row="4"/>
            </Grid>
            <Border BorderBrush="#455C79" BorderThickness="0,1,0,0" Margin="0,14,0,12"/>
            <StackPanel Orientation="Horizontal">
                <Button x:Name="btnClinical" Content="Clinical Location Lookup" MinWidth="220" Padding="12,9" Margin="0,0,12,0"/>
                <Button x:Name="btnProvider" Content="Provider Location Lookup" MinWidth="220" Padding="12,9"/>
            </StackPanel>
            <TextBlock x:Name="txtClinical" TextWrapping="Wrap" Margin="0,12,0,5"/>
            <TextBlock x:Name="txtProvider" TextWrapping="Wrap" Margin="0,0,0,6"/>
            <TextBlock Text="Select either lookup to change its assignment. Next Task preserves your choices." Foreground="#9FB5D0" TextWrapping="Wrap" Margin="0,12,0,0"/>
        </StackPanel>
    </DockPanel>
</Window>
'@
    $dlg = ConvertFrom-WpfXaml $xaml
    $dlg.Owner = $window
    $dlg.Topmost = $true
    $dlg.Title = 'Add Locations - Task {0}' -f $Task.TaskID
    $dlg.FindName('txtProgress').Text = 'Task {0} of {1}' -f $Index,$Total
    $dlg.FindName('valTask').Text = [string]$Task.TaskID
    $dlg.FindName('valName').Text = [string]$user.DisplayName
    $dlg.FindName('valSam').Text = [string]$user.SamAccountName
    $dlg.FindName('valEmployee').Text = [string]$user.EmployeeID
    $dlg.FindName('valTitle').Text = [string]$user.Title
    $clinicalText = $dlg.FindName('txtClinical')
    $providerText = $dlg.FindName('txtProvider')
    $clinicalText.Text = 'Clinical: ' + $(if ($Task.ClinicalLocationDisplay) { $Task.ClinicalLocationDisplay } else { '(not selected)' })
    $providerText.Text = 'Provider: ' + $(if ($Task.ProviderLocationDisplay) { $Task.ProviderLocationDisplay } else { '(not selected)' })
    $dlg.FindName('btnClinical').Add_Click({
        if ($script:Locations.Count -eq 0) {
            [System.Windows.MessageBox]::Show($dlg,'Clinical locations not loaded. Use Update Locations from the main window.','No Clinical Locations','OK','Warning') | Out-Null
            return
        }
        $selected = Show-LocationPicker -Title ('Clinical Location - Task {0}' -f $Task.TaskID) -Task $Task -DialogOwner $dlg
        if ($null -ne $selected) {
            Set-TaskClinicalLocation -Task $Task -Location $selected
            $clinicalText.Text = 'Clinical: ' + $Task.ClinicalLocationDisplay
        }
    })
    $dlg.FindName('btnProvider').Add_Click({
        if (Invoke-DoctorMasterLookup -Task $Task -DialogOwner $dlg) {
            $providerText.Text = 'Provider: ' + $Task.ProviderLocationDisplay + ' | NPI: ' + $Task.ProviderNPI
        }
    })
    $dlg.FindName('btnNext').Add_Click({ $dlg.DialogResult = $true })
    $dlg.FindName('btnStop').Add_Click({ $dlg.DialogResult = $false })
    return ($dlg.ShowDialog() -eq $true)
}

function Show-NotImplemented {
    param([string]$Feature)
    Write-Activity ('{0}: integration details are not configured yet.' -f $Feature)
    [System.Windows.MessageBox]::Show(
        $window,
        ('The "{0}" button is ready for its workflow, but the behavior and application endpoint have not yet been supplied.' -f $Feature),
        'Integration Placeholder', 'OK', 'Information'
    ) | Out-Null
}

$btnAddTasks.Add_Click({
    try {
        $entered = Show-TextPrompt -Title 'Add Task IDs' -Message 'Enter one Task ID, or multiple IDs separated by commas (or new lines):' -Multiline
        if ($null -ne $entered -and -not [string]::IsNullOrWhiteSpace($entered)) { Add-TaskIDs -InputText $entered }
    }
    catch { Write-Activity ('Add Tasks error: {0}' -f $_.Exception.Message) }
})

$btnAddUsers.Add_Click({
    try {
        if ($script:Tasks.Count -eq 0) {
            [System.Windows.MessageBox]::Show($window, 'Add at least one task before searching for users.', 'No Tasks', 'OK', 'Information') | Out-Null
            return
        }
        if (-not (Get-Command Get-ADUser -ErrorAction SilentlyContinue)) {
            try { Import-Module ActiveDirectory -ErrorAction Stop }
            catch {
                [System.Windows.MessageBox]::Show($window,
                    'The ActiveDirectory PowerShell module is unavailable. Install RSAT AD tools or run this on a workstation that has the module.',
                    'AD Module Missing', 'OK', 'Warning') | Out-Null
                Write-Activity 'Add Users: ActiveDirectory module missing.'
                return
            }
        }
        # Snapshot permits safe iteration even if tasks are changed later.
        foreach ($task in @($script:Tasks | Where-Object { $null -eq (Get-TaskUser -Task $_) })) {
            $message = 'Task {0}: enter a user identifier (SamAccountName, EmployeeID, email, name, etc.). Cancel stops the loop. Leave empty to skip.' -f $task.TaskID
            $entered = Show-TextPrompt -Title ('AD User for Task {0}' -f $task.TaskID) -Message $message -DefaultValue $task.EmolstUserName
            if ($null -eq $entered) { Write-Activity 'Add Users cancelled by operator.'; break }
            $entered = $entered.Trim()
            if (-not $entered) { Write-Activity ('Skipped task {0} (blank search).' -f $task.TaskID); continue }
            Add-AdUserForTask -Task $task -SearchTerm $entered
        }
        Update-Counters
        Update-WorkflowButtons
    }
    catch { Write-Activity ('Add Users error: {0}' -f $_.Exception.Message) }
})

$btnEditAliases.Add_Click({
    if ($script:Locations.Count -eq 0) { Write-Activity 'No locations loaded; use Update Locations.'; return }
    $null = Show-LocationPicker -Title 'Clinical Location Aliases' -AliasEditor
})
$btnRefreshLocations.Add_Click({
    if (-not (Test-Path -LiteralPath $script:UpdaterPath)) {
        [System.Windows.MessageBox]::Show($window,('Updater not found beside the GUI: ' + $script:UpdaterPath),'Missing Updater','OK','Warning') | Out-Null
        return
    }
    $decision = [System.Windows.MessageBox]::Show($window,
        'Refresh facilities from nyuhs.org? Existing Location aliases will be verified before overwriting. A .bak backup will be created. This may take a while.',
        'Update Clinical Locations','YesNo','Question')
    if ($decision -ne 'Yes') { return }
    try {
        $btnRefreshLocations.IsEnabled = $false
        Write-Activity 'Updating clinical locations from website...'
        # Save to local only. The master list may be refreshed separately with the updater.
        & $script:UpdaterPath -LocalPath $script:LocationsPath -SkipMaster *>&1 | ForEach-Object { Write-Activity ([string]$_) }
        Read-ClinicalLocations
    }
    catch {
        Write-Activity ('Location update failed: {0}' -f $_.Exception.Message)
        [System.Windows.MessageBox]::Show($window,$_.Exception.Message,'Update Failed','OK','Error') | Out-Null
    }
    finally { $btnRefreshLocations.IsEnabled = $true }
})
$btnAddLocations.Add_Click({
    try {
        Update-WorkflowButtons
        if (-not $btnAddLocations.IsEnabled) {
            [System.Windows.MessageBox]::Show($window,'First add tasks and assign an Active Directory user to every task.','Complete Add Users First','OK','Information') | Out-Null
            return
        }
        $index = 0
        foreach ($task in @($script:Tasks)) {
            $index++
            if (-not (Show-TaskLocationDialog -Task $task -Index $index -Total $script:Tasks.Count)) {
                Write-Activity ('Add Locations stopped at Task {0}.' -f $task.TaskID)
                break
            }
        }
    }
    catch {
        Write-Activity ('Add Locations error: {0}' -f $_.Exception.Message)
        [System.Windows.MessageBox]::Show($window,$_.Exception.Message,'Location Workflow Error','OK','Error') | Out-Null
    }
})

foreach ($config in @(
    @{ Control = $btnAddSSO; Name = 'Add SSO' },
    @{ Control = $btnLaunchIvanti; Name = 'Launch Ivanti' },
    @{ Control = $btnLaunchDrMaster; Name = 'Launch Dr Master' },
    @{ Control = $btnLaunchEMOLST; Name = 'Launch EMOLST' },
    @{ Control = $btnLoadEPICUser; Name = 'Load EPIC User' },
    @{ Control = $btnLoadEMOLSTUser; Name = 'Load EMOLST User' },
    @{ Control = $btnLoadDrMasterUser; Name = 'Load Dr Master User' },
    @{ Control = $btnLoadIvantiSummary; Name = 'Load Ivanti Summary' }
)) {
    $feature = [string]$config.Name
    $button = $config.Control
    # Use a dedicated closure to avoid every handler taking the last loop value.
    $button.Add_Click(({ Show-NotImplemented -Feature $feature }).GetNewClosure())
}

$gridTasks.Add_SelectionChanged({ Update-TaskDetails })
Update-Counters
Update-WorkflowButtons
Read-ClinicalLocations
Write-Activity 'Ready. Workflow: Add Tasks -> Add Users -> Add Locations.'
[void]$window.ShowDialog()
