param(
    [ValidateSet("Eye", "Body", "Both")]
    [string]$Test
)

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Windows.Forms

Add-Type @"
using System;
using System.Runtime.InteropServices;

public static class UserInput {
    [StructLayout(LayoutKind.Sequential)]
    private struct LASTINPUTINFO {
        public uint cbSize;
        public uint dwTime;
    }

    [DllImport("user32.dll")]
    private static extern bool GetLastInputInfo(ref LASTINPUTINFO inputInfo);

    public static uint GetLastInputTickCount() {
        LASTINPUTINFO inputInfo = new LASTINPUTINFO();
        inputInfo.cbSize = (uint)Marshal.SizeOf(inputInfo);
        return GetLastInputInfo(ref inputInfo) ? inputInfo.dwTime : 0;
    }

    public static uint GetIdleMilliseconds() {
        uint lastInput = GetLastInputTickCount();
        return unchecked((uint)Environment.TickCount - lastInput);
    }
}
"@

function ConvertFrom-CodePoints {
    param([int[]]$CodePoints)
    return -join ($CodePoints | ForEach-Object { [char]$_ })
}

$uiText = @{
    EyeTitle = ConvertFrom-CodePoints @(35813,35753,30524,30555,20241,24687,20102)
    EyeMessage = ConvertFrom-CodePoints @(35831,26395,21521,36828,22788,65292,25918,26494,30524,30555)
    BodyTitle = ConvertFrom-CodePoints @(35813,31163,24320,30005,33041,20241,24687,20102)
    BodyMessage = ConvertFrom-CodePoints @(36215,36523,27963,21160,19968,19979,65292,25918,26494,32937,39048,21644,36523,20307)
    BothTitle = ConvertFrom-CodePoints @(35813,20241,24687,19968,19979,20102)
    BothMessage = ConvertFrom-CodePoints @(26395,21521,36828,22788,24182,36215,36523,27963,21160,65292,35753,30524,30555,21644,36523,20307,37117,20241,24687)
    WindowTitle = ConvertFrom-CodePoints @(20241,24687,25552,37266)
    DoneButton = ConvertFrom-CodePoints @(25105,20241,24687,22909,20102)
    WidgetTitle = ConvertFrom-CodePoints @(25252,30524,19982,20241,24687)
    Running = ConvertFrom-CodePoints @(36816,34892,20013)
    EyeNext = ConvertFrom-CodePoints @(36317,31163,25252,30524,25552,37266)
    BodyNext = ConvertFrom-CodePoints @(36317,31163,36523,20307,20241,24687)
    WindowTopmost = ConvertFrom-CodePoints @(31383,21475,32622,39030)
    EyeIntervalLabel = ConvertFrom-CodePoints @(25252,30524,38388,38548,40,109,105,110,41)
    EyeDurationLabel = ConvertFrom-CodePoints @(25252,30524,26102,38271,40,115,101,99,41)
    BodyIntervalLabel = ConvertFrom-CodePoints @(20241,24687,38388,38548,40,109,105,110,41)
    BodyDurationLabel = ConvertFrom-CodePoints @(20241,24687,26102,38271,40,109,105,110,41)
    SaveSettings = ConvertFrom-CodePoints @(20445,23384,35774,32622)
}

$settingsPath = Join-Path $PSScriptRoot "rest-reminder-settings.json"

function Get-DefaultReminderSettings {
    return [ordered]@{
        EyeIntervalMinutes = 20
        EyeDurationSeconds = 20
        BodyIntervalMinutes = 60
        BodyDurationMinutes = 5
        IdlePauseMinutes = 1
    }
}

