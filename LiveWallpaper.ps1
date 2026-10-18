# LiveWallpaper.ps1
# Windows 10/11 | Windows PowerShell 5.1
# Escape closes the dashboard. F11 toggles fullscreen.
# Reads local system data; no downloads or administrator access required.

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase
Add-Type -AssemblyName System.Windows.Forms

Add-Type @'
using System;
using System.Runtime.InteropServices;

public static class HudSensors
{
    [DllImport("kernel32.dll")]
    public static extern bool GetSystemTimes(
        out long idle, out long kernel, out long user);

    [StructLayout(LayoutKind.Sequential)]
    public class Memory
    {
        public uint length =
            (uint)Marshal.SizeOf(typeof(Memory));
        public uint load;
        public ulong totalPhys, availPhys;
        public ulong totalPage, availPage;
        public ulong totalVirtual, availVirtual;
        public ulong availExtended;
    }

    [DllImport("kernel32.dll")]
    public static extern bool GlobalMemoryStatusEx(
        [In, Out] Memory memory);
}
'@

[xml]$layout = @'
<Window
 xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
 xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
 Title="Latitude System HUD"
 Background="#03080D"
 WindowStyle="None"
 WindowState="Maximized">
 <Viewbox Stretch="Uniform">
  <Canvas Width="1000" Height="700" Background="#03080D">
   <TextBlock Canvas.Left="45" Canvas.Top="25"
    Text="LATITUDE 5590 // SYSTEM TELEMETRY"
    FontFamily="Consolas" FontSize="20" Foreground="#22EADA"/>

   <TextBlock x:Name="Clock" Canvas.Left="40" Canvas.Top="55"
    FontFamily="Consolas" FontSize="88" Foreground="#22EADA"/>

   <TextBlock x:Name="Date" Canvas.Left="620" Canvas.Top="90"
    FontFamily="Consolas" FontSize="22" Foreground="#599BCD"/>

   <Line X1="45" Y1="170" X2="955" Y2="170"
    Stroke="#216390" StrokeThickness="2"/>

   <Canvas x:Name="Rings"/>

   <TextBlock Canvas.Left="440" Canvas.Top="305"
    Text="CPU LOAD" FontFamily="Consolas"
    FontSize="22" Foreground="#73AEC4"/>

   <TextBlock x:Name="Cpu" Canvas.Left="412" Canvas.Top="335"
    FontFamily="Consolas" FontSize="60" Foreground="#22EADA"/>

   <TextBlock Canvas.Left="436" Canvas.Top="416"
    Text="LIVE SENSORS" FontFamily="Consolas"
    FontSize="16" Foreground="#599BCD"/>

   <TextBlock Canvas.Left="45" Canvas.Top="260"
    Text="POWER REMAINING" FontFamily="Consolas"
    FontSize="18" Foreground="#73AEC4"/>

   <TextBlock x:Name="Battery" Canvas.Left="45" Canvas.Top="295"
    FontFamily="Consolas" FontSize="48" Foreground="#22EADA"/>

   <TextBlock x:Name="Power" Canvas.Left="45" Canvas.Top="360"
    FontFamily="Consolas" FontSize="17" Foreground="#599BCD"/>

   <TextBlock Canvas.Left="755" Canvas.Top="260"
    Text="MEMORY" FontFamily="Consolas"
    FontSize="18" Foreground="#73AEC4"/>

   <TextBlock x:Name="Ram" Canvas.Left="755" Canvas.Top="295"
    FontFamily="Consolas" FontSize="48" Foreground="#22EADA"/>

   <TextBlock x:Name="RamDetail" Canvas.Left="755" Canvas.Top="360"
    FontFamily="Consolas" FontSize="15" Foreground="#599BCD"/>

   <TextBlock x:Name="Disk" Canvas.Left="45" Canvas.Top="555"
    FontFamily="Consolas" FontSize="20" Foreground="#22EADA"/>

   <TextBlock x:Name="Network" Canvas.Left="45" Canvas.Top="595"
    FontFamily="Consolas" FontSize="20" Foreground="#22EADA"/>

   <Line X1="45" Y1="640" X2="955" Y2="640"
    Stroke="#216390" StrokeThickness="2"/>

   <TextBlock x:Name="Status" Canvas.Left="45" Canvas.Top="660"
    Text="LOCAL TELEMETRY // ESC: CLOSE // F11: FULLSCREEN"
    FontFamily="Consolas" FontSize="14" Foreground="#599BCD"/>
  </Canvas>
 </Viewbox>
