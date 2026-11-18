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
                <Button x:Name="btnClearTasks" Content="Clear Tasks" Background="#7D4242"/>
                <Button x:Name="btnAddUsers" Content="Add Users" Background="#17657A"/>
                <Button x:Name="btnAddLocations" Content="Add Locations" Background="#17657A"/>
                <Button x:Name="btnAddSSO" Content="Add SSO"/>
                <Button x:Name="btnCreateEMOLST" Content="Create EMOLST Data" Background="#17657A"/>
                <Button x:Name="btnLaunchIvanti" Content="Launch Ivanti"/>
                <Button x:Name="btnLaunchDrMaster" Content="Launch Dr Master"/>
                <Button x:Name="btnLaunchEMOLST" Content="Launch EMOLST"/>
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
                    <DataGrid x:Name="gridTasks" Grid.Column="0" CanUserSortColumns="False">
                        <!-- Completed EMOLST summaries are visually distinguishable, even after selection changes. -->
                        <DataGrid.RowStyle>
                            <Style TargetType="DataGridRow" BasedOn="{StaticResource {x:Type DataGridRow}}">
                                <Style.Triggers>
                                    <DataTrigger Binding="{Binding EmolstSummaryCopied}" Value="True">
                                        <Setter Property="Background" Value="#225941"/>
                                        <Setter Property="Foreground" Value="#F2FFF7"/>
                                    </DataTrigger>
                                    <MultiDataTrigger>
                                        <MultiDataTrigger.Conditions>
                                            <Condition Binding="{Binding EmolstSummaryCopied}" Value="True"/>
                                            <Condition Binding="{Binding RelativeSource={RelativeSource Self}, Path=IsSelected}" Value="True"/>
                                        </MultiDataTrigger.Conditions>
                                        <Setter Property="Background" Value="#347C60"/>
                                        <Setter Property="Foreground" Value="White"/>
                                    </MultiDataTrigger>
                                </Style.Triggers>
                            </Style>
                        </DataGrid.RowStyle>
                        <DataGrid.Columns>
                            <DataGridTextColumn Header="Task ID" Binding="{Binding TaskID}" Width="110"/>
                            <DataGridTextColumn Header="Task Type" Binding="{Binding TaskType}" Width="125"/>
                            <DataGridTextColumn Header="Task Note" Binding="{Binding TaskNote}" Width="*"/>
                            <DataGridTextColumn Header="Clinical Location" Binding="{Binding ClinicalLocationDisplay}" Width="170"/>
                            <DataGridTextColumn Header="Provider Location" Binding="{Binding ProviderLocationDisplay}" Width="170"/>
                            <DataGridTextColumn Header="SSO" Binding="{Binding EmolstSSOUsername}" Width="95"/>
                            <DataGridTextColumn Header="EMOLST User" Binding="{Binding EmolstUserName}" Width="140"/>
                        </DataGrid.Columns>
                    </DataGrid>
                    <GridSplitter Grid.Column="1" Width="7" HorizontalAlignment="Stretch" Background="#354B68"/>
                    <DataGrid x:Name="gridUsers" Grid.Column="2" IsReadOnly="False" CanUserSortColumns="False">
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
    'btnAddTasks','btnClearTasks','btnAddUsers','btnAddLocations','btnAddSSO','btnCreateEMOLST',
    'btnLaunchIvanti','btnLaunchDrMaster','btnLaunchEMOLST',
    'btnLoadIvantiSummary',
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
# Favorites are independent of the refreshable facility catalog.
$script:FavoritesPath = Join-Path $env:LOCALAPPDATA 'Get-UHSLocations\ClinicalLocationFavorites.json'
$script:ClinicalFavorites = [System.Collections.ObjectModel.ObservableCollection[object]]::new()

$script:UpdaterPath = Join-Path $PSScriptRoot 'Update-UHSLocations.ps1'
# DoctorMaster is deliberately loaded once per application session, on first use.
$script:DoctorMasterPath = $null
$script:DoctorMasterRecords = @()
$script:DoctorMasterIndex = @{}
$script:DoctorMasterLoadedAt = $null
$gridTasks.ItemsSource = $script:Tasks
$gridUsers.ItemsSource = $script:Users
$gridTaskProperties.ItemsSource = $script:TaskProperties

# Keep both collections in the task-entry order. Do not sort Task IDs as text:
# e.g. 2 would otherwise appear after 10. A task without an AD match
# has no corresponding Users row, but all linked rows retain task order.
$script:SyncingGridSelection = $false
function Sync-UserOrderToTasks {
    $wasSyncing = $script:SyncingGridSelection
    $script:SyncingGridSelection = $true
    try {
        $position = 0
        foreach ($taskItem in $script:Tasks) {
            $taskId = [string]$taskItem.TaskID
            foreach ($userItem in @($script:Users | Where-Object { [string]$_.TaskID -eq $taskId })) {
                $oldIndex = $script:Users.IndexOf($userItem)
                if ($oldIndex -ge 0 -and $oldIndex -ne $position) {
                    $script:Users.Move($oldIndex, $position)
                }
                $position++
            }
        }
    }
    finally { $script:SyncingGridSelection = $wasSyncing }
}

function Sync-SelectionFromTask {
    if ($script:SyncingGridSelection) { return }
    $script:SyncingGridSelection = $true
    try {
        $taskItem = $gridTasks.SelectedItem
        $matchingUser = $null
        if ($null -ne $taskItem) {
            $matchingUser = @($script:Users | Where-Object {
                [string]$_.TaskID -eq [string]$taskItem.TaskID
            } | Select-Object -First 1)
            if ($matchingUser.Count -gt 0) { $matchingUser = $matchingUser[0] }
            else { $matchingUser = $null }
        }
        $gridUsers.SelectedItem = $matchingUser
        if ($null -ne $matchingUser) { $gridUsers.ScrollIntoView($matchingUser) }
    }
    finally { $script:SyncingGridSelection = $false }
}

function Sync-SelectionFromUser {
    if ($script:SyncingGridSelection) { return }
    $script:SyncingGridSelection = $true
    try {
        $userItem = $gridUsers.SelectedItem
        $matchingTask = $null
        if ($null -ne $userItem) {
            $matched = @($script:Tasks | Where-Object {
                [string]$_.TaskID -eq [string]$userItem.TaskID
            } | Select-Object -First 1)
            if ($matched.Count -gt 0) { $matchingTask = $matched[0] }
        }
        $gridTasks.SelectedItem = $matchingTask
        if ($null -ne $matchingTask) { $gridTasks.ScrollIntoView($matchingTask) }
        Update-TaskDetails
    }
    finally { $script:SyncingGridSelection = $false }
}

# All identity columns stay read-only; only the new Status column is editable.
foreach ($column in $gridUsers.Columns) { $column.IsReadOnly = $true }
$statusColumn = [System.Windows.Controls.DataGridComboBoxColumn]::new()
$statusColumn.Header = 'Status'
$statusColumn.ItemsSource = @('To Do','Access Granted','Updated Profile','Re-Enrolled User')
$statusColumn.SelectedItemBinding = [System.Windows.Data.Binding]::new('Status')
$statusColumn.SelectedItemBinding.Mode = [System.Windows.Data.BindingMode]::TwoWay
$statusColumn.SelectedItemBinding.UpdateSourceTrigger = [System.Windows.Data.UpdateSourceTrigger]::PropertyChanged
$statusColumn.Width = [System.Windows.Controls.DataGridLength]::new(165)
$statusColumn.IsReadOnly = $false
[void]$gridUsers.Columns.Add($statusColumn)


