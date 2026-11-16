#requires -Version 5.1
<#
.SYNOPSIS
    Clinical Task Workbench - PowerShell 5.1 / WPF
.DESCRIPTION
    Topmost GUI for staging Task IDs, associating AD users, and later
    integrating Clinical Locations, Professional Locations, SSO, Ivanti,
    Doctor Master, EPIC, and EMOLST.

    Includes local clinical-location aliases, task assignments, and safe refresh.
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
    'ProviderLocationPhone'
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
        $records = @(ConvertFrom-Json -InputObject $raw -ErrorAction Stop)
        foreach ($r in $records) {
            if ($null -eq $r -or [string]::IsNullOrWhiteSpace([string]$r.Name)) { continue }
            $script:Locations.Add([pscustomobject]@{
                Name=[string]$r.Name; Location=[string]$r.Location; Phone=[string]$r.Phone
                Address1=[string]$r.Address1; Address2=[string]$r.Address2
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
        $json = ConvertTo-Json -InputObject @($script:Locations) -Depth 8
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
        Width="1020" Height="580" MinWidth="740" MinHeight="370"
        WindowStartupLocation="CenterOwner" Background="#152237" Foreground="White" ShowInTaskbar="False">
    <DockPanel Margin="12">
        <TextBlock x:Name="lblIntro" DockPanel.Dock="Top" TextWrapping="Wrap" Margin="0,0,0,8"/>
        <TextBox x:Name="txtSearch" DockPanel.Dock="Top" Margin="0,0,0,9" Padding="8,6"
                 Background="#F0F5FB" Foreground="#142337" ToolTip="Search name, alias, city, or address"/>
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
                <DataGridTextColumn Header="Address" Binding="{Binding Address1}" Width="220"/>
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
    $btnEditAliases.IsEnabled = $complete
    $btnRefreshLocations.IsEnabled = $complete
    # Steps following Add Users cannot run until each task has an assigned AD user.
    foreach ($button in @($btnAddSSO,$btnLaunchIvanti,$btnLaunchDrMaster,$btnLaunchEMOLST,
                           $btnLoadEPICUser,$btnLoadEMOLSTUser,$btnLoadDrMasterUser,$btnLoadIvantiSummary)) {
        $button.IsEnabled = $complete
    }
}

function Set-TaskProviderLocation {
    param($Task,$Location)
    $Task.ProviderLocationName = [string]$Location.Name
    $Task.ProviderLocationAlias = [string]$Location.Location
    $Task.ProviderLocationDisplay = if ([string]::IsNullOrWhiteSpace([string]$Location.Location)) { [string]$Location.Name } else { '{0} ({1})' -f $Location.Location,$Location.Name }
    $Task.ProviderLocationAddress = (@([string]$Location.Address1,[string]$Location.Address2,[string]$Location.Locality,[string]$Location.State,[string]$Location.Zip) | Where-Object { $_ }) -join ', '
    $Task.ProviderLocationPhone = [string]$Location.Phone
    $gridTasks.Items.Refresh()
    Update-TaskDetails
    Write-Activity ('Task {0}: provider location set to {1}.' -f $Task.TaskID,$Task.ProviderLocationDisplay)
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
        $selected = Show-LocationPicker -Title ('Clinical Location - Task {0}' -f $Task.TaskID) -Task $Task -DialogOwner $dlg
        if ($null -ne $selected) {
            Set-TaskClinicalLocation -Task $Task -Location $selected
            $clinicalText.Text = 'Clinical: ' + $Task.ClinicalLocationDisplay
        }
    })
    $dlg.FindName('btnProvider').Add_Click({
        $selected = Show-LocationPicker -Title ('Provider Location - Task {0}' -f $Task.TaskID) -Task $Task -DialogOwner $dlg
        if ($null -ne $selected) {
            Set-TaskProviderLocation -Task $Task -Location $selected
            $providerText.Text = 'Provider: ' + $Task.ProviderLocationDisplay
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
        'Refresh facilities from nyuhs.org? Existing Location aliases will be preserved. A .bak backup will be created. This may take a while.',
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
        if ($script:Locations.Count -eq 0) {
            [System.Windows.MessageBox]::Show($window,'No locations loaded. Check local JSON or use Update Locations.','No Locations','OK','Warning') | Out-Null
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