</Window>
'@

$reader = New-Object System.Xml.XmlNodeReader $layout
$window = [Windows.Markup.XamlReader]::Load($reader)

$ui = @{}
@(
    'Clock', 'Date', 'Rings', 'Cpu', 'Battery',
    'Power', 'Ram', 'RamDetail', 'Disk', 'Network', 'Status'
) | ForEach-Object {
    $ui[$_] = $window.FindName($_)
}

$cyan = [Windows.Media.Brushes]::Turquoise
$dim = New-Object Windows.Media.SolidColorBrush (
    [Windows.Media.ColorConverter]::ConvertFromString('#123B50')
)

# CPU ring: 100 independently illuminated segments.
$segments = @()

for ($i = 0; $i -lt 100; $i++) {
    $angle = ($i * 3.6 - 90) * [Math]::PI / 180
    $line = New-Object Windows.Shapes.Line
    $line.X1 = 500 + 154 * [Math]::Cos($angle)
    $line.Y1 = 370 + 154 * [Math]::Sin($angle)
    $line.X2 = 500 + 176 * [Math]::Cos($angle)
    $line.Y2 = 370 + 176 * [Math]::Sin($angle)
    $line.StrokeThickness = 5
    $line.Stroke = $dim
    [void]$ui.Rings.Children.Add($line)
    $segments += $line
}

foreach ($radius in @(125, 140, 187)) {
    $ring = New-Object Windows.Shapes.Ellipse
    $ring.Width = $radius * 2
    $ring.Height = $radius * 2
    $ring.Stroke = '#2365A0'
    $ring.StrokeThickness = 2

    [Windows.Controls.Canvas]::SetLeft($ring, 500 - $radius)
    [Windows.Controls.Canvas]::SetTop($ring, 370 - $radius)
    [void]$ui.Rings.Children.Add($ring)
}

# Decorative rotating scan line.
$scan = New-Object Windows.Shapes.Line
$scan.X1 = 500
$scan.Y1 = 243
$scan.X2 = 500
$scan.Y2 = 263
$scan.Stroke = $cyan
$scan.StrokeThickness = 5

$rotation = New-Object Windows.Media.RotateTransform
$rotation.CenterX = 500
$rotation.CenterY = 370
$scan.RenderTransform = $rotation
[void]$ui.Rings.Children.Add($scan)

$animation = New-Object Windows.Media.Animation.DoubleAnimation
$animation.From = 0
$animation.To = 360
$animation.Duration = [Windows.Duration]::new(
    [TimeSpan]::FromSeconds(8)
)
$animation.RepeatBehavior =
    [Windows.Media.Animation.RepeatBehavior]::Forever

$rotation.BeginAnimation(
    [Windows.Media.RotateTransform]::AngleProperty,
    $animation
)

$script:previousIdle = 0L
$script:previousTotal = 0L
$script:previousAdapters = @{}
$script:previousTime = [DateTime]::UtcNow