$script:TaskFieldNames = @(
    'TaskID','TaskType','TaskNote','EmolstUserName','EmolstAdminRole',
    'EmolstClinicalRole','EmolstTitle','EmolstPrefix','EmolstFirstName',
    'EmolstMiddleName','EmolstLastName','EmolstSuffix','EmolstStreet',
    'EmolstCity','EmolstState','EmolstZip','EmolstPhone','EmolstEmail',
    'EmolstNPI','EmolstProvStateLic','EmolstSSOUsername','EmolstIdentityProvider',
    'ClinicalLocationName','ClinicalLocationAlias','ClinicalLocationDisplay','ClinicalLocationAddress',
    'ClinicalLocationPhone','ClinicalAddress1','ClinicalAddress2','ClinicalCity','ClinicalState','ClinicalZip',
    'ProviderLocationName','ProviderLocationAlias','ProviderLocationDisplay','ProviderLocationAddress',
    'ProviderLocationPhone',
    'ProviderNumber','ProviderLastName','ProviderFirstName','ProviderMiddleName',
    'ProviderSuffix','ProviderTitle','ProviderNPI','ProviderAddress1','ProviderAddress2',
    'ProviderCity','ProviderState','ProviderZip','ProviderStateLic','ProviderSourceFile',
    'EmolstReviewApplied','EmolstSummaryCopied','EmolstSummaryFile'
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
    $properties['EmolstReviewApplied'] = $false
    $properties['EmolstSummaryCopied'] = $false
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
    Sync-UserOrderToTasks
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
        Status = 'To Do'
        ADObject = $user
    }
    $script:Users.Add($record)
    Sync-UserOrderToTasks
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
function Read-ClinicalFavorites {
    $script:ClinicalFavorites.Clear()
    if (-not (Test-Path -LiteralPath $script:FavoritesPath -PathType Leaf)) { return }
    try {
        $data = ConvertFrom-Json -InputObject ([System.IO.File]::ReadAllText($script:FavoritesPath)) -ErrorAction Stop
        if ($null -ne $data -and $null -ne $data.PSObject.Properties['SyncRoot']) {
            $data = $data.SyncRoot
        }
        foreach ($f in @($data)) {
            if ($null -eq $f -or [string]::IsNullOrWhiteSpace([string]$f.Label) -or
                [string]::IsNullOrWhiteSpace([string]$f.Name)) { continue }
            $script:ClinicalFavorites.Add([pscustomobject]@{
                Label=[string]$f.Label; Name=[string]$f.Name
                Address1=[string]$f.Address1; Locality=[string]$f.Locality
                Zip=[string]$f.Zip
            })
        }
        Write-Activity ('Loaded {0} clinical location favorites.' -f $script:ClinicalFavorites.Count)
    }
    catch {
        Write-Activity ('Unable to read clinical location favorites: {0}' -f $_.Exception.Message)
        [System.Windows.MessageBox]::Show($window,
            ('Cannot read favorites file. It was not modified. ' + $_.Exception.Message),
            'Favorites Load Error','OK','Warning') | Out-Null
    }
}
function Save-ClinicalFavorites {
    $folder = Split-Path -Parent $script:FavoritesPath
    if (-not (Test-Path -LiteralPath $folder)) { $null = New-Item -ItemType Directory -Path $folder -Force }
    $tmp = Join-Path $folder ('.favorites-' + [guid]::NewGuid().ToString('N') + '.tmp')
    try {
        $rows = @($script:ClinicalFavorites | ForEach-Object {
            [pscustomobject][ordered]@{
                Label=[string]$_.Label; Name=[string]$_.Name
                Address1=[string]$_.Address1; Locality=[string]$_.Locality; Zip=[string]$_.Zip
            }
        })
        # -InputObject forces a JSON array even for zero or one favorites.
        $json = ConvertTo-Json -InputObject $rows -Depth 6
        [System.IO.File]::WriteAllText($tmp,$json,[System.Text.UTF8Encoding]::new($true))
        if (Test-Path -LiteralPath $script:FavoritesPath) {
            Copy-Item -LiteralPath $script:FavoritesPath -Destination ($script:FavoritesPath + '.bak') -Force
        }
        Move-Item -LiteralPath $tmp -Destination $script:FavoritesPath -Force
    }
    finally {
        if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue }
    }
}
function Resolve-ClinicalFavorite {
    param($Favorite)
    if ($null -eq $Favorite) { return $null }
    # Exact facility name is mandatory. Never match on address alone: several
    # UHS departments can legitimately share the same street address.
    $matches = @($script:Locations | Where-Object {
        [string]$_.Name -ieq [string]$Favorite.Name
    })
    if ($matches.Count -eq 1) { return $matches[0] }
    if ($matches.Count -gt 1) {
        $matches = @($matches | Where-Object {
            [string]$_.Address1 -ieq [string]$Favorite.Address1 -and
            [string]$_.Locality -ieq [string]$Favorite.Locality -and
            [string]$_.Zip -ieq [string]$Favorite.Zip
        })
        if ($matches.Count -eq 1) { return $matches[0] }
    }
    return $null
}
function Show-ClinicalFavoritesManager {
    param($DialogOwner = $window)
    [xml]$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Manage Clinical Location Favorites" Width="660" Height="420"
        MinWidth="550" MinHeight="310" WindowStartupLocation="CenterOwner"
        ShowInTaskbar="False" Background="#152237" Foreground="#E6EDF7">
    <DockPanel Margin="16">
        <TextBlock DockPanel.Dock="Top" Text="Add a shortcut for a specific facility, then rename or remove it here. Favorites persist between sessions."
                   TextWrapping="Wrap" Margin="0,0,0,12"/>
        <StackPanel DockPanel.Dock="Bottom" Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,12,0,0">
            <Button x:Name="btnAdd" Content="Add Favorite" Padding="12,7" Margin="0,0,8,0"/>
            <Button x:Name="btnRename" Content="Rename Button" Padding="12,7" Margin="0,0,8,0"/>
            <Button x:Name="btnRemove" Content="Remove" Padding="12,7" Margin="0,0,8,0"/>
            <Button x:Name="btnClose" Content="Done" Padding="12,7" MinWidth="70"/>
        </StackPanel>
        <DataGrid x:Name="gridFavorites" AutoGenerateColumns="False" IsReadOnly="True" CanUserAddRows="False"
                  SelectionMode="Single" Background="#EDF3FA" Foreground="#122039"
                  RowBackground="#EDF3FA" AlternatingRowBackground="#DCE6F4">
            <DataGrid.Columns>
                <DataGridTextColumn Header="Button Name" Binding="{Binding Label}" Width="140"/>
                <DataGridTextColumn Header="Clinical Facility" Binding="{Binding Name}" Width="*"/>
                <DataGridTextColumn Header="Address" Binding="{Binding Address1}" Width="185"/>
            </DataGrid.Columns>
        </DataGrid>
    </DockPanel>
</Window>
'@
    $dlg = ConvertFrom-WpfXaml $xaml
    $dlg.Owner = $DialogOwner
    $dlg.Topmost = $true
    $grid = $dlg.FindName('gridFavorites')
    $grid.ItemsSource = $script:ClinicalFavorites
    $dlg.FindName('btnAdd').Add_Click({
        if ($script:Locations.Count -eq 0) {
            [System.Windows.MessageBox]::Show($dlg,'Load clinical locations before adding a favorite.','No Locations','OK','Warning') | Out-Null
            return
        }
        $loc = Show-LocationPicker -Title 'Choose a Clinical Location for Favorite' -DialogOwner $dlg
        if ($null -eq $loc) { return }
        $suggested = if (-not [string]::IsNullOrWhiteSpace([string]$loc.Location)) { [string]$loc.Location } else { [string]$loc.Name }
        $label = Show-TextPrompt -Title 'New Favorite' -Message 'Enter the text for this favorite button:' -DefaultValue $suggested -DialogOwner $dlg
        if ($null -eq $label -or [string]::IsNullOrWhiteSpace($label)) { return }
        $label = $label.Trim()
        if (@($script:ClinicalFavorites | Where-Object { [string]$_.Label -ieq $label }).Count -gt 0) {
            [System.Windows.MessageBox]::Show($dlg,'A favorite already has that button name.','Duplicate Name','OK','Warning') | Out-Null
            return
        }
        $fav = [pscustomobject]@{ Label=$label; Name=[string]$loc.Name; Address1=[string]$loc.Address1;
                                 Locality=[string]$loc.Locality; Zip=[string]$loc.Zip }
        $script:ClinicalFavorites.Add($fav)
        try { Save-ClinicalFavorites; Write-Activity ('Added clinical favorite {0} -> {1}.' -f $label,$loc.Name) }
        catch {
            $script:ClinicalFavorites.Remove($fav)
            [System.Windows.MessageBox]::Show($dlg,$_.Exception.Message,'Save Favorites Failed','OK','Error') | Out-Null
        }
    })
    $dlg.FindName('btnRename').Add_Click({
        $fav = $grid.SelectedItem
        if ($null -eq $fav) { return }
        $name = Show-TextPrompt -Title 'Rename Favorite' -Message 'Enter the new button label:' -DefaultValue $fav.Label -DialogOwner $dlg
        if ($null -eq $name -or [string]::IsNullOrWhiteSpace($name)) { return }
        $name = $name.Trim()
        if (@($script:ClinicalFavorites | Where-Object { $_ -ne $fav -and [string]$_.Label -ieq $name }).Count -gt 0) {
            [System.Windows.MessageBox]::Show($dlg,'A favorite already has that name.','Duplicate Name','OK','Warning') | Out-Null
            return
        }
        $before = $fav.Label
        $fav.Label = $name
        try { Save-ClinicalFavorites; $grid.Items.Refresh(); Write-Activity ('Renamed favorite {0} to {1}.' -f $before,$name) }
        catch {
            $fav.Label = $before
            [System.Windows.MessageBox]::Show($dlg,$_.Exception.Message,'Save Favorites Failed','OK','Error') | Out-Null
        }
    })
    $dlg.FindName('btnRemove').Add_Click({
        $fav = $grid.SelectedItem
        if ($null -eq $fav) { return }
        if ([System.Windows.MessageBox]::Show($dlg,('Remove favorite "{0}"? The clinical facility itself will not be deleted.' -f $fav.Label),
            'Remove Favorite','YesNo','Question') -ne 'Yes') { return }
        $index = $script:ClinicalFavorites.IndexOf($fav)
        $script:ClinicalFavorites.Remove($fav)
        try { Save-ClinicalFavorites; Write-Activity ('Removed clinical favorite {0}.' -f $fav.Label) }
        catch {
            $script:ClinicalFavorites.Insert($index,$fav)
            [System.Windows.MessageBox]::Show($dlg,$_.Exception.Message,'Save Favorites Failed','OK','Error') | Out-Null
        }
    })
    $dlg.FindName('btnClose').Add_Click({ $dlg.Close() })
    $dlg.ShowDialog() | Out-Null
}

