#requires -Version 5.1
<#
.SYNOPSIS
    Clinical Task Workbench - PowerShell 5.1 / WPF
.DESCRIPTION
    Topmost GUI for staging Task IDs, associating AD users, and later
    integrating Clinical Locations, Professional Locations, SSO, Ivanti,
    Doctor Master, EPIC, and EMOLST.

    The Add Tasks and Add Users workflows are implemented. Buttons for
    integrations without supplied specifications are deliberately placeholders.

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
                <RowDefinition Height="*"/>
            </Grid.RowDefinitions>
            <WrapPanel Grid.Row="0" Margin="0,0,0,3">
                <Button x:Name="btnAddTasks" Content="Add Tasks" Background="#17657A"/>
                <Button x:Name="btnAddUsers" Content="Add Users" Background="#17657A"/>
                <Button x:Name="btnAddClinLoc" Content="Add Clin Loc"/>
                <Button x:Name="btnAddProfLoc" Content="Add Prof Loc"/>
                <Button x:Name="btnAddSSO" Content="Add SSO"/>
                <Button x:Name="btnLaunchIvanti" Content="Launch Ivanti"/>
                <Button x:Name="btnLaunchDrMaster" Content="Launch Dr Master"/>
                <Button x:Name="btnLaunchEMOLST" Content="Launch EMOLST"/>
                <Button x:Name="btnLoadEPICUser" Content="Load EPIC User"/>
                <Button x:Name="btnLoadEMOLSTUser" Content="Load EMOLST User"/>
                <Button x:Name="btnLoadDrMasterUser" Content="Load Dr Master User"/>
                <Button x:Name="btnLoadIvantiSummary" Content="Load Ivanti Summary"/>
            </WrapPanel>
            <Grid Grid.Row="1" Margin="0,3,0,10">
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="*"/>
                </Grid.ColumnDefinitions>
                <TextBlock Grid.Column="0" x:Name="txtTaskCount" Text="Tasks (0)" FontWeight="SemiBold" FontSize="17"/>
                <TextBlock Grid.Column="1" x:Name="txtUserCount" Text="Users (0)" FontWeight="SemiBold" FontSize="17"/>
            </Grid>
            <Grid Grid.Row="2">
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
    'btnAddTasks','btnAddUsers','btnAddClinLoc','btnAddProfLoc','btnAddSSO',
    'btnLaunchIvanti','btnLaunchDrMaster','btnLaunchEMOLST',
    'btnLoadEPICUser','btnLoadEMOLSTUser','btnLoadDrMasterUser','btnLoadIvantiSummary',
    'txtTaskCount','txtUserCount','txtStatus','txtLog',
    'gridTasks','gridUsers','gridTaskProperties'
)
foreach ($name in $controlNames) { Set-Variable -Name $name -Value $window.FindName($name) -Scope Script }

$script:Tasks = [System.Collections.ObjectModel.ObservableCollection[object]]::new()
$script:Users = [System.Collections.ObjectModel.ObservableCollection[object]]::new()
$script:TaskProperties = [System.Collections.ObjectModel.ObservableCollection[object]]::new()
$gridTasks.ItemsSource = $script:Tasks
$gridUsers.ItemsSource = $script:Users
$gridTaskProperties.ItemsSource = $script:TaskProperties

$script:TaskFieldNames = @(
    'TaskID','TaskType','TaskNote','EmolstUserName','EmolstAdminRole',
    'EmolstClinicalRole','EmolstTitle','EmolstPrefix','EmolstFirstName',
    'EmolstMiddleName','EmolstLastName','EmolstSuffix','EmolstStreet',
    'EmolstCity','EmolstState','EmolstZip','EmolstPhone','EmolstEmail',
    'EmolstNPI','EmolstProvStateLic','EmolstSSOUsername','EmolstIdentityProvider'
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
        [switch]$Multiline
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
    $dlg.Owner = $window
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
    Write-Activity ('Linked {0} to task {1} ({2} AD match(es)).' -f $user.SamAccountName, $Task.TaskID, $matches.Count)
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
        foreach ($task in @($script:Tasks)) {
            $message = 'Task {0}: enter a user identifier (SamAccountName, EmployeeID, email, name, etc.). Cancel stops the loop. Leave empty to skip.' -f $task.TaskID
            $entered = Show-TextPrompt -Title ('AD User for Task {0}' -f $task.TaskID) -Message $message -DefaultValue $task.EmolstUserName
            if ($null -eq $entered) { Write-Activity 'Add Users cancelled by operator.'; break }
            $entered = $entered.Trim()
            if (-not $entered) { Write-Activity ('Skipped task {0} (blank search).' -f $task.TaskID); continue }
            Add-AdUserForTask -Task $task -SearchTerm $entered
        }
        Update-Counters
    }
    catch { Write-Activity ('Add Users error: {0}' -f $_.Exception.Message) }
})

foreach ($config in @(
    @{ Control = $btnAddClinLoc; Name = 'Add Clin Loc' },
    @{ Control = $btnAddProfLoc; Name = 'Add Prof Loc' },
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
Write-Activity 'Ready. Add Tasks accepts comma-separated Task IDs; Add Users searches AD per task.'
[void]$window.ShowDialog()