function Update-Dashboard {
    $now = Get-Date
    $ui.Clock.Text = $now.ToString('HH:mm:ss')
    $ui.Date.Text = $now.ToString(
        "dddd`nyyyy / MM / dd"
    ).ToUpperInvariant()

    # CPU usage across all logical processors.
    $idle = 0L
    $kernel = 0L
    $user = 0L

    if ([HudSensors]::GetSystemTimes(
        [ref]$idle, [ref]$kernel, [ref]$user
    )) {
        $total = $kernel + $user
        $difference = $total - $script:previousTotal

        if ($script:previousTotal -gt 0 -and $difference -gt 0) {
            $usage = 100 * (
                1 - ($idle - $script:previousIdle) / $difference
            )
            $usage = [Math]::Round(
                [Math]::Max(0, [Math]::Min(100, $usage))
            )

            $ui.Cpu.Text = '{0,3}%' -f $usage

            for ($i = 0; $i -lt 100; $i++) {
                if ($i -lt $usage) {
                    $segments[$i].Stroke = $cyan
                } else {
                    $segments[$i].Stroke = $dim
                }
            }
        }

        $script:previousIdle = $idle
        $script:previousTotal = $total
    }

    # Physical memory.
    $memory = New-Object HudSensors+Memory
    if ([HudSensors]::GlobalMemoryStatusEx($memory)) {
        $ui.Ram.Text = "$($memory.load)%"
        $used = ($memory.totalPhys - $memory.availPhys) / 1GB
        $totalRam = $memory.totalPhys / 1GB
        $ui.RamDetail.Text = '{0:N1} / {1:N1} GB' -f $used, $totalRam
    }

    # Battery and AC power.
    $power = [Windows.Forms.SystemInformation]::PowerStatus
    $batteryState = [int]$power.BatteryChargeStatus

    if (
        $batteryState -ne 128 -and
        $batteryState -ne 255 -and
        $power.BatteryLifePercent -ge 0 -and
        $power.BatteryLifePercent -le 1
    ) {
        $ui.Battery.Text = '{0:0}%' -f (
            $power.BatteryLifePercent * 100
        )
    } else {
        $ui.Battery.Text = 'N/A'
    }

    $ui.Power.Text = "AC POWER: $($power.PowerLineStatus)"

    # Windows system drive.
    $root = [IO.Path]::GetPathRoot($env:SystemRoot)
    $drive = New-Object IO.DriveInfo $root
    $ui.Disk.Text = '{0} FREE: {1:N1} / {2:N1} GB' -f (
        $drive.Name,
        ($drive.AvailableFreeSpace / 1GB),
        ($drive.TotalSize / 1GB)
    )

    # Network throughput, sampled separately for each adapter.
    $timestamp = [DateTime]::UtcNow
    $elapsed = ($timestamp - $script:previousTime).TotalSeconds
    $current = @{}
    $received = 0.0
    $sent = 0.0

    foreach (
        $adapter in
        [Net.NetworkInformation.NetworkInterface]::GetAllNetworkInterfaces()
    ) {
        if (
            $adapter.OperationalStatus -ne 'Up' -or
            $adapter.NetworkInterfaceType -eq 'Loopback'
        ) {
            continue
        }

        $stats = $adapter.GetIPv4Statistics()
        $current[$adapter.Id] = @(
            $stats.BytesReceived, $stats.BytesSent
        )

        if (
            $script:previousAdapters.ContainsKey($adapter.Id) -and
            $elapsed -gt 0
        ) {
            $old = $script:previousAdapters[$adapter.Id]
            $received += [Math]::Max(
                0, ($stats.BytesReceived - $old[0]) / $elapsed
            )
            $sent += [Math]::Max(
                0, ($stats.BytesSent - $old[1]) / $elapsed
            )
        }
    }

    $script:previousAdapters = $current
    $script:previousTime = $timestamp

    $ui.Network.Text = 'NETWORK  RX {0:N1} KB/s   TX {1:N1} KB/s' -f (
        ($received / 1KB), ($sent / 1KB)
    )
}

$window.Add_KeyDown({
    if ($_.Key -eq 'Escape') {
        $window.Close()
    }

    if ($_.Key -eq 'F11') {
        if ($window.WindowStyle -eq 'None') {
            $window.WindowState = 'Normal'
            $window.WindowStyle = 'SingleBorderWindow'
            $window.Width = 1050
            $window.Height = 780
        } else {
            $window.WindowStyle = 'None'
            $window.WindowState = 'Maximized'
        }
    }
})

$timer = New-Object Windows.Threading.DispatcherTimer
$timer.Interval = [TimeSpan]::FromSeconds(1)

$timer.Add_Tick({
    try {
        Update-Dashboard
        $ui.Status.Text =
            'LOCAL TELEMETRY // ESC: CLOSE // F11: FULLSCREEN'
    } catch {
        $ui.Status.Text = "SENSOR ERROR: $($_.Exception.Message)"
    }
})

$window.Add_Closed({
    $timer.Stop()
    $rotation.BeginAnimation(
        [Windows.Media.RotateTransform]::AngleProperty, $null
    )
})

$ui.Cpu.Text = ' --%'
$timer.Start()
[void]$window.ShowDialog()