function Normalize-ReminderSettings {
    param($Settings)

    $defaults = Get-DefaultReminderSettings
    $normalized = Get-DefaultReminderSettings

    foreach ($name in @("EyeIntervalMinutes", "EyeDurationSeconds", "BodyIntervalMinutes", "BodyDurationMinutes", "IdlePauseMinutes")) {
        $hasValue = $false
        $rawValue = $null

        if ($Settings -is [System.Collections.IDictionary] -and $Settings.Contains($name)) {
            $hasValue = $true
            $rawValue = $Settings[$name]
        }
        elseif ($Settings -and $Settings.PSObject.Properties.Name -contains $name) {
            $hasValue = $true
            $rawValue = $Settings.$name
        }

        if ($hasValue) {
            $value = [double]$rawValue
            if ($value -gt 0) {
                $normalized[$name] = $value
            }
        }
    }

    if (($normalized.BodyDurationMinutes * 60) -gt ($normalized.BodyIntervalMinutes * 60)) {
        $normalized.BodyDurationMinutes = $defaults.BodyDurationMinutes
    }
    if ($normalized.EyeDurationSeconds -gt ($normalized.EyeIntervalMinutes * 60)) {
        $normalized.EyeDurationSeconds = $defaults.EyeDurationSeconds
    }

    return $normalized
}

function Load-ReminderSettings {
    if (Test-Path -LiteralPath $settingsPath) {
        try {
            return Normalize-ReminderSettings (Get-Content -LiteralPath $settingsPath -Raw | ConvertFrom-Json)
        }
        catch {
            return Get-DefaultReminderSettings
        }
    }

    return Get-DefaultReminderSettings
}

function Save-ReminderSettings {
    $global:RestReminderSettings | ConvertTo-Json | Set-Content -LiteralPath $settingsPath -Encoding UTF8
}

function Get-EyeIntervalTimeSpan {
    return [TimeSpan]::FromMinutes([double]$global:RestReminderSettings.EyeIntervalMinutes)
}

function Get-EyeDurationSeconds {
    return [int]([double]$global:RestReminderSettings.EyeDurationSeconds)
}

function Get-BodyIntervalTimeSpan {
    return [TimeSpan]::FromMinutes([double]$global:RestReminderSettings.BodyIntervalMinutes)
}

function Get-BodyDurationSeconds {
    return [int]([double]$global:RestReminderSettings.BodyDurationMinutes * 60)
}

function Get-IdlePauseMilliseconds {
    return [int]([double]$global:RestReminderSettings.IdlePauseMinutes * 60000)
}

$global:RestReminderSettings = Load-ReminderSettings

$global:RestReminderState = @{
    NextEyeReminder = (Get-Date).Add((Get-EyeIntervalTimeSpan))
    NextBodyReminder = (Get-Date).Add((Get-BodyIntervalTimeSpan))
    ActiveWindow = $null
    CountdownTimer = $null
    IsSessionInactive = $false
    IsWaitingForActivity = $false
    LastInputTickCount = [UserInput]::GetLastInputTickCount()
    PendingRestType = $null
    FrozenBodyRemaining = Get-BodyIntervalTimeSpan
    IsUserIdle = $false
    IdleResetApplied = $false
    LastActivityCheck = Get-Date
}

function Reset-ReminderTimers {
    $now = Get-Date
    $global:RestReminderState.NextEyeReminder = $now.Add((Get-EyeIntervalTimeSpan))
    $global:RestReminderState.NextBodyReminder = $now.Add((Get-BodyIntervalTimeSpan))
}

function Reset-IdleTracking {
    $global:RestReminderState.IsUserIdle = $false
    $global:RestReminderState.IdleResetApplied = $false
    $global:RestReminderState.LastActivityCheck = Get-Date
}

function Wait-ForUserActivity {
    param(
        [Parameter(Mandatory)]
        [ValidateSet("Eye", "Body", "Both")]
        [string]$RestType
    )

    $global:RestReminderState.IsWaitingForActivity = $true
    $global:RestReminderState.LastInputTickCount = [UserInput]::GetLastInputTickCount()
    $global:RestReminderState.PendingRestType = $RestType

    if ($RestType -eq "Eye") {
        $remaining = $global:RestReminderState.NextBodyReminder - (Get-Date)
        $global:RestReminderState.FrozenBodyRemaining = if ($remaining -gt [TimeSpan]::Zero) {
            $remaining
        }
        else {
            [TimeSpan]::Zero
        }
    }
}

