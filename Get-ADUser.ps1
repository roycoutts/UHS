# Hide the PowerShell console window
Add-Type -Name Win32 -Namespace Console -MemberDefinition @"
[DllImport("user32.dll")]
public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
[DllImport("kernel32.dll")]
public static extern IntPtr GetConsoleWindow();
"@

$consoleHandle = [Console.Win32]::GetConsoleWindow()
[Console.Win32]::ShowWindow($consoleHandle, 0) # 0 = SW_HIDE

# Import the custom Active Directory module
Import-Module cActiveDirectoryModule -ErrorAction Stop

# XAML for the WPF GUI
[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="AD User Search" Height="600" Width="1000" Topmost="True">
    <Grid Margin="10">

        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>

        <StackPanel Orientation="Horizontal" Grid.Row="0" Margin="0,0,0,10">
            <TextBox x:Name="SearchBox" Width="220" Margin="0,0,10,0"/>
            <Button x:Name="SearchButton" Content="Search" Width="100" Margin="0,0,10,0"/>

            <Button x:Name="CopyTicketButton" Content="Copy Ticket Block" Width="140" Margin="0,0,10,0"/>
            <Button x:Name="CopyGroupsButton" Content="Copy Groups Only" Width="140"/>
        </StackPanel>

        <DataGrid x:Name="UserGrid" Grid.Row="1" AutoGenerateColumns="False" IsReadOnly="True">
            <DataGrid.Columns>
                <DataGridTextColumn Header="Enabled" Binding="{Binding Enabled}"/>
                <DataGridTextColumn Header="LockedOut" Binding="{Binding LockedOut}"/>
                <DataGridTextColumn Header="Employee ID" Binding="{Binding EmployeeID}"/>
                <DataGridTextColumn Header="SAM Account Name" Binding="{Binding SamAccountName}"/>
                <DataGridTextColumn Header="Given Name" Binding="{Binding GivenName}"/>
                <DataGridTextColumn Header="Middle Name" Binding="{Binding MiddleName}"/>
                <DataGridTextColumn Header="Surname" Binding="{Binding Surname}"/>
                <DataGridTextColumn Header="Display Name" Binding="{Binding DisplayName}"/>
                <DataGridTextColumn Header="Email Address" Binding="{Binding EmailAddress}"/>
                <DataGridTextColumn Header="Title" Binding="{Binding Title}"/>
                <DataGridTextColumn Header="Department" Binding="{Binding Department}"/>
                <DataGridTextColumn Header="Office" Binding="{Binding Office}"/>
                <DataGridTextColumn Header="Manager" Binding="{Binding Manager}"/>
            </DataGrid.Columns>

            <DataGrid.RowStyle>
                <Style TargetType="DataGridRow">
                    <!-- Tooltip (unchanged behavior) -->
                    <Setter Property="ToolTip">
                        <Setter.Value>
                            <ToolTip MaxWidth="500">
                                <ScrollViewer MaxHeight="350" VerticalScrollBarVisibility="Auto">
                                    <TextBlock Text="{Binding MemberOfTooltip}" TextWrapping="Wrap"/>
                                </ScrollViewer>
                            </ToolTip>
                        </Setter.Value>
                    </Setter>

                    <!-- Disabled user styling -->
                    <Style.Triggers>
                        <DataTrigger Binding="{Binding Enabled}" Value="False">
                            <Setter Property="Foreground" Value="Gray"/>
                            <Setter Property="Opacity" Value="0.75"/>
                            <Setter Property="Background" Value="#FFF3F3F3"/>
                        </DataTrigger>
                    </Style.Triggers>
                </Style>
            </DataGrid.RowStyle>

        </DataGrid>
        <Border Grid.Row="2" Margin="0,10,0,0" Padding="8" BorderThickness="1" BorderBrush="#CCC">
            <DockPanel LastChildFill="True">
                <TextBlock Text="Status:" FontWeight="Bold" Margin="0,0,8,0"/>
                <TextBlock x:Name="StatusText" Text="Ready"/>
            </DockPanel>
        </Border>

    </Grid>
</Window>
"@

# Load the XAML
Add-Type -AssemblyName PresentationFramework
$reader = (New-Object System.Xml.XmlNodeReader $xaml)
$window = [Windows.Markup.XamlReader]::Load($reader)

# Get WPF elements
$searchBox = $window.FindName("SearchBox")
$searchButton = $window.FindName("SearchButton")
$userGrid = $window.FindName("UserGrid")
$copyTicketButton = $window.FindName("CopyTicketButton")
$copyGroupsButton = $window.FindName("CopyGroupsButton")
$statusText = $window.FindName("StatusText")

# ---------- Helpers (add above Search-ADUsers) ----------

# Put your high-value groups here (exact names as they appear in CN)
$script:ImportantGroups = @(
    "APP_FOO_Users",
    "APP_BAR_Access",
    "VPN_Users",
    "Citrix_Users"
)

# Optional: treat these as prefixes too (handy if groups are like APP_FOO_* )
$script:ImportantGroupPrefixes = @(
    "Citrix",
    "ISCV"
)

function Sort-GroupsPinned {
    param(
        [string[]]$Groups,
        [string[]]$PinnedExact = $script:ImportantGroups,
        [string[]]$PinnedPrefixes = $script:ImportantGroupPrefixes
    )

    if (-not $Groups) { return @() }

    $pinnedSet = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($g in ($PinnedExact | Where-Object { $_ })) { [void]$pinnedSet.Add($g) }

    $pinned = New-Object System.Collections.Generic.List[string]
    $rest   = New-Object System.Collections.Generic.List[string]

    foreach ($g in $Groups) {
        if ([string]::IsNullOrWhiteSpace($g)) { continue }

        $isPinned =
            $pinnedSet.Contains($g) -or
            ($PinnedPrefixes | Where-Object { $_ -and $g.StartsWith($_, [System.StringComparison]::OrdinalIgnoreCase) } | Measure-Object).Count -gt 0

        if ($isPinned) { $pinned.Add($g) } else { $rest.Add($g) }
    }

    # Sort each section
    $pinnedSorted = $pinned | Sort-Object -Unique
    $restSorted   = $rest   | Sort-Object -Unique

    # Optional: add a divider line between sections (tooltip only)
    return @($pinnedSorted + @("-----") + $restSorted)
}


function Set-Status {
    param([string]$Text)
    if ($statusText) { $statusText.Text = $Text }
}

function Resolve-ManagerName {
    param(
        [string]$ManagerDn,
        [hashtable]$Cache
    )

    if ([string]::IsNullOrWhiteSpace($ManagerDn)) { return "" }
    if ($Cache.ContainsKey($ManagerDn)) { return $Cache[$ManagerDn] }

    try {
        $m = Get-ADUser -Identity $ManagerDn -Properties DisplayName,SamAccountName -ErrorAction Stop
        $name = if ($m.DisplayName) { $m.DisplayName } else { $m.SamAccountName }
        if ($m.SamAccountName -and $m.DisplayName) { $name = "$($m.DisplayName) ($($m.SamAccountName))" }

        $Cache[$ManagerDn] = $name
        return $name
    }
    catch {
        # fallback: DN (or empty)
        $Cache[$ManagerDn] = $ManagerDn
        return $ManagerDn
    }
}


function Set-ClipboardTextSafe {
    param([Parameter(Mandatory)][string]$Text)

    try {
        [System.Windows.Clipboard]::SetText($Text)
        return $true
    }
    catch {
        Set-Status "Failed to copy to clipboard:`n$($_.Exception.Message)"
        return $false
    }
}


function New-TicketBlockText {
    param([Parameter(Mandatory)]$SelectedItem)

    # Handle nulls cleanly
    $val = {
        param($x)
        if ($null -eq $x) { "" } else { [string]$x }
    }

    $memberOfBlock = ""
    if ($SelectedItem.MemberOfGroups) {
        $memberOfBlock = ($SelectedItem.MemberOfGroups | ForEach-Object { "`t$_" }) -join "`n"
    }

    @"
       Enabled: $(& $val $SelectedItem.Enabled)
     LockedOut: $(& $val $SelectedItem.LockedOut)
    EmployeeID: $(& $val $SelectedItem.EmployeeID)
SamAccountName: $(& $val $SelectedItem.SamAccountName)
     GivenName: $(& $val $SelectedItem.GivenName)
    MiddleName: $(& $val $SelectedItem.MiddleName)
       Surname: $(& $val $SelectedItem.Surname)
   DisplayName: $(& $val $SelectedItem.DisplayName)
  EmailAddress: $(& $val $SelectedItem.EmailAddress)
         Title: $(& $val $SelectedItem.Title)
    Department: $(& $val $SelectedItem.Department)
        Office: $(& $val $SelectedItem.Office)
       Manager: $(& $val $SelectedItem.Manager)

UPN: $(& $val $SelectedItem.UPN)
 DN: $(& $val $SelectedItem.DN)

MemberOf:
$memberOfBlock
"@
}


function Get-GroupNamesFromDN {
    param([string[]]$MemberOfDns)

    if (-not $MemberOfDns) { return @() }

    $names = foreach ($dn in $MemberOfDns) {
        if ([string]::IsNullOrWhiteSpace($dn)) { continue }

        # DN example: CN=Some Group,OU=...,DC=...
        if ($dn -match '^CN=([^,]+),') { $matches[1] }
        else { $dn }
    }

    $names | Sort-Object -Unique
}

function Escape-LdapValue {
    param([string]$Value)
    if ($null -eq $Value) { return "" }

    # Minimal LDAP escaping for common special chars.
    # NOTE: AD's -LDAPFilter is fairly forgiving, but this helps avoid surprises.
    $Value `
        -replace '\\', '\5c' `
        -replace '\*', '\2a' `
        -replace '\(', '\28' `
        -replace '\)', '\29' `
        -replace "`0", '\00'
}

# Function to search AD users
# ---------- Improved search function (replace yours) ----------

function Search-ADUsers {
    param(
        [Parameter(Mandatory)]
        [string]$SearchTerm,

        [int]$MaxResults = 200
    )

    $stRaw = $SearchTerm.Trim()
    if ([string]::IsNullOrWhiteSpace($stRaw)) { return }

    # UI busy state (prevents "feels hung")
    $searchButton.IsEnabled = $false
    $window.Cursor = [System.Windows.Input.Cursors]::Wait

    try {
        $st = Escape-LdapValue $stRaw

        Set-Status "Searching for '$stRaw' ..."
        $managerCache = @{}

        # Decide search strategy based on your workflow
        $ldapFiltersToTry = New-Object System.Collections.Generic.List[string]

        if ($stRaw -match '^\d+$') {
            # EmployeeID exact
            $ldapFiltersToTry.Add("(employeeID=$st)")
        }
        elseif ($stRaw -match '^\S+@\S+\.\S+$') {
            # Email exact
            $ldapFiltersToTry.Add("(mail=$st)")
        }
        else {
            # Login ID exact first (no spaces)
            if ($stRaw -notmatch '\s') {
                $ldapFiltersToTry.Add("(sAMAccountName=$st)")
            }

            # Then your typical fallback: last name / display name
            # Starts-with first (fewer results, faster)
            $ldapFiltersToTry.Add("(sn=$st*)")
            $ldapFiltersToTry.Add("(displayName=*$st*)")

            # If still nothing, contains on surname (broader)
            $ldapFiltersToTry.Add("(sn=*$st*)")
        }

        $properties = @(
            "enabled",
            "lockedOut",
            "employeeID",
            "sAMAccountName",
            "displayName",
            "givenName",
            "middleName",
            "sn",
            "mail",
            "title",
            "department",
            "office",                         # keep your current name
            "physicalDeliveryOfficeName",     # common real AD attribute
            "memberOf",
            "userPrincipalName",
            "distinguishedName",
            "manager"
        )

        $users = @()

        foreach ($inner in $ldapFiltersToTry) {
            $ldap = "(&" +
                    "(objectCategory=person)" +
                    "(objectClass=user)" +
                    "(|$inner)" +
                    ")"

            $users = Get-ADUser -LDAPFilter $ldap -Properties $properties -ResultSetSize $MaxResults -ErrorAction Stop

            # Stop on first strategy that returns something
            if ($users -and $users.Count -gt 0) { break }
        }

        # Build results efficiently (avoid += on arrays)
        $results = [System.Collections.Generic.List[object]]::new()

        foreach ($user in $users) {
            $groups = Get-GroupNamesFromDN $user.MemberOf
            $mgr = Resolve-ManagerName -ManagerDn $user.Manager -Cache $managerCache
            # Handle Office mapping: use your custom Office if present, else physicalDeliveryOfficeName
            $officeValue = $null
            if ($user.PSObject.Properties.Match("Office").Count -gt 0 -and $user.Office) {
                $officeValue = $user.Office
            } elseif ($user.physicalDeliveryOfficeName) {
                $officeValue = $user.physicalDeliveryOfficeName
            }

            $results.Add([PSCustomObject]@{
                Enabled         = $user.Enabled
                LockedOut       = $user.LockedOut
                EmployeeID      = $user.EmployeeID
                SamAccountName  = $user.SamAccountName
                GivenName       = $user.GivenName
                MiddleName      = $user.MiddleName
                Surname         = $user.Surname
                DisplayName     = $user.DisplayName
                EmailAddress    = $user.mail
                Title           = $user.Title
                Department      = $user.Department
                Office          = $officeValue
                Manager         = $mgr

                # Tooltip + clipboard
                MemberOfTooltip = ($groups -join "`n")
                MemberOfGroups  = $groups

                # Optional handy fields (not shown, but useful for copy/escalations)
                UPN             = $user.UserPrincipalName
                DN              = $user.DistinguishedName
            })
        }

        $userGrid.ItemsSource = $results

        if ($results.Count -gt 0) {
            $userGrid.SelectedIndex = 0
            $userGrid.ScrollIntoView($userGrid.SelectedItem)
            Set-Status "$($results.Count) result(s). First row selected."
        } else {
            Set-Status "No matches for '$stRaw'."
        }


        # Quick feedback without changing XAML
        $window.Title = "AD User Search — $($results.Count) result(s)"
        if ($results.Count -eq $MaxResults) {
            # Let you know results were capped
            Set-Status "Showing the first $MaxResults results. Refine your search to narrow it down."
        }
    }

    catch {
        $msg = $_.Exception.Message
        Set-Status "Error searching AD users: $msg"
    }

    finally {
        $window.Cursor = $null
        $searchButton.IsEnabled = $true
    }
}

# Button click event
$searchButton.Add_Click({ $t = $searchBox.Text.Trim(); if ($t) { Search-ADUsers -SearchTerm $t } })

# SearchBox KeyDown event to trigger search on Enter key
$searchBox.Add_KeyDown({ param($sender, $e); if ($e.Key -eq [System.Windows.Input.Key]::Enter) { $t = $searchBox.Text.Trim(); if ($t) { Search-ADUsers -SearchTerm $t } } })


# Expanded right-click menu. Each menu is attached to its own DataGridRow.
# MenuItem.Tag holds the action; ContextMenu.Tag identifies the clicked row.
$copyContextMenuHandler = {
    param($sender, $args)

    $contextMenu = $sender.Parent
    if ($null -eq $contextMenu) { return }

    $clickedRow = $contextMenu.Tag
    if ($null -eq $clickedRow) { return }

    $selectedUser = $clickedRow.Item
    if ($null -eq $selectedUser -or
        $selectedUser -eq [System.Windows.Data.CollectionView]::NewItemPlaceholder) { return }

    $userGrid.SelectedItem = $selectedUser
    $action = [string]$sender.Tag
    $label = [string]$sender.Header

    switch ($action) {
        'TicketBlock' {
            $value = New-TicketBlockText -SelectedItem $selectedUser
        }
        'Groups' {
            $value = ($selectedUser.MemberOfGroups | Sort-Object) -join "`r`n"
        }
        default {
            $value = [string]$selectedUser.$action
        }
    }

    if ([string]::IsNullOrWhiteSpace($value)) {
        Set-Status "No value available for $label."
        return
    }

    if (Set-ClipboardTextSafe -Text $value) {
        Set-Status "Copied $label for $($selectedUser.SamAccountName)."
    }
}

$userGrid.Add_LoadingRow({
    param($sender, $e)

    $menu = New-Object System.Windows.Controls.ContextMenu
    $menu.Tag = $e.Row

    # Select the row the user right-clicked (not the previously selected row).
    $menu.Add_Opened({
        param($sender, $args)
        $row = $sender.Tag
        if ($null -ne $row -and $null -ne $row.Item) {
            $userGrid.SelectedItem = $row.Item
        }
    })

    $menuOptions = @(
        @{ Label = 'Copy SAM Account Name'; Action = 'SamAccountName' }
        @{ Label = 'Copy Employee ID';      Action = 'EmployeeID' }
        @{ Label = 'Copy Display Name';      Action = 'DisplayName' }
        @{ Label = 'Copy Email Address';     Action = 'EmailAddress' }
        @{ Label = 'Copy User Principal Name (UPN)'; Action = 'UPN' }
        @{ Separator = $true }
        @{ Label = 'Copy Ticket Block';     Action = 'TicketBlock' }
        @{ Label = 'Copy Groups Only';      Action = 'Groups' }
    )

    foreach ($option in $menuOptions) {
        if ($option.ContainsKey('Separator')) {
            [void]$menu.Items.Add((New-Object System.Windows.Controls.Separator))
            continue
        }

        $item = New-Object System.Windows.Controls.MenuItem
        $item.Header = $option.Label
        $item.Tag = $option.Action
        $item.Add_Click($copyContextMenuHandler)
        [void]$menu.Items.Add($item)
    }

    $e.Row.ContextMenu = $menu
})

$userGrid.Add_MouseDoubleClick({
    $selectedItem = $userGrid.SelectedItem
    if ($selectedItem) {
        $text = New-TicketBlockText -SelectedItem $selectedItem
        if (Set-ClipboardTextSafe -Text $text) {
            Set-Status "Copied ticket block for $($selectedItem.SamAccountName)."
        }
    }
})

$userGrid.Add_PreviewKeyDown({
    param($sender, $e)

    if ($e.Key -eq [System.Windows.Input.Key]::C -and
        ([System.Windows.Input.Keyboard]::Modifiers -band [System.Windows.Input.ModifierKeys]::Control)) {

        $selectedItem = $userGrid.SelectedItem
        if ($selectedItem) {
            $text = New-TicketBlockText -SelectedItem $selectedItem
            [void](Set-ClipboardTextSafe -Text $text)
            $e.Handled = $true
        }
    }
})

# Copy Ticket Block button
$copyTicketButton.Add_Click({
    $selectedItem = $userGrid.SelectedItem
    if (-not $selectedItem) {
        Set-Status "Select a user row first."
        return
    }

    $text = New-TicketBlockText -SelectedItem $selectedItem
    if (Set-ClipboardTextSafe -Text $text) {
        Set-Status "Copied ticket block for $($selectedItem.SamAccountName)."
    }
})

# Copy Groups Only button
$copyGroupsButton.Add_Click({
    $selectedItem = $userGrid.SelectedItem
    if (-not $selectedItem) {
        Set-Status "Select a user row first."
        return
    }

    $groupsText = ""
    if ($selectedItem.MemberOfGroups) {
        $groupsText = ($selectedItem.MemberOfGroups | Sort-Object) -join "`r`n"
    }

    if (Set-ClipboardTextSafe -Text $groupsText) {
        Set-Status "Groups copied to clipboard."
    }
})

$window.Add_ContentRendered({
    $searchBox.Focus()
})

# Show the window
$window.ShowDialog() | Out-Null