function Set-TaskClinicalLocation {
    param($Task,$Location)
    $Task.ClinicalLocationName = [string]$Location.Name
    $Task.ClinicalLocationAlias = [string]$Location.Location
    $Task.ClinicalLocationDisplay = if ([string]::IsNullOrWhiteSpace([string]$Location.Location)) { [string]$Location.Name } else { '{0} ({1})' -f $Location.Location,$Location.Name }
    $Task.ClinicalLocationAddress = (@([string]$Location.Address1,[string]$Location.Address2,[string]$Location.Locality,[string]$Location.State,[string]$Location.Zip) | Where-Object { $_ }) -join ', '
    $Task.ClinicalLocationPhone = [string]$Location.Phone
    $Task.ClinicalAddress1 = [string]$Location.Address1
    $Task.ClinicalAddress2 = [string]$Location.Address2
    $Task.ClinicalCity = [string]$Location.Locality
    $Task.ClinicalState = [string]$Location.State
    $Task.ClinicalZip = [string]$Location.Zip
    $gridTasks.Items.Refresh()
    Update-TaskDetails
    Write-Activity ('Task {0}: clinical location set to {1}.' -f $Task.TaskID,$Task.ClinicalLocationDisplay)
    Update-WorkflowButtons
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
    $usersComplete = $hasTasks
    if ($usersComplete) {
        foreach ($task in $script:Tasks) {
            if ($null -eq (Get-TaskUser -Task $task)) { $usersComplete = $false; break }
        }
    }
    $btnAddLocations.IsEnabled = $usersComplete
    # Maintain clinical locations independently of tasks and AD users.
    $btnEditAliases.IsEnabled = $true
    $btnRefreshLocations.IsEnabled = $true

    # A task may require a clinical location OR a DoctorMaster provider record.
    # SSO unlocks once each task has an AD user and at least one location assignment.
    $locationsComplete = $usersComplete
    if ($locationsComplete) {
        foreach ($task in $script:Tasks) {
            $hasClinical = -not [string]::IsNullOrWhiteSpace([string]$task.ClinicalLocationName)
            $hasProvider = -not [string]::IsNullOrWhiteSpace([string]$task.ProviderNumber)
            if (-not ($hasClinical -or $hasProvider)) {
                $locationsComplete = $false
                break
            }
        }
    }
    $btnAddSSO.IsEnabled = $locationsComplete
    $btnAddSSO.ToolTip = if ($locationsComplete) {
        'Enter a 1-8 digit SSO identifier for each task.'
    } else {
        'First assign an AD user and at least one Clinical OR Provider location to every task.'
    }

    $ssoComplete = $locationsComplete
    if ($ssoComplete) {
        foreach ($task in $script:Tasks) {
            if ([string]$task.EmolstSSOUsername -cnotmatch '^[0-9]{1,8}$') {
                $ssoComplete = $false
                break
            }
        }
    }
    $btnCreateEMOLST.IsEnabled = $ssoComplete
    $btnCreateEMOLST.ToolTip = if ($ssoComplete) {
        'Build and review EMOLST records for every task.'
    } else {
        'Complete Add Tasks, Add Users, Add Locations, and 1-8 digit SSO for every task first.'
    }

    # Existing application placeholders retain their previous user-assignment gate.
    foreach ($button in @($btnLaunchIvanti,$btnLaunchDrMaster,$btnLaunchEMOLST,
                           $btnLoadIvantiSummary)) {
        $button.IsEnabled = $usersComplete
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
    Update-WorkflowButtons
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
        Width="790" Height="535" MinWidth="680" MinHeight="470"
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
            <Border Background="#203451" BorderBrush="#3B5471" BorderThickness="1" CornerRadius="5" Padding="10" Margin="0,12,0,5">
                <StackPanel>
                    <DockPanel Margin="0,0,0,7">
                        <Button x:Name="btnManageFavorites" DockPanel.Dock="Right" Content="Manage Favorites..." Padding="9,4" MinHeight="28" Margin="8,0,0,0"/>
                        <TextBlock Text="Clinical Location Favorites" FontWeight="SemiBold" VerticalAlignment="Center"/>
                    </DockPanel>
                    <ScrollViewer VerticalScrollBarVisibility="Auto" MaxHeight="100">
                        <ItemsControl x:Name="itemsFavorites">
                            <ItemsControl.ItemsPanel>
                                <ItemsPanelTemplate><WrapPanel/></ItemsPanelTemplate>
                            </ItemsControl.ItemsPanel>
                            <ItemsControl.ItemTemplate>
                                <DataTemplate>
                                    <Button Content="{Binding Label}" Tag="{Binding}"
                                            MinWidth="70" Padding="12,6" Margin="0,0,8,7"
                                            Background="#17657A" Foreground="White"
                                            ToolTip="{Binding Name}"/>
                                </DataTemplate>
                            </ItemsControl.ItemTemplate>
                        </ItemsControl>
                    </ScrollViewer>
                    <TextBlock x:Name="txtFavoritesEmpty" Text="No favorites yet. Click Manage Favorites to add a button." Foreground="#9FB5D0"/>
                </StackPanel>
            </Border>
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
    # Bind favorites directly to an ObservableCollection. WPF updates buttons
    # automatically when favorites are added, renamed or removed.
    $favoritesItems = $dlg.FindName('itemsFavorites')
    $emptyFavorites = $dlg.FindName('txtFavoritesEmpty')
    $favoritesItems.ItemsSource = $script:ClinicalFavorites

    $showFavoritesEmpty = {
        $emptyFavorites.Visibility = if ($script:ClinicalFavorites.Count -eq 0) {
            [System.Windows.Visibility]::Visible
        } else {
            [System.Windows.Visibility]::Collapsed
        }
    }.GetNewClosure()
    & $showFavoritesEmpty

    # Event delegation handles all dynamically generated favorite buttons.
    # No button-specific WPF handlers need to be rebuilt after editing.
    $favoriteClicked = [System.Windows.RoutedEventHandler]{
        param($sender, $eventArgs)
        $source = $eventArgs.OriginalSource
        if ($source -isnot [System.Windows.Controls.Button]) { return }
        $fav = $source.Tag
        if ($null -eq $fav) { return }
        $loc = Resolve-ClinicalFavorite -Favorite $fav
        if ($null -eq $loc) {
            [System.Windows.MessageBox]::Show($dlg,
                ('Favorite "{0}" could not be uniquely matched to a current clinical facility. Open Manage Favorites and reselect it.' -f $fav.Label),
                'Favorite Not Found','OK','Warning') | Out-Null
            return
        }
        Set-TaskClinicalLocation -Task $Task -Location $loc
        $clinicalText.Text = 'Clinical: ' + $Task.ClinicalLocationDisplay
        $eventArgs.Handled = $true
    }.GetNewClosure()
    $favoritesItems.AddHandler([System.Windows.Controls.Primitives.ButtonBase]::ClickEvent, $favoriteClicked)

    $dlg.FindName('btnManageFavorites').Add_Click({
        Show-ClinicalFavoritesManager -DialogOwner $dlg
        # Re-read persisted favorites after the manager closes so the current
        # window shows exactly what was committed to disk.
        Read-ClinicalFavorites
        & $showFavoritesEmpty
    }.GetNewClosure())
    $dlg.FindName('btnProvider').Add_Click({
        if (Invoke-DoctorMasterLookup -Task $Task -DialogOwner $dlg) {
            $providerText.Text = 'Provider: ' + $Task.ProviderLocationDisplay + ' | NPI: ' + $Task.ProviderNPI
        }
    })
    $dlg.FindName('btnNext').Add_Click({ $dlg.DialogResult = $true })
    $dlg.FindName('btnStop').Add_Click({ $dlg.DialogResult = $false })
    return ($dlg.ShowDialog() -eq $true)
}

function Show-TaskSSODialog {
    param($Task,[int]$Index,[int]$Total)
    $user = Get-TaskUser -Task $Task
    [xml]$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Add SSO" Width="540" Height="365" MinWidth="460" MinHeight="340"
        Background="#152237" Foreground="#E6EDF7" ShowInTaskbar="False"
        WindowStartupLocation="CenterOwner" ResizeMode="CanResizeWithGrip">
    <DockPanel Margin="18">
        <StackPanel DockPanel.Dock="Bottom" Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,12,0,0">
            <Button x:Name="btnCancel" Content="Cancel / Stop" MinWidth="115" Margin="0,0,8,0" Padding="10,7"/>
            <Button x:Name="btnSkip" Content="Skip Task" MinWidth="100" Margin="0,0,8,0" Padding="10,7"/>
            <Button x:Name="btnSave" Content="Save / Next" IsDefault="True" MinWidth="110" Padding="10,7"/>
        </StackPanel>
        <StackPanel>
            <TextBlock x:Name="txtProgress" Foreground="#A9BCD4" FontSize="12" Margin="0,0,0,12"/>
            <TextBlock x:Name="txtTask" FontSize="19" FontWeight="SemiBold" Margin="0,0,0,7"/>
            <TextBlock x:Name="txtUser" TextWrapping="Wrap" Margin="0,0,0,4"/>
            <TextBlock x:Name="txtSam" Foreground="#B9CDE4" Margin="0,0,0,13"/>
            <TextBlock Text="SSO number (1 to 8 digits)" FontWeight="SemiBold"/>
            <TextBox x:Name="txtSSO" MaxLength="8" Margin="0,6,0,5" Padding="8,7"
                     FontSize="17" Background="#F5F8FD" Foreground="#172437"/>
            <TextBlock Text="Digits only. Leading zeros are preserved. Skip keeps the current value."
                       Foreground="#A9BCD4" TextWrapping="Wrap" Margin="0,3,0,0"/>
            <TextBlock x:Name="txtError" Foreground="#FF9F9F" TextWrapping="Wrap" Margin="0,8,0,0"/>
        </StackPanel>
    </DockPanel>
</Window>
'@
    $dlg = ConvertFrom-WpfXaml $xaml
    $dlg.Owner = $window
    $dlg.Topmost = $true
    $dlg.FindName('txtProgress').Text = 'Task {0} of {1}' -f $Index,$Total
    $dlg.FindName('txtTask').Text = 'Task ID: ' + [string]$Task.TaskID
    $dlg.FindName('txtUser').Text = 'User: ' + [string]$user.DisplayName
    $dlg.FindName('txtSam').Text = 'SamAccount: ' + [string]$user.SamAccountName
    $entry = $dlg.FindName('txtSSO')
    $entry.Text = [string]$Task.EmolstSSOUsername
    $errorLabel = $dlg.FindName('txtError')
    # Validate the final text, including pasted values, before saving.
    $dlg.FindName('btnSave').Add_Click({
        $candidate = $entry.Text.Trim()
        if ($candidate -cnotmatch '^[0-9]{1,8}$') {
            $errorLabel.Text = 'Enter 1 to 8 digits (0-9), with no spaces or other characters.'
            $entry.Focus() | Out-Null
            return
        }
        $dlg.Tag = [pscustomobject]@{ Action = 'Save'; Value = $candidate }
        $dlg.DialogResult = $true
    })
    $dlg.FindName('btnSkip').Add_Click({
        $dlg.Tag = [pscustomobject]@{ Action = 'Skip'; Value = '' }
        $dlg.DialogResult = $true
    })
    $dlg.FindName('btnCancel').Add_Click({ $dlg.DialogResult = $false })
    # Copy this task's SamAccount to the clipboard when its SSO dialog appears.
    # ContentRendered runs for each task, including after Save/Next or Skip Task.
    $samToCopy = [string]$user.SamAccountName
    $dlg.Add_ContentRendered({
        try {
            if (-not [string]::IsNullOrWhiteSpace($samToCopy)) {
                [System.Windows.Clipboard]::SetText($samToCopy)
            }
        }
        catch {
            $errorLabel.Text = 'Could not copy SamAccount to clipboard: ' + $_.Exception.Message
        }
        [void]$entry.Focus()
        $entry.SelectAll()
    })
    if ($dlg.ShowDialog() -eq $true) { return $dlg.Tag }
    return [pscustomobject]@{ Action = 'Stop'; Value = '' }
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

# Clear completed tasks safely, allowing the user to retain tasks without a saved summary.
$btnClearTasks.Add_Click({
    try {
        if ($script:Tasks.Count -eq 0) {
            [System.Windows.MessageBox]::Show($window,'There are no tasks to clear.','Clear Tasks','OK','Information') | Out-Null
            return
        }

        $copied = @($script:Tasks | Where-Object { $_.EmolstSummaryCopied -eq $true })
        $pending = @($script:Tasks | Where-Object { $_.EmolstSummaryCopied -ne $true })
        $removeAll = $false
        if ($pending.Count -gt 0) {
            $message = @(
                'Some tasks have NOT completed Copy EMOLST Summary.'
                ''
                ('Summary copied: {0}' -f $copied.Count)
                ('Summary not copied: {0}' -f $pending.Count)
                ''
                'YES: Clear ALL tasks, including those without summaries.'
                'NO: Clear ONLY tasks with copied summaries; keep the others.'
                'CANCEL: Keep all tasks; do not clear anything.'
            ) -join [Environment]::NewLine
            $choice = [System.Windows.MessageBox]::Show(
                $window,$message,'Clear Tasks - Unsaved Summaries',
                [System.Windows.MessageBoxButton]::YesNoCancel,
                [System.Windows.MessageBoxImage]::Warning,
                [System.Windows.MessageBoxResult]::Cancel
            )
            if ($choice -eq [System.Windows.MessageBoxResult]::Cancel) { return }
            $removeAll = ($choice -eq [System.Windows.MessageBoxResult]::Yes)
        } else {
            $choice = [System.Windows.MessageBox]::Show(
                $window,('Remove all {0} tasks and their user assignments? All have copied EMOLST summaries.' -f $script:Tasks.Count),
                'Confirm Clear Tasks',
                [System.Windows.MessageBoxButton]::YesNo,
                [System.Windows.MessageBoxImage]::Question,
                [System.Windows.MessageBoxResult]::No
            )
            if ($choice -ne [System.Windows.MessageBoxResult]::Yes) { return }
            $removeAll = $true
        }

        $toRemove = if ($removeAll) { @($script:Tasks) } else { $copied }
        if ($toRemove.Count -eq 0) {
            Write-Activity 'Clear Tasks: no tasks removed; summaries are still pending.'
            return
        }
        $removeIds = @{}
        foreach ($task in $toRemove) { $removeIds[[string]$task.TaskID] = $true }
        # Remove associated users as well, so Tasks and Users stay synchronized.
        foreach ($record in @($script:Users)) {
            if ($removeIds.ContainsKey([string]$record.TaskID)) { [void]$script:Users.Remove($record) }
        }
        foreach ($task in $toRemove) { [void]$script:Tasks.Remove($task) }
        $gridTasks.SelectedItem = $null
        $script:TaskProperties.Clear()
        Update-Counters
        Update-WorkflowButtons
        Write-Activity ('Clear Tasks: removed {0}; retained {1} task(s).' -f $toRemove.Count,$script:Tasks.Count)
    } catch {
        Write-Activity ('Clear Tasks error: {0}' -f $_.Exception.Message)
        [System.Windows.MessageBox]::Show($window,$_.Exception.Message,'Clear Tasks Error','OK','Error') | Out-Null
    }
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

$btnAddSSO.Add_Click({
    try {
        Update-WorkflowButtons
        if (-not $btnAddSSO.IsEnabled) {
            [System.Windows.MessageBox]::Show($window,
                'Complete Add Tasks, Add Users, and at least one Clinical OR Provider location assignment for every task before adding SSO.',
                'Complete Locations First','OK','Information') | Out-Null
            return
        }
        $index = 0
        foreach ($task in @($script:Tasks)) {
            $index++
            $result = Show-TaskSSODialog -Task $task -Index $index -Total $script:Tasks.Count
            if ($result.Action -eq 'Stop') {
                Write-Activity ('Add SSO stopped at task {0}.' -f $task.TaskID)
                break
            }
            if ($result.Action -eq 'Skip') {
                Write-Activity ('Add SSO skipped task {0}; existing SSO unchanged.' -f $task.TaskID)
                continue
            }
            $task.EmolstSSOUsername = [string]$result.Value
            $gridTasks.Items.Refresh()
            Update-TaskDetails
            Write-Activity ('Task {0}: SSO number saved.' -f $task.TaskID)
        }
        Update-WorkflowButtons
    }
    catch {
        Write-Activity ('Add SSO error: {0}' -f $_.Exception.Message)
        [System.Windows.MessageBox]::Show($window,$_.Exception.Message,'SSO Workflow Error','OK','Error') | Out-Null
    }
})


# EMOLST review is intentionally generated locally; nothing is submitted to EMOLST.
function Get-ProviderCategory {
    [CmdletBinding()]
    param([AllowNull()][AllowEmptyString()][string]$Credential)
    if ([string]::IsNullOrWhiteSpace($Credential)) { return 'All Others' }
    $credentialKey = $Credential.Trim().ToUpperInvariant()
    $md = @('DDS, MD','DMD, MD','DO','MD','MD, DDS','MD, DMD','MD, DO','MD, PHD','PHD, MD')
    $np = @('ACNP','AGNP','ANP','ANP, NPP','ANP-BC','ANP-C','AOCNP','CNM, FNP','CNM, NP','CNNP','CNP','CPNP','CRNP','CRNP, PHD','DNP- FNP-C','FNP','FNP, NPP','FNP-BC','FNP-C','GNP','NNP','NP','NPC','NPP','OGNP','ONP','PMHNP','PNP','PNP, NPP','WHNP','WHNP, AOCNP')
    $pa = @('PA','PA-C','RPA','RPA-C')
    if ($credentialKey -in $md) { return 'MD/DO Form Signer' }
    if ($credentialKey -in $np) { return 'NP Form Signer' }
    if ($credentialKey -in $pa) { return 'PA Form Signer' }
    return 'Read but no write access to Forms'
}

function Join-EmolstAddress {
    param([string]$Address1,[string]$Address2)
    return (@($Address1.Trim(),$Address2.Trim()) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }) -join ', '
}

function Get-EmolstAdValue {
    param($User,[string[]]$Names)
    if ($null -eq $User) { return '' }
    foreach ($name in $Names) {
        $source = if ($null -ne $User.ADObject) { $User.ADObject } else { $User }
        $prop = $source.PSObject.Properties[$name]
        if ($null -ne $prop -and -not [string]::IsNullOrWhiteSpace([string]$prop.Value)) {
            return [string]$prop.Value
        }
    }
    return ''
}

function Get-EmolstClinicalRecord {
    param($Task)
    # Prefer the exact snapshot attached to the task. Fall back for tasks staged before this update.
    $addr1 = [string]$Task.ClinicalAddress1
    $addr2 = [string]$Task.ClinicalAddress2
    $city = [string]$Task.ClinicalCity
    $state = [string]$Task.ClinicalState
    $zip = [string]$Task.ClinicalZip
    if ([string]::IsNullOrWhiteSpace($addr1) -and $Task.ClinicalLocationName) {
        $matching = @($script:Locations | Where-Object { [string]$_.Name -eq [string]$Task.ClinicalLocationName })
        if ($matching.Count -eq 1) {
            $addr1 = [string]$matching[0].Address1
            $addr2 = [string]$matching[0].Address2
            $city = [string]$matching[0].Locality
            $state = [string]$matching[0].State
            $zip = [string]$matching[0].Zip
        }
    }
    return [pscustomobject]@{
        Street = Join-EmolstAddress -Address1 $addr1 -Address2 $addr2
        City = $city; State = $state; Zip = $zip; Phone = [string]$Task.ClinicalLocationPhone
    }
}

function New-EmolstReviewRow {
    param($Task,[string]$Type)
    $user = Get-TaskUser -Task $Task
    $clinical = Get-EmolstClinicalRecord -Task $Task
    $provider = ($Type -eq 'Provider')
    # OrderedDictionary implements IDictionary, so WPF can bind safely to [Field Name] keys.
    return [ordered]@{
        'Task ID' = [string]$Task.TaskID
        'Type' = $Type
        'Username' = [string]$Task.EmolstUserName
        'Admin Role' = 'No Admin Access'
        'Clinical Role' = if ($provider) { Get-ProviderCategory -Credential ([string]$Task.ProviderTitle) } else { 'Read but no write access to Forms' }
        'Title' = if ($provider) { [string]$Task.ProviderTitle } else { Get-EmolstAdValue -User $user -Names @('Title') }
        'Prefix' = [string]$Task.EmolstPrefix
        'First Name' = if ($provider) { [string]$Task.ProviderFirstName } else { Get-EmolstAdValue -User $user -Names @('GivenName') }
        'Middle Name' = if ($provider) { [string]$Task.ProviderMiddleName } else { Get-EmolstAdValue -User $user -Names @('middleName','MiddleName','OtherName') }
        'Last Name' = if ($provider) { [string]$Task.ProviderLastName } else { Get-EmolstAdValue -User $user -Names @('sn','Surname') }
        'Suffix' = if ($provider) { [string]$Task.ProviderSuffix } else { [string]$Task.EmolstSuffix }
        'Street' = if ($provider) { Join-EmolstAddress -Address1 ([string]$Task.ProviderAddress1) -Address2 ([string]$Task.ProviderAddress2) } else { $clinical.Street }
        'City' = if ($provider) { [string]$Task.ProviderCity } else { $clinical.City }
        'State' = if ($provider) { [string]$Task.ProviderState } else { $clinical.State }
        'Zip' = if ($provider) { [string]$Task.ProviderZip } else { $clinical.Zip }
        'Phone Number' = if ($provider) { [string]$Task.ProviderLocationPhone } else { $clinical.Phone }
        'Email Address' = Get-EmolstAdValue -User $user -Names @('EmailAddress','mail')
        'Provider NPI' = if ($provider) { [string]$Task.ProviderNPI } else { '' }
        'Provider State License' = if ($provider) { [string]$Task.ProviderStateLic } else { '' }
        'SSO Username' = [string]$Task.EmolstSSOUsername
        'Identity Provider' = 'United Health Services - Epic'
        'Validation' = ''
    }
}

function Test-EmolstReviewRows {
    param([object[]]$Rows)
    $commonRequired = @('Task ID','Type','Username','Admin Role','Clinical Role','Title','First Name','Last Name','Street','City','State','Zip','Phone Number','Email Address','SSO Username','Identity Provider')
    $adminRoles = @('No Admin Access','QA/QI','HIPAA Entity Admin','HIPAA Entity Auditor')
    $clinicalRoles = @('Read but no write access to Forms','MD/DO Form Signer','NP Form Signer','PA Form Signer','Form Access, Non-Signer','No Patient Access')
    $invalid = 0
    foreach ($row in $Rows) {
        $errors = [System.Collections.Generic.List[string]]::new()
        foreach ($field in $commonRequired) {
            if ([string]::IsNullOrWhiteSpace([string]$row.$field)) { $errors.Add($field + ' missing') }
        }
        if ($row.Type -notin @('Admin','Clinical','Provider')) { $errors.Add('Type must be Admin, Clinical, or Provider') }
        if ($row.'Admin Role' -notin $adminRoles) { $errors.Add('Unrecognized Admin Role') }
        if ($row.'Clinical Role' -notin $clinicalRoles) { $errors.Add('Unrecognized Clinical Role') }
        if ([string]$row.'SSO Username' -cnotmatch '^[0-9]{1,8}$') { $errors.Add('SSO must contain 1-8 digits') }
        if ([string]$row.'Identity Provider' -cne 'United Health Services - Epic') { $errors.Add('Identity Provider must be United Health Services - Epic') }
        if ($row.Type -eq 'Provider') {
            foreach ($field in @('Provider NPI','Provider State License')) {
                if ([string]::IsNullOrWhiteSpace([string]$row.$field)) { $errors.Add($field + ' missing') }
            }
        }
        $row.Validation = if ($errors.Count -eq 0) { 'OK' } else { $errors -join '; ' }
        if ($errors.Count -gt 0) { $invalid++ }
    }
    return $invalid
}

function Save-EmolstReviewToTasks {
    param([object[]]$Rows)
    $map = [ordered]@{
        'Type'='TaskType'; 'Username'='EmolstUserName'; 'Admin Role'='EmolstAdminRole'
        'Clinical Role'='EmolstClinicalRole'; 'Title'='EmolstTitle'; 'Prefix'='EmolstPrefix'
        'First Name'='EmolstFirstName'; 'Middle Name'='EmolstMiddleName'
        'Last Name'='EmolstLastName'; 'Suffix'='EmolstSuffix'; 'Street'='EmolstStreet'
        'City'='EmolstCity'; 'State'='EmolstState'; 'Zip'='EmolstZip'
        'Phone Number'='EmolstPhone'; 'Email Address'='EmolstEmail'
        'Provider NPI'='EmolstNPI'; 'Provider State License'='EmolstProvStateLic'
        'SSO Username'='EmolstSSOUsername'; 'Identity Provider'='EmolstIdentityProvider'
    }
    foreach ($row in $Rows) {
        $task = @($script:Tasks | Where-Object { $_.TaskID -eq $row.'Task ID' } | Select-Object -First 1)[0]
        if ($null -eq $task) { throw ('Task {0} no longer exists.' -f $row.'Task ID') }
        foreach ($field in $map.Keys) {
            $destination = $map[$field]
            $task.$destination = [string]$row.$field
        }
        $task.EmolstReviewApplied = $true
        $task.EmolstSummaryCopied = $false
        $task.EmolstSummaryFile = ''
    }
    $gridTasks.Items.Refresh()
    Update-TaskDetails
    Update-WorkflowButtons
}

function Show-EmolstDataReview {
    $rows = [System.Collections.ObjectModel.ObservableCollection[object]]::new()
    foreach ($task in $script:Tasks) {
        $hasClinical = -not [string]::IsNullOrWhiteSpace([string]$task.ClinicalLocationName)
        $hasProvider = -not [string]::IsNullOrWhiteSpace([string]$task.ProviderNumber)
        $type = if ($hasClinical) { 'Clinical' } else { 'Provider' }
        $rows.Add((New-EmolstReviewRow -Task $task -Type $type))
    }

    [xml]$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Create EMOLST Data - Review" Width="1360" Height="680"
        MinWidth="850" MinHeight="450" Background="#101827" Foreground="#E6EDF7"
        WindowStartupLocation="CenterOwner" ShowInTaskbar="False" Topmost="True">
    <DockPanel Margin="13">
        <StackPanel DockPanel.Dock="Top" Margin="0,0,0,10">
            <TextBlock Text="EMOLST Data Review" FontSize="21" FontWeight="SemiBold"/>
            <TextBlock Text="Edit cells, choose Type when needed, then Validate and Apply. No data is sent to the EMOLST website."
                       Foreground="#B4C8DE" Margin="0,4,0,5" TextWrapping="Wrap"/>
            <TextBlock x:Name="txtSummary" Foreground="#F2C879" TextWrapping="Wrap"/>
        </StackPanel>
        <StackPanel DockPanel.Dock="Bottom" Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,10,0,0">
            <Button x:Name="btnValidate" Content="Validate" MinWidth="95" Margin="0,0,8,0" Padding="12,7"/>
            <Button x:Name="btnApply" Content="Apply to Tasks" MinWidth="120" Margin="0,0,8,0" Padding="12,7"/>
            <Button x:Name="btnClose" Content="Close" MinWidth="85" Padding="12,7"/>
        </StackPanel>
        <DataGrid x:Name="gridReview" AutoGenerateColumns="False" IsReadOnly="False"
                  CanUserAddRows="False" CanUserDeleteRows="False" AlternationCount="2"
                  Background="#172339" Foreground="#E6EDF7" RowBackground="#172339"
                  AlternatingRowBackground="#20314A" BorderBrush="#3B526D"
                  HorizontalScrollBarVisibility="Auto" VerticalScrollBarVisibility="Auto"
                  HeadersVisibility="Column" GridLinesVisibility="Horizontal">
            <DataGrid.ColumnHeaderStyle>
                <Style TargetType="DataGridColumnHeader">
                    <Setter Property="Background" Value="#DCE6F2"/>
                    <Setter Property="Foreground" Value="#14243A"/>
                    <Setter Property="FontWeight" Value="SemiBold"/>
                    <Setter Property="Padding" Value="9,8"/>
                    <Setter Property="BorderBrush" Value="#AABACD"/>
                    <Setter Property="BorderThickness" Value="0,0,1,1"/>
                </Style>
            </DataGrid.ColumnHeaderStyle>
        </DataGrid>
    </DockPanel>
</Window>
'@
    $dlg = ConvertFrom-WpfXaml $xaml
    $dlg.Owner = $window
    $grid = $dlg.FindName('gridReview')
    $grid.ItemsSource = $rows
    $fields = @('Task ID','Type','Username','Admin Role','Clinical Role','Title','Prefix','First Name','Middle Name','Last Name','Suffix','Street','City','State','Zip','Phone Number','Email Address','Provider NPI','Provider State License','SSO Username','Identity Provider','Validation')
    foreach ($field in $fields) {
        $choices = switch ($field) {
            'Type' { @('Admin','Clinical','Provider') }
            'Admin Role' { @('QA/QI','HIPAA Entity Admin','HIPAA Entity Auditor','No Admin Access') }
            'Clinical Role' { @('Form Access, Non-Signer','Read but no write access to Forms','MD/DO Form Signer','No Patient Access','NP Form Signer','PA Form Signer') }
            default { $null }
        }
        if ($null -ne $choices) {
            $column = [System.Windows.Controls.DataGridComboBoxColumn]::new()
            $column.Header = $field
            $column.ItemsSource = [string[]]$choices
            $binding = [System.Windows.Data.Binding]::new('[' + $field + ']')
            $binding.Mode = [System.Windows.Data.BindingMode]::TwoWay
            $binding.UpdateSourceTrigger = [System.Windows.Data.UpdateSourceTrigger]::PropertyChanged
            $column.SelectedItemBinding = $binding
            $column.Width = [System.Windows.Controls.DataGridLength]::new($(if ($field -eq 'Type') { 125 } elseif ($field -eq 'Admin Role') { 190 } else { 245 }))
            # ComboBox options remain readable when the row background is dark.
            $viewStyle = [System.Windows.Style]::new([System.Windows.Controls.ComboBox])
            $viewStyle.Setters.Add([System.Windows.Setter]::new([System.Windows.Controls.Control]::ForegroundProperty, [System.Windows.Media.Brushes]::Black))
            $viewStyle.Setters.Add([System.Windows.Setter]::new([System.Windows.Controls.Control]::BackgroundProperty, [System.Windows.Media.Brushes]::White))
            $column.EditingElementStyle = $viewStyle
        } else {
            $column = [System.Windows.Controls.DataGridTextColumn]::new()
            $column.Header = $field
            $column.Binding = [System.Windows.Data.Binding]::new('[' + $field + ']')
            $column.Width = if ($field -eq 'Validation') { [System.Windows.Controls.DataGridLength]::new(370) } else { [System.Windows.Controls.DataGridLength]::new(155) }
            if ($field -in @('Task ID','Validation')) { $column.IsReadOnly = $true }
        }
        [void]$grid.Columns.Add($column)
    }
    $summary = $dlg.FindName('txtSummary')
    $hasBoth = @($script:Tasks | Where-Object { $_.ClinicalLocationName -and $_.ProviderNumber })
    if ($hasBoth.Count -gt 0) {
        $summary.Text = ('{0} task(s) have both location types. Clinical is initially selected; change Type to Provider to use DoctorMaster fields.' -f $hasBoth.Count)
    }
    # Switching Type rehydrates its source fields, while retaining common/manual values.
    $grid.Add_CellEditEnding({
        param($sender,$eventArgs)
        if ($eventArgs.Column.Header -ne 'Type') { return }
        $row = $eventArgs.Row.Item
        $combo = $eventArgs.EditingElement
        $newType = [string]$combo.SelectedItem
        if ($newType -notin @('Admin','Clinical','Provider') -or $newType -eq $row.Type) { return }
        $task = @($script:Tasks | Where-Object { $_.TaskID -eq $row.'Task ID' } | Select-Object -First 1)[0]
        if ($newType -eq 'Clinical' -and -not $task.ClinicalLocationName) {
            [System.Windows.MessageBox]::Show($dlg,'No Clinical Location is assigned to this task.','Type unavailable','OK','Warning') | Out-Null
            $eventArgs.Cancel = $true; return
        }
        if ($newType -eq 'Provider' -and -not $task.ProviderNumber) {
            [System.Windows.MessageBox]::Show($dlg,'No DoctorMaster provider is assigned to this task.','Type unavailable','OK','Warning') | Out-Null
            $eventArgs.Cancel = $true; return
        }
        # Admin uses AD identity rather than DoctorMaster provider identity.
        # Where a clinical location exists, use it as the address source.
        # Otherwise preserve the manually editable address values for review.
        $fresh = New-EmolstReviewRow -Task $task -Type $newType
        foreach ($property in @('Title','First Name','Middle Name','Last Name','Suffix','Street','City','State','Zip','Phone Number','Provider NPI','Provider State License','Clinical Role')) {
            if ($newType -eq 'Admin' -and -not $task.ClinicalLocationName -and
                $property -in @('Street','City','State','Zip','Phone Number')) { continue }
            $row.$property = $fresh.$property
        }
        # Cell commit updates Type through the binding after this event.
        $dlg.Dispatcher.BeginInvoke([action]{ $grid.Items.Refresh() }) | Out-Null
    })
    $validateAction = {
        [void]$grid.CommitEdit([System.Windows.Controls.DataGridEditingUnit]::Cell,$true)
        [void]$grid.CommitEdit([System.Windows.Controls.DataGridEditingUnit]::Row,$true)
        $bad = Test-EmolstReviewRows -Rows @($rows)
        $grid.Items.Refresh()
        $summary.Text = if ($bad -eq 0) { 'All {0} task(s) passed required-field validation.' -f $rows.Count } else { '{0} of {1} task(s) need attention. Scroll right to the Validation column.' -f $bad,$rows.Count }
        return $bad
    }.GetNewClosure()
    $dlg.FindName('btnValidate').Add_Click({ [void](& $validateAction) }.GetNewClosure())
    $dlg.FindName('btnApply').Add_Click({
        if ((& $validateAction) -gt 0) {
            [System.Windows.MessageBox]::Show($dlg,'Correct required fields shown in the Validation column before applying.','Validation failed','OK','Warning') | Out-Null
            return
        }
        $overrides = @($rows | Where-Object {
            $_.'Admin Role' -ne 'No Admin Access' -or
            $_.'Clinical Role' -in @('Form Access, Non-Signer','No Patient Access')
        })
        if ($overrides.Count -gt 0) {
            $confirm = [System.Windows.MessageBox]::Show($dlg,
                ('{0} task(s) have manually selected access-role overrides. Apply these roles to the task records?' -f $overrides.Count),
                'Confirm manual role overrides','YesNo','Warning')
            if ($confirm -ne [System.Windows.MessageBoxResult]::Yes) { return }
        }
        Save-EmolstReviewToTasks -Rows @($rows)
        Write-Activity ('Created and applied EMOLST data for {0} task(s).' -f $rows.Count)
        $dlg.DialogResult = $true
    }.GetNewClosure())
    $dlg.FindName('btnClose').Add_Click({ $dlg.Close() })
    [void](& $validateAction)
    [void]$dlg.ShowDialog()
}

$btnCreateEMOLST.Add_Click({
    try {
        Update-WorkflowButtons
        if (-not $btnCreateEMOLST.IsEnabled) { return }
        Show-EmolstDataReview
    } catch {
        Write-Activity ('Create EMOLST Data error: {0}' -f $_.Exception.Message)
        [System.Windows.MessageBox]::Show($window,$_.Exception.Message,'EMOLST Data Error','OK','Error') | Out-Null
    }
})

# Resolve the installed Chrome desktop executable, independent of browser defaults.
function Get-ChromeExecutable {
    $commands = @(Get-Command 'chrome.exe' -ErrorAction SilentlyContinue)
    foreach ($command in $commands) {
        if ($command.Source -and (Test-Path -LiteralPath $command.Source -PathType Leaf)) {
            return $command.Source
        }
    }

    foreach ($regPath in @(
        'Registry::HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\App Paths\chrome.exe',
        'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\chrome.exe',
        'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\App Paths\chrome.exe'
    )) {
        try {
            $key = Get-Item -LiteralPath $regPath -ErrorAction Stop
            $exe = [string]$key.GetValue('')
            if ($exe -and (Test-Path -LiteralPath $exe -PathType Leaf)) { return $exe }
        }
        catch { }
    }

    foreach ($base in @($env:ProgramFiles, ${env:ProgramFiles(x86)}, $env:LOCALAPPDATA)) {
        if ([string]::IsNullOrWhiteSpace($base)) { continue }
        $candidate = Join-Path $base 'Google\Chrome\Application\chrome.exe'
        if (Test-Path -LiteralPath $candidate -PathType Leaf) { return $candidate }
    }
    return $null
}

function Start-ChromeWebsite {
    param(
        [Parameter(Mandatory=$true)][string]$Name,
        [Parameter(Mandatory=$true)][string]$Url
    )
    try {
        $chrome = Get-ChromeExecutable
        if (-not $chrome) {
            throw 'Google Chrome is not installed or chrome.exe could not be located on this PC.'
        }
        Start-Process -FilePath $chrome -ArgumentList @($Url) -ErrorAction Stop
        Write-Activity ('{0}: opened in Chrome: {1}' -f $Name, $Url)
    }
    catch {
        Write-Activity ('{0}: launch failed: {1}' -f $Name, $_.Exception.Message)
        [System.Windows.MessageBox]::Show(
            $window, $_.Exception.Message, ('Unable to launch {0}' -f $Name), 'OK', 'Error'
        ) | Out-Null
    }
}

$btnLaunchIvanti.Add_Click({
    Start-ChromeWebsite -Name 'Ivanti' -Url 'https://uhs-amc.ivanticloud.com'
})
$btnLaunchDrMaster.Add_Click({
    Start-ChromeWebsite -Name 'Dr Master' -Url 'http://apps.uhs.org/DoctorMaster/DoctorsInternal.aspx'
})
$btnLaunchEMOLST.Add_Click({
    Start-ChromeWebsite -Name 'EMOLST' -Url 'https://www.nysemolstregistry.com/backend/LogIn.aspx?RedirectUrl=%2fbackend%2fPages%2fUsers.aspx'
})

foreach ($config in @(
    @{ Control = $btnLoadIvantiSummary; Name = 'Load Ivanti Summary' }
)) {
    $feature = [string]$config.Name
    $button = $config.Control
    # Use a dedicated closure to avoid every handler taking the last loop value.
    $button.Add_Click(({ Show-NotImplemented -Feature $feature }).GetNewClosure())
}


# Each Clavier file represents ONE selected task. Clavier /load replaces the
# active Clavier configuration, so arming another task replaces this shortcut.
function Get-ClavierExecutable {
    $command = Get-Command 'clavier.exe' -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($command -and $command.Source -and (Test-Path -LiteralPath $command.Source -PathType Leaf)) {
        return $command.Source
    }
    $locations = @(
        (Join-Path $PSScriptRoot 'clavier.exe'),
        (Join-Path $env:ProgramFiles 'Clavier+\Clavier.exe')
    )
    if (${env:ProgramFiles(x86)}) {
        $locations += Join-Path ${env:ProgramFiles(x86)} 'Clavier+\Clavier.exe'
    }
    foreach ($candidate in $locations) {
        if ($candidate -and (Test-Path -LiteralPath $candidate -PathType Leaf)) { return $candidate }
    }
    throw 'Clavier.exe not found. Put clavier.exe beside this script or add its installation directory to PATH.'
}

function Get-EmolstClavierFields {
    param([Parameter(Mandatory)]$Task)
    # Position C02 intentionally contains just a Tab, matching the supplied macro.
    # Emit each of the 19 fields separately; unary comma would nest the entire array.
    return @(
        [string]$Task.EmolstUserName,
        [string]$Task.EmolstAdminRole,
        [string]$Task.EmolstClinicalRole,
        [string]$Task.EmolstTitle,
        [string]$Task.EmolstPrefix,
        [string]$Task.EmolstFirstName,
        [string]$Task.EmolstMiddleName,
        [string]$Task.EmolstLastName,
        [string]$Task.EmolstSuffix,
        [string]$Task.EmolstStreet,
        [string]$Task.EmolstCity,
        [string]$Task.EmolstState,
        [string]$Task.EmolstZip,
        [string]$Task.EmolstPhone,
        [string]$Task.EmolstEmail,
        [string]$Task.EmolstNPI,
        [string]$Task.EmolstProvStateLic,
        [string]$Task.EmolstSSOUsername,
        [string]$Task.EmolstIdentityProvider
    )
}

function Write-EmolstClavierConfig {
    param([Parameter(Mandatory)]$Task,[Parameter(Mandatory)][bool]$Arm)
    $lines = @('Language=English','Size=637,439,0,0','Columns=35,20,15,10','Sorting=0','')
    if ($Arm) {
        if ($Task.EmolstReviewApplied -ne $true) {
            throw ('Task {0} has not had its EMOLST data reviewed and applied.' -f $Task.TaskID)
        }
        $values = @(Get-EmolstClavierFields -Task $Task)
        if ($values.Count -ne 19) { throw 'EMOLST shortcut expects 19 mapped field values.' }
        foreach ($value in $values) {
            # Square brackets delimit Clavier instructions, and a newline would
            # introduce another INI setting. Stop instead of generating bad code.
            if ($value -match '[\[\]\r\n]') {
                throw 'An EMOLST field contains square brackets or a line break that Clavier cannot safely paste. Correct the reviewed task data first.'
            }
        }
        $wait = '[][][]'
        $tab = '[Tab]' + $wait + $wait
        $paste = $wait + '[Ctrl + V]' + $wait + $tab
        $parts = [System.Collections.Generic.List[string]]::new()
        # Clavier cannot reliably execute [{Copy,}] for a blank value.
        # Use a TAB ONLY for empty optional fields to keep all subsequent
        # values aligned with their actual EMOLST form controls.
        # The 19-element sequence is fixed: index 15 = Provider NPI,
        # 16 = Provider State License, 17 = SSO Username, 18 = Identity Provider.
        if ([string]::IsNullOrWhiteSpace($values[0])) {
            throw 'EMOLST Username is empty. Review and apply the EMOLST data before arming.'
        }
        $parts.Add('[{Copy,' + $values[0] + '}]' + $paste)
        $parts.Add($tab) # C02: deliberately skip the next form field.
        for ($index = 1; $index -lt $values.Count; $index++) {
            if ([string]::IsNullOrWhiteSpace($values[$index])) {
                $parts.Add($tab)
            } else {
                $parts.Add('[{Copy,' + $values[$index] + '}]' + $paste)
            }
            # After Email Address (index 14), the EMOLST form focuses the
            # red "NPI Search" link before the Provider NPI input. Advance
            # past that link, regardless of whether the NPI value is blank.
            if ($index -eq 14) {
                $parts.Add($tab)
            }
        }
        $lines += 'Shortcut=`'
        $lines += 'Code=192'
        $lines += 'Text=' + ($parts -join '')
        $lines += 'Usages=0'
    }
    $lines += '-'
    $path = Join-Path $PSScriptRoot ("{0}-powershell.ini" -f $env:COMPUTERNAME)
    # Write to a temporary file and atomically replace the configuration.
    # PowerShell 5.1 Default encoding matches the local Windows ANSI code page.
    $temp = Join-Path $PSScriptRoot ('.{0}.tmp' -f ([guid]::NewGuid().ToString('N')))
    try {
        [System.IO.File]::WriteAllLines($temp, [string[]]$lines, [System.Text.Encoding]::Default)
        Move-Item -LiteralPath $temp -Destination $path -Force
    } finally {
        if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Force -ErrorAction SilentlyContinue }
    }
    return $path
}

function Invoke-EmolstClavier {
    param([Parameter(Mandatory)]$Task,[Parameter(Mandatory)][bool]$Arm)
    try {
        # Verify Clavier is installed BEFORE touching any existing INI.
        $exe = Get-ClavierExecutable
        $path = Write-EmolstClavierConfig -Task $Task -Arm $Arm
        if ($Arm) {
            Start-Process -FilePath $exe -ArgumentList ('/load "{0}"' -f $path) -ErrorAction Stop | Out-Null
            # Make the selected task's reviewed EMOLST username ready to paste
            # into the sign-in/search field before the Clavier hotkey is used.
            $emolstUserName = [string]$Task.EmolstUserName
            if (-not [string]::IsNullOrWhiteSpace($emolstUserName)) {
                try {
                    [System.Windows.Clipboard]::SetText($emolstUserName)
                    Write-Activity ('Copied EMOLST username to clipboard for Task {0}.' -f $Task.TaskID)
                } catch {
                    Write-Activity ('Could not copy EMOLST username for Task {0}: {1}' -f $Task.TaskID,$_.Exception.Message)
                    [System.Windows.MessageBox]::Show($window,('Clavier was loaded, but copying the EMOLST username failed: {0}' -f $_.Exception.Message),'Clipboard Warning','OK','Warning') | Out-Null
                }
            }
        } else {
            # Disarming exits Clavier instead of loading an empty shortcut file.
            Start-Process -FilePath $exe -ArgumentList '/quit' -ErrorAction Stop | Out-Null
        }
        $action = if ($Arm) { 'Armed' } else { 'Disarmed' }
        Write-Activity ('{0} EMOLST Clavier shortcut for Task {1}: {2}' -f $action,$Task.TaskID,$path)
    } catch {
        Write-Activity ('Clavier error for Task {0}: {1}' -f $Task.TaskID,$_.Exception.Message)
        [System.Windows.MessageBox]::Show($window,$_.Exception.Message,'EMOLST Clavier Error','OK','Error') | Out-Null
    }
}

# Copy a readable, fixed-width EMOLST summary and archive it locally.
# Only reviewed/applied data is used: no live AD or DoctorMaster re-query.
function Copy-EmolstSummary {
    param([Parameter(Mandatory)]$Task)

    if ($Task.EmolstReviewApplied -ne $true) {
        throw ('Task {0} has not had its EMOLST data reviewed and applied.' -f $Task.TaskID)
    }

    # Retain this order so the output matches the EMOLST form review.
    $fields = [ordered]@{
        'Task ID'                = [string]$Task.TaskID
        'Task Type'              = [string]$Task.TaskType
        'Username'               = [string]$Task.EmolstUserName
        'Admin Role'             = [string]$Task.EmolstAdminRole
        'Clinical Role'          = [string]$Task.EmolstClinicalRole
        'Title'                  = [string]$Task.EmolstTitle
        'Prefix'                 = [string]$Task.EmolstPrefix
        'First Name'             = [string]$Task.EmolstFirstName
        'Middle Name'            = [string]$Task.EmolstMiddleName
        'Last Name'              = [string]$Task.EmolstLastName
        'Suffix'                 = [string]$Task.EmolstSuffix
        'Street'                 = [string]$Task.EmolstStreet
        'City'                   = [string]$Task.EmolstCity
        'State'                  = [string]$Task.EmolstState
        'Zip'                    = [string]$Task.EmolstZip
        'Phone Number'           = [string]$Task.EmolstPhone
        'Email Address'          = [string]$Task.EmolstEmail
        'Provider NPI'           = [string]$Task.EmolstNPI
        'Provider State License' = [string]$Task.EmolstProvStateLic
        'SSO Username'           = [string]$Task.EmolstSSOUsername
        'Identity Provider'      = [string]$Task.EmolstIdentityProvider
    }

    $lines = foreach ($entry in $fields.GetEnumerator()) {
        '{0,22}: {1}' -f $entry.Key, $entry.Value
    }
    $content = ($lines -join [Environment]::NewLine) + [Environment]::NewLine

    $folder = 'C:\Temp\~EMOLST'
    if (-not (Test-Path -LiteralPath $folder -PathType Container)) {
        [void](New-Item -ItemType Directory -Path $folder -Force -ErrorAction Stop)
    }

    # Windows file names cannot contain reserved characters from user data.
    $invalid = [System.IO.Path]::GetInvalidFileNameChars()
    $nameParts = foreach ($part in @([string]$Task.EmolstLastName,[string]$Task.EmolstFirstName,[string]$Task.EmolstUserName)) {
        $clean = ([string]$part).Trim()
        foreach ($character in $invalid) { $clean = $clean.Replace([string]$character, '_') }
        $clean = $clean.Trim().TrimEnd('.')
        if ([string]::IsNullOrWhiteSpace($clean)) { 'Unknown' } else { $clean }
    }
    $prefix = '{0} {1}' -f (Get-Date -Format 'yyyyMMdd-HHmm'), ($nameParts -join ' ')
    $destination = Join-Path $folder ($prefix + '.txt')
    # Preserve existing summaries in case the same person is processed twice in a minute.
    $sequence = 2
    while (Test-Path -LiteralPath $destination) {
        $destination = Join-Path $folder ('{0} ({1}).txt' -f $prefix,$sequence)
        $sequence++
    }

    # Use UTF-8 with BOM for easy Notepad viewing in Windows PowerShell 5.1.
    $encoding = [System.Text.UTF8Encoding]::new($true)
    [System.IO.File]::WriteAllText($destination,$content,$encoding)
    [System.Windows.Clipboard]::SetText($content)
    return $destination
}

# Right click selects the task under the pointer (not a previously selected row).
$gridTasks.Add_PreviewMouseRightButtonDown({
    param($sender,$eventArgs)
    $element = $eventArgs.OriginalSource -as [System.Windows.DependencyObject]
    while ($element -and -not ($element -is [System.Windows.Controls.DataGridRow])) {
        $element = [System.Windows.Media.VisualTreeHelper]::GetParent($element)
    }
    if ($element -is [System.Windows.Controls.DataGridRow]) {
        $gridTasks.SelectedItem = $element.Item
    }
})

$taskMenu = [System.Windows.Controls.ContextMenu]::new()
$armMenuItem = [System.Windows.Controls.MenuItem]::new()
$armMenuItem.Header = 'Arm EMOLST Script'
$disarmMenuItem = [System.Windows.Controls.MenuItem]::new()
$disarmMenuItem.Header = 'Disarm EMOLST Script'
$copySummaryMenuItem = [System.Windows.Controls.MenuItem]::new()
$copySummaryMenuItem.Header = 'Copy EMOLST Summary'
$removeTaskMenuItem = [System.Windows.Controls.MenuItem]::new()
$removeTaskMenuItem.Header = 'Remove Task'
[void]$taskMenu.Items.Add($armMenuItem)
[void]$taskMenu.Items.Add($disarmMenuItem)
[void]$taskMenu.Items.Add(([System.Windows.Controls.Separator]::new()))
[void]$taskMenu.Items.Add($copySummaryMenuItem)
[void]$taskMenu.Items.Add(([System.Windows.Controls.Separator]::new()))
[void]$taskMenu.Items.Add($removeTaskMenuItem)
$taskMenu.Add_Opened({
    $task = $gridTasks.SelectedItem
    $armMenuItem.IsEnabled = ($null -ne $task -and $task.EmolstReviewApplied -eq $true)
    $disarmMenuItem.IsEnabled = ($null -ne $task)
    $removeTaskMenuItem.IsEnabled = ($null -ne $task)
    $copySummaryMenuItem.IsEnabled = ($null -ne $task -and $task.EmolstReviewApplied -eq $true)
    $copySummaryMenuItem.ToolTip = if ($copySummaryMenuItem.IsEnabled) { 'Copy and save the reviewed EMOLST fields.' } else { 'Apply Create EMOLST Data first.' }
    $armMenuItem.ToolTip = if ($armMenuItem.IsEnabled) { 'Load the selected task into Clavier.' } else { 'Run Create EMOLST Data and Apply to Tasks first.' }
})
$armMenuItem.Add_Click({
    $task = $gridTasks.SelectedItem
    if ($null -ne $task) { Invoke-EmolstClavier -Task $task -Arm $true }
})
$disarmMenuItem.Add_Click({
    $task = $gridTasks.SelectedItem
    if ($null -ne $task) { Invoke-EmolstClavier -Task $task -Arm $false }
})
$copySummaryMenuItem.Add_Click({
    $task = $gridTasks.SelectedItem
    if ($null -eq $task) { return }
    try {
        $file = Copy-EmolstSummary -Task $task
        # Mark complete only after both file writing and clipboard copy succeed.
        $task.EmolstSummaryCopied = $true
        $task.EmolstSummaryFile = [string]$file
        $gridTasks.Items.Refresh()
        Update-TaskDetails
        Write-Activity ('Copied EMOLST summary for Task {0}; saved to {1}' -f $task.TaskID,$file)
    } catch {
        Write-Activity ('EMOLST summary error for Task {0}: {1}' -f $task.TaskID,$_.Exception.Message)
        [System.Windows.MessageBox]::Show($window,$_.Exception.Message,'EMOLST Summary Error','OK','Error') | Out-Null
    }
})
# Removing a task never requires an AD match or an EMOLST summary.
$removeTaskMenuItem.Add_Click({
    try {
        $task = $gridTasks.SelectedItem
        if ($null -eq $task) { return }
        $taskId = [string]$task.TaskID
        $linkedUser = @($script:Users | Where-Object { [string]$_.TaskID -eq $taskId })
        $summaryWarning = if ($task.EmolstSummaryCopied -eq $true) {
            'An EMOLST summary has been copied for this task.'
        } else {
            'WARNING: Copy EMOLST Summary has not been completed for this task.'
        }
        $message = @(
            ('Remove Task ID: {0}?' -f $taskId),
            '',
            $summaryWarning,
            ('Associated AD user record(s): {0}' -f $linkedUser.Count),
            '',
            'This removes the selected task and its linked user record from this session.',
            'Other tasks will not be changed.',
            '',
            'Continue?'
        ) -join [Environment]::NewLine
        $response = [System.Windows.MessageBox]::Show(
            $window,$message,'Confirm Remove Task',
            [System.Windows.MessageBoxButton]::YesNo,
            [System.Windows.MessageBoxImage]::Warning,
            [System.Windows.MessageBoxResult]::No
        )
        if ($response -ne [System.Windows.MessageBoxResult]::Yes) { return }

        foreach ($userRecord in $linkedUser) { [void]$script:Users.Remove($userRecord) }
        [void]$script:Tasks.Remove($task)
        $gridTasks.SelectedItem = $null
        $script:TaskProperties.Clear()
        Update-Counters
        Update-WorkflowButtons
        Write-Activity ('Removed Task {0} and {1} linked user record(s).' -f $taskId,$linkedUser.Count)
    } catch {
        Write-Activity ('Remove Task error: {0}' -f $_.Exception.Message)
        [System.Windows.MessageBox]::Show(
            $window,$_.Exception.Message,'Remove Task Error','OK','Error'
        ) | Out-Null
    }
})
$gridTasks.ContextMenu = $taskMenu

$gridTasks.Add_SelectionChanged({
    Update-TaskDetails
    Sync-SelectionFromTask
})
$gridUsers.Add_SelectionChanged({ Sync-SelectionFromUser })
Update-Counters
Update-WorkflowButtons
Read-ClinicalFavorites
Read-ClinicalLocations
Write-Activity 'Ready. Workflow: Add Tasks -> Add Users -> Add Locations -> Add SSO -> Create EMOLST Data.'
[void]$window.ShowDialog()