function Show-RestReminder {
    param(
        [Parameter(Mandatory)]
        [ValidateSet("Eye", "Body", "Both")]
        [string]$Type
    )

    if ($global:RestReminderState.ActiveWindow) {
        return
    }

    switch ($Type) {
        "Eye" {
            $title = $uiText.EyeTitle
            $message = $uiText.EyeMessage
            $durationSeconds = Get-EyeDurationSeconds
            $accent = "#3B82F6"
        }
        "Body" {
            $title = $uiText.BodyTitle
            $message = $uiText.BodyMessage
            $durationSeconds = Get-BodyDurationSeconds
            $accent = "#10B981"
        }
        "Both" {
            $title = $uiText.BothTitle
            $message = $uiText.BothMessage
            $durationSeconds = Get-BodyDurationSeconds
            $accent = "#8B5CF6"
        }
    }

    [xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        Title="$($uiText.WindowTitle)"
        Width="520"
        Height="310"
        WindowStartupLocation="CenterScreen"
        WindowStyle="None"
        ResizeMode="NoResize"
        ShowInTaskbar="False"
        Topmost="True"
        Background="Transparent"
        AllowsTransparency="True">
    <Border CornerRadius="24" Background="#FFFDFB" BorderBrush="$accent" BorderThickness="3" Padding="36">
        <Border.Effect>
            <DropShadowEffect BlurRadius="28" ShadowDepth="4" Opacity="0.35"/>
        </Border.Effect>
        <Grid>
            <Grid.RowDefinitions>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="*"/>
                <RowDefinition Height="Auto"/>
            </Grid.RowDefinitions>
            <TextBlock Text="$title"
                       FontFamily="Microsoft YaHei UI"
                       FontSize="30"
                       FontWeight="Bold"
                       Foreground="#172033"
                       HorizontalAlignment="Center"/>
            <StackPanel Grid.Row="1" VerticalAlignment="Center">
                <TextBlock Text="$message"
                           FontFamily="Microsoft YaHei UI"
                           FontSize="20"
                           Foreground="#445069"
                           TextAlignment="Center"
                           TextWrapping="Wrap"
                           Margin="0,8,0,16"/>
                <TextBlock Name="CountdownText"
                           FontFamily="Microsoft YaHei UI"
                           FontSize="42"
                           FontWeight="SemiBold"
                           Foreground="$accent"
                           HorizontalAlignment="Center"/>
            </StackPanel>
            <Button Name="DoneButton"
                    Grid.Row="2"
                    Content="$($uiText.DoneButton)"
                    Width="180"
                    Height="46"
                    FontFamily="Microsoft YaHei UI"
                    FontSize="17"
                    Foreground="White"
                    Background="$accent"
                    BorderThickness="0"
                    Cursor="Hand"
                    HorizontalAlignment="Center"/>
        </Grid>
    </Border>
</Window>
"@

    $reader = New-Object System.Xml.XmlNodeReader $xaml
    $window = [Windows.Markup.XamlReader]::Load($reader)
    $countdownText = $window.FindName("CountdownText")
    $doneButton = $window.FindName("DoneButton")
    $global:RestReminderState.ActiveWindow = $window
    $countdownState = @{ Remaining = $durationSeconds }

    $windowTimer = New-Object Windows.Threading.DispatcherTimer
    $windowTimer.Interval = [TimeSpan]::FromSeconds(1)
    $global:RestReminderState.CountdownTimer = $windowTimer

    $updateCountdown = {
        $minutes = [int][math]::Floor($countdownState.Remaining / 60)
        $seconds = [int]($countdownState.Remaining % 60)
        $countdownText.Text = "{0:00}:{1:00}" -f $minutes, $seconds
    }.GetNewClosure()

    & $updateCountdown

    $windowTimer.Add_Tick({
        $countdownState.Remaining--
        & $updateCountdown
        if ($countdownState.Remaining -le 0) {
            $windowTimer.Stop()
            $window.Close()
        }
    }.GetNewClosure())

    $doneButton.Add_Click({
        $windowTimer.Stop()
        $window.Close()
    }.GetNewClosure())

    $window.Add_Closed({
        $windowTimer.Stop()
        $global:RestReminderState.ActiveWindow = $null
        if ($global:RestReminderState.CountdownTimer -eq $windowTimer) {
            $global:RestReminderState.CountdownTimer = $null
        }
        Wait-ForUserActivity -RestType $Type
    }.GetNewClosure())

    $window.Add_ContentRendered({
        $window.Activate()
        $window.Focus()
        $windowTimer.Start()
        [System.Media.SystemSounds]::Asterisk.Play()
    }.GetNewClosure())

    $window.Show()
}

function Show-StatusWidget {
    [xml]$widgetXaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        Title="$($uiText.WidgetTitle)"
        Width="330"
        SizeToContent="Height"
        WindowStartupLocation="Manual"
        WindowStyle="None"
        ResizeMode="NoResize"
        ShowInTaskbar="False"
        Topmost="False"
        Background="Transparent"
        AllowsTransparency="True">
    <Border CornerRadius="18" Background="#F7FFFFFF" BorderBrush="#D8E1F0" BorderThickness="1" Padding="20">
        <Border.Effect>
            <DropShadowEffect BlurRadius="18" ShadowDepth="3" Opacity="0.25"/>
        </Border.Effect>
        <Grid>
            <Grid.RowDefinitions>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="Auto"/>
            </Grid.RowDefinitions>
            <StackPanel Orientation="Horizontal">
                <Ellipse Name="StatusDot" Width="10" Height="10" Fill="#10B981" Margin="0,0,9,0"/>
                <TextBlock Name="StatusText" Text="$($uiText.Running)" FontFamily="Microsoft YaHei UI"
                           FontSize="13" Foreground="#10B981"/>
            </StackPanel>
            <Grid Grid.Row="1" Margin="0,14,0,8">
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="Auto"/>
                </Grid.ColumnDefinitions>
                <TextBlock Text="$($uiText.EyeNext)" FontFamily="Microsoft YaHei UI"
                           FontSize="16" FontWeight="SemiBold" Foreground="#526078"/>
                <TextBlock Name="EyeTime" Grid.Column="1" Text="20:00" FontFamily="Consolas"
                           FontSize="22" FontWeight="Bold" Foreground="#3B82F6"/>
            </Grid>
            <Grid Grid.Row="2" Margin="0,4,0,14">
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="Auto"/>
                </Grid.ColumnDefinitions>
                <TextBlock Text="$($uiText.BodyNext)" FontFamily="Microsoft YaHei UI"
                           FontSize="16" FontWeight="SemiBold" Foreground="#526078"/>
                <TextBlock Name="BodyTime" Grid.Column="1" Text="60:00" FontFamily="Consolas"
                           FontSize="22" FontWeight="Bold" Foreground="#10B981"/>
            </Grid>
            <Grid Grid.Row="3" Margin="0,2,0,10">
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="72"/>
                </Grid.ColumnDefinitions>
                <Grid.RowDefinitions>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="Auto"/>
                </Grid.RowDefinitions>
                <TextBlock Text="$($uiText.EyeIntervalLabel)" FontFamily="Microsoft YaHei UI" FontSize="12" Foreground="#526078" Margin="0,0,8,4"/>
                <TextBox Name="EyeIntervalTextBox" Grid.Column="1" Height="25" FontFamily="Consolas" FontSize="13" TextAlignment="Center"/>
                <TextBlock Grid.Row="1" Text="$($uiText.EyeDurationLabel)" FontFamily="Microsoft YaHei UI" FontSize="12" Foreground="#526078" Margin="0,0,8,4"/>
                <TextBox Name="EyeDurationTextBox" Grid.Row="1" Grid.Column="1" Height="25" FontFamily="Consolas" FontSize="13" TextAlignment="Center"/>
                <TextBlock Grid.Row="2" Text="$($uiText.BodyIntervalLabel)" FontFamily="Microsoft YaHei UI" FontSize="12" Foreground="#526078" Margin="0,0,8,4"/>
                <TextBox Name="BodyIntervalTextBox" Grid.Row="2" Grid.Column="1" Height="25" FontFamily="Consolas" FontSize="13" TextAlignment="Center"/>
                <TextBlock Grid.Row="3" Text="$($uiText.BodyDurationLabel)" FontFamily="Microsoft YaHei UI" FontSize="12" Foreground="#526078" Margin="0,0,8,6"/>
                <TextBox Name="BodyDurationTextBox" Grid.Row="3" Grid.Column="1" Height="25" FontFamily="Consolas" FontSize="13" TextAlignment="Center"/>
                <Button Name="SaveSettingsButton" Grid.Row="4" Grid.ColumnSpan="2" Content="$($uiText.SaveSettings)" Height="30"
                        FontFamily="Microsoft YaHei UI" FontSize="13" Background="#EEF2F7" BorderThickness="0"/>
            </Grid>
            <CheckBox Name="TopmostCheckBox" Grid.Row="4" Content="$($uiText.WindowTopmost)"
                      FontFamily="Microsoft YaHei UI" FontSize="13" Foreground="#526078"
                      Margin="0,4,0,0" HorizontalAlignment="Right" VerticalAlignment="Center"/>
        </Grid>
    </Border>
</Window>
"@

    $reader = New-Object System.Xml.XmlNodeReader $widgetXaml
    $widget = [Windows.Markup.XamlReader]::Load($reader)
    $eyeTime = $widget.FindName("EyeTime")
    $bodyTime = $widget.FindName("BodyTime")
    $topmostCheckBox = $widget.FindName("TopmostCheckBox")
    $eyeIntervalTextBox = $widget.FindName("EyeIntervalTextBox")
    $eyeDurationTextBox = $widget.FindName("EyeDurationTextBox")
    $bodyIntervalTextBox = $widget.FindName("BodyIntervalTextBox")
    $bodyDurationTextBox = $widget.FindName("BodyDurationTextBox")
    $saveSettingsButton = $widget.FindName("SaveSettingsButton")

    $workArea = [System.Windows.SystemParameters]::WorkArea
    $widget.Left = $workArea.Right - $widget.Width - 18
    $widget.Top = $workArea.Top + 18

    $formatRemaining = {
        param([TimeSpan]$remaining)
        $totalSeconds = [long][math]::Max(0, [math]::Ceiling($remaining.TotalSeconds))
        $minutes = [int][math]::Floor($totalSeconds / 60)
        $seconds = [int]($totalSeconds % 60)
        return "{0:00}:{1:00}" -f $minutes, $seconds
    }

    $widgetTimer = New-Object Windows.Threading.DispatcherTimer
    $widgetTimer.Interval = [TimeSpan]::FromSeconds(1)
    $widgetTimer.Add_Tick({
        if ($global:RestReminderState.IsWaitingForActivity) {
            $eyeTime.Text = & $formatRemaining (Get-EyeIntervalTimeSpan)
            if ($global:RestReminderState.PendingRestType -eq "Eye") {
                $bodyTime.Text = & $formatRemaining $global:RestReminderState.FrozenBodyRemaining
            }
            else {
                $bodyTime.Text = & $formatRemaining (Get-BodyIntervalTimeSpan)
            }
            return
        }

        $now = Get-Date
        $eyeTime.Text = & $formatRemaining ($global:RestReminderState.NextEyeReminder - $now)
        $bodyTime.Text = & $formatRemaining ($global:RestReminderState.NextBodyReminder - $now)
    }.GetNewClosure())

    $refreshSettingsText = {
        $eyeIntervalTextBox.Text = [string]$global:RestReminderSettings.EyeIntervalMinutes
        $eyeDurationTextBox.Text = [string]$global:RestReminderSettings.EyeDurationSeconds
        $bodyIntervalTextBox.Text = [string]$global:RestReminderSettings.BodyIntervalMinutes
        $bodyDurationTextBox.Text = [string]$global:RestReminderSettings.BodyDurationMinutes
    }.GetNewClosure()

    $saveSettingsButton.Add_Click({
        try {
            $eyeInterval = [double]$eyeIntervalTextBox.Text
            $eyeDuration = [double]$eyeDurationTextBox.Text
            $bodyInterval = [double]$bodyIntervalTextBox.Text
            $bodyDuration = [double]$bodyDurationTextBox.Text

            if ($eyeInterval -gt 0 -and $eyeDuration -gt 0 -and $bodyInterval -gt 0 -and $bodyDuration -gt 0) {
                $global:RestReminderSettings.EyeIntervalMinutes = $eyeInterval
                $global:RestReminderSettings.EyeDurationSeconds = $eyeDuration
                $global:RestReminderSettings.BodyIntervalMinutes = $bodyInterval
                $global:RestReminderSettings.BodyDurationMinutes = $bodyDuration
                $global:RestReminderSettings = Normalize-ReminderSettings $global:RestReminderSettings
                Save-ReminderSettings
                Reset-ReminderTimers
                $global:RestReminderState.FrozenBodyRemaining = Get-BodyIntervalTimeSpan
                & $refreshSettingsText
            }
        }
        catch {
            & $refreshSettingsText
        }
    }.GetNewClosure())

    $topmostCheckBox.Add_Checked({
        $widget.Topmost = $true
    }.GetNewClosure())
    $topmostCheckBox.Add_Unchecked({
        $widget.Topmost = $false
    }.GetNewClosure())

    $widget.Add_MouseLeftButtonDown({ $widget.DragMove() }.GetNewClosure())
    $widget.Add_Closed({
        $widgetTimer.Stop()
        $app.Shutdown()
    }.GetNewClosure())
    $widget.Add_ContentRendered({
        & $refreshSettingsText
        $now = Get-Date
        $eyeTime.Text = & $formatRemaining ($global:RestReminderState.NextEyeReminder - $now)
        $bodyTime.Text = & $formatRemaining ($global:RestReminderState.NextBodyReminder - $now)
        $widgetTimer.Start()
    }.GetNewClosure())

    $widget.Show()
}

$app = New-Object Windows.Application
$app.ShutdownMode = [Windows.ShutdownMode]::OnExplicitShutdown

[Microsoft.Win32.SystemEvents]::add_SessionSwitch({
    param($sender, $eventArgs)

    switch ($eventArgs.Reason) {
        ([Microsoft.Win32.SessionSwitchReason]::SessionLock) {
            $global:RestReminderState.IsSessionInactive = $true
            $global:RestReminderState.IsWaitingForActivity = $false
            $global:RestReminderState.PendingRestType = $null
            Reset-ReminderTimers
            Reset-IdleTracking
        }
        ([Microsoft.Win32.SessionSwitchReason]::SessionUnlock) {
            $global:RestReminderState.IsSessionInactive = $false
            $global:RestReminderState.IsWaitingForActivity = $false
            $global:RestReminderState.PendingRestType = $null
            Reset-ReminderTimers
            Reset-IdleTracking
        }
    }
})

[Microsoft.Win32.SystemEvents]::add_PowerModeChanged({
    param($sender, $eventArgs)

    switch ($eventArgs.Mode) {
        ([Microsoft.Win32.PowerModes]::Suspend) {
            $global:RestReminderState.IsSessionInactive = $true
            $global:RestReminderState.IsWaitingForActivity = $false
            $global:RestReminderState.PendingRestType = $null
            Reset-ReminderTimers
            Reset-IdleTracking
        }
        ([Microsoft.Win32.PowerModes]::Resume) {
            $global:RestReminderState.IsSessionInactive = $false
            $global:RestReminderState.IsWaitingForActivity = $false
            $global:RestReminderState.PendingRestType = $null
            Reset-ReminderTimers
            Reset-IdleTracking
        }
    }
})

$checkTimer = New-Object Windows.Threading.DispatcherTimer
$checkTimer.Interval = [TimeSpan]::FromSeconds(1)
$checkTimer.Add_Tick({
    $now = Get-Date
    $elapsedSinceCheck = $now - $global:RestReminderState.LastActivityCheck
    $global:RestReminderState.LastActivityCheck = $now

    if ($global:RestReminderState.IsSessionInactive) {
        return
    }

    if ($global:RestReminderState.ActiveWindow) {
        return
    }

    if ($global:RestReminderState.IsWaitingForActivity) {
        $lastInputTickCount = [UserInput]::GetLastInputTickCount()
        if ($lastInputTickCount -eq $global:RestReminderState.LastInputTickCount) {
            if ([UserInput]::GetIdleMilliseconds() -ge 300000) {
                $global:RestReminderState.PendingRestType = "Both"
            }
            return
        }

        $global:RestReminderState.IsWaitingForActivity = $false
        $global:RestReminderState.LastInputTickCount = $lastInputTickCount
        if ($global:RestReminderState.PendingRestType -eq "Eye") {
            $global:RestReminderState.NextEyeReminder = $now.Add((Get-EyeIntervalTimeSpan))
            $global:RestReminderState.NextBodyReminder = $now.Add($global:RestReminderState.FrozenBodyRemaining)
        }
        else {
            Reset-ReminderTimers
        }
        $global:RestReminderState.PendingRestType = $null
        Reset-IdleTracking
        return
    }

    $idleMilliseconds = [UserInput]::GetIdleMilliseconds()
    if ($idleMilliseconds -ge (Get-IdlePauseMilliseconds)) {
        if (-not $global:RestReminderState.IsUserIdle) {
            # Only pause time observed by this process. The OS idle duration may
            # include minutes from before the reminder app was started.
            $global:RestReminderState.NextEyeReminder = $global:RestReminderState.NextEyeReminder.Add($elapsedSinceCheck)
            $global:RestReminderState.NextBodyReminder = $global:RestReminderState.NextBodyReminder.Add($elapsedSinceCheck)
            $global:RestReminderState.IsUserIdle = $true
        }
        else {
            $global:RestReminderState.NextEyeReminder = $global:RestReminderState.NextEyeReminder.Add($elapsedSinceCheck)
            $global:RestReminderState.NextBodyReminder = $global:RestReminderState.NextBodyReminder.Add($elapsedSinceCheck)
        }

        if ($idleMilliseconds -ge 300000 -and -not $global:RestReminderState.IdleResetApplied) {
            Reset-ReminderTimers
            $global:RestReminderState.IdleResetApplied = $true
        }
        return
    }

    $global:RestReminderState.IsUserIdle = $false
    $global:RestReminderState.IdleResetApplied = $false

    $eyeDue = $now -ge $global:RestReminderState.NextEyeReminder
    $bodyDue = $now -ge $global:RestReminderState.NextBodyReminder

    while ($now -ge $global:RestReminderState.NextEyeReminder) {
        $global:RestReminderState.NextEyeReminder = $global:RestReminderState.NextEyeReminder.Add((Get-EyeIntervalTimeSpan))
    }
    while ($now -ge $global:RestReminderState.NextBodyReminder) {
        $global:RestReminderState.NextBodyReminder = $global:RestReminderState.NextBodyReminder.Add((Get-BodyIntervalTimeSpan))
    }

    if ($bodyDue -and $eyeDue) {
        Show-RestReminder -Type Both
    }
    elseif ($bodyDue) {
        Show-RestReminder -Type Body
    }
    elseif ($eyeDue) {
        Show-RestReminder -Type Eye
    }
})

$checkTimer.Start()

if ($Test) {
    Show-RestReminder -Type $Test
}
else {
    Show-StatusWidget
}

$app.Run()
