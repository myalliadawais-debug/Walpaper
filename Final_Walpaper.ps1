# Commander HUD — Windows PowerShell 5.1
# ESC closes. F11 toggles fullscreen.
# Network scale: 1 KB = 1024 bytes; 1 MB = 1024 KB.

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase

if (-not ('CommanderSensors' -as [type])) {
    Add-Type @'
using System;
using System.Runtime.InteropServices;

public static class CommanderSensors {
    [DllImport("kernel32.dll")]
    public static extern bool GetSystemTimes(
        out long idle, out long kernel, out long user);

    [StructLayout(LayoutKind.Sequential)]
    public class Memory {
        public uint length = (uint)Marshal.SizeOf(typeof(Memory));
        public uint load;
        public ulong totalPhys, availPhys, totalPage, availPage;
        public ulong totalVirtual, availVirtual, availExtended;
    }

    [DllImport("kernel32.dll")]
    public static extern bool GlobalMemoryStatusEx(
        [In, Out] Memory memory);
}
'@
}

[xml]$xaml = @'
<Window
 xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
 xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
 Title="Commander HUD"
 Background="#03090E"
 FontFamily="Segoe UI"
 WindowStyle="None"
 WindowState="Maximized">

 <Viewbox Stretch="Uniform">
  <Canvas x:Name="Surface"
   Width="1440" Height="900" Background="#03090E">

   <TextBlock Canvas.Left="50" Canvas.Top="27"
    Text="Developer Mode: ON"
    FontSize="23" Foreground="#26E6DC"/>

   <Line X1="50" Y1="70" X2="1390" Y2="70"
    Stroke="#174563"/>

   <!-- Central date and time -->
   <TextBlock x:Name="Time"
    Canvas.Left="490" Canvas.Top="337"
    Width="460" TextAlignment="Center"
    FontSize="62" FontWeight="Light"
    Foreground="#34F5E5"/>

   <TextBlock x:Name="Day"
    Canvas.Left="500" Canvas.Top="420"
    Width="440" TextAlignment="Center"
    FontSize="25" Foreground="#83BFD5"/>

   <TextBlock x:Name="Date"
    Canvas.Left="490" Canvas.Top="463"
    Width="460" TextAlignment="Center"
    FontSize="25" Foreground="#83BFD5"/>

   <!-- Left-middle borderless table -->
   <Grid Canvas.Left="40" Canvas.Top="300" Width="305">
    <Grid.ColumnDefinitions>
     <ColumnDefinition Width="130"/>
     <ColumnDefinition Width="175"/>
    </Grid.ColumnDefinitions>

    <Grid.RowDefinitions>
     <RowDefinition Height="43"/>
     <RowDefinition Height="40"/>
     <RowDefinition Height="26"/>
     <RowDefinition Height="43"/>
     <RowDefinition Height="40"/>
     <RowDefinition Height="28"/>
     <RowDefinition Height="36"/>
     <RowDefinition Height="36"/>
    </Grid.RowDefinitions>

    <TextBlock Grid.Row="0" Text="CPU"
     FontSize="23" Foreground="#25EBDF"/>
    <TextBlock x:Name="Cpu" Grid.Row="0" Grid.Column="1"
     FontSize="23" Foreground="#25EBDF"/>

    <TextBlock Grid.Row="1" Text="RAM"
     FontSize="23" Foreground="#B58BFF"/>
    <TextBlock x:Name="Ram" Grid.Row="1" Grid.Column="1"
     FontSize="23" Foreground="#B58BFF"/>
    <TextBlock x:Name="RamDetail" Grid.Row="2" Grid.Column="1"
     FontSize="12" Foreground="#6D91AD"/>

    <TextBlock Grid.Row="3" Text="GPU"
     FontSize="23" Foreground="#509FFF"/>
    <TextBlock x:Name="Gpu" Grid.Row="3" Grid.Column="1"
     FontSize="23" Foreground="#509FFF"/>

    <TextBlock Grid.Row="4" Text="SSD"
     FontSize="23" Foreground="#FFBD69"/>
    <TextBlock x:Name="Ssd" Grid.Row="4" Grid.Column="1"
     FontSize="23" Foreground="#FFBD69"/>
    <TextBlock x:Name="DiskDetail" Grid.Row="5" Grid.Column="1"
     FontSize="12" Foreground="#6D91AD"/>

    <TextBlock Grid.Row="6" Text="DOWNLOAD"
     FontSize="18" Foreground="#40F5AC"/>
    <TextBlock x:Name="Download" Grid.Row="6" Grid.Column="1"
     FontSize="18" Foreground="#40F5AC"/>

    <TextBlock Grid.Row="7" Text="UPLOAD"
     FontSize="18" Foreground="#FF72BC"/>
    <TextBlock x:Name="Upload" Grid.Row="7" Grid.Column="1"
     FontSize="18" Foreground="#FF72BC"/>
   </Grid>

   <!-- Ethernet: top right -->
   <TextBlock Canvas.Left="1165" Canvas.Top="130"
    Width="190" TextAlignment="Center"
    Text="ETHERNET" FontSize="20" Foreground="#63ADFF"/>

   <TextBlock x:Name="Ethernet"
    Canvas.Left="1165" Canvas.Top="170"
    Width="190" TextAlignment="Center"
    FontSize="15" Foreground="#9FD5EC"/>

   <!-- Wi-Fi: bottom right -->
   <TextBlock Canvas.Left="1165" Canvas.Top="633"
    Width="190" TextAlignment="Center"
    Text="WI-FI" FontSize="20" Foreground="#25EBDF"/>

   <TextBlock x:Name="Wifi"
    Canvas.Left="1165" Canvas.Top="673"
    Width="190" TextAlignment="Center"
    FontSize="15" Foreground="#9FD5EC"/>

   <Line X1="50" Y1="815" X2="1390" Y2="815"
    Stroke="#174563"/>

   <TextBlock Canvas.Left="300" Canvas.Top="834"
    Width="840" TextAlignment="Center"
    Text="Welcome Commander, MHM"
    FontSize="30" Foreground="#34F5E5"/>

  </Canvas>
 </Viewbox>
</Window>
'@

$reader = New-Object System.Xml.XmlNodeReader $xaml
$window = [Windows.Markup.XamlReader]::Load($reader)

$ui = @{}

@(
    'Surface', 'Time', 'Day', 'Date',
    'Cpu', 'Ram', 'RamDetail', 'Gpu',
    'Ssd', 'DiskDetail', 'Download', 'Upload',
    'Wifi', 'Ethernet'
) | ForEach-Object {
    $ui[$_] = $window.FindName($_)
}

function New-Brush {
    param([string]$Color)

    $brush = New-Object Windows.Media.SolidColorBrush (
        [Windows.Media.ColorConverter]::ConvertFromString($Color)
    )

    $brush.Freeze()
    return $brush
}

$dimBrush = New-Brush '#123044'
$cpuBrush = New-Brush '#25EBDF'
$ramBrush = New-Brush '#B58BFF'
$gpuBrush = New-Brush '#509FFF'
$ssdBrush = New-Brush '#FFBD69'
$downloadBrush = New-Brush '#40F5AC'
$uploadBrush = New-Brush '#FF72BC'

function Add-Circle {
    param(
        [double]$X,
        [double]$Y,
        [double]$Radius,
        [string]$Color,
        [double]$Thickness = 1
    )

    $circle = New-Object Windows.Shapes.Ellipse
    $circle.Width = $Radius * 2
    $circle.Height = $Radius * 2
    $circle.Stroke = New-Brush $Color
    $circle.StrokeThickness = $Thickness
    $circle.IsHitTestVisible = $false

    [Windows.Controls.Canvas]::SetLeft(
        $circle, $X - $Radius
    )

    [Windows.Controls.Canvas]::SetTop(
        $circle, $Y - $Radius
    )

    [void]$ui.Surface.Children.Add($circle)
}

function New-Ring {
    param(
        [double]$Radius,
        [double]$Start,
        [double]$Sweep,
        [int]$Count = 60,
        [double]$Length = 16,
        [double]$Thickness = 5
    )

    $lines = @()

    for ($i = 0; $i -lt $Count; $i++) {
        $angle = (
            $Start + ($i + 0.5) * $Sweep / $Count
        ) * [Math]::PI / 180

        $line = New-Object Windows.Shapes.Line

        $line.X1 = 720 + ($Radius - $Length) * [Math]::Cos($angle)
        $line.Y1 = 440 + ($Radius - $Length) * [Math]::Sin($angle)

        $line.X2 = 720 + $Radius * [Math]::Cos($angle)
        $line.Y2 = 440 + $Radius * [Math]::Sin($angle)

        $line.StrokeThickness = $Thickness
        $line.Stroke = $dimBrush
        $line.IsHitTestVisible = $false

        [void]$ui.Surface.Children.Add($line)
        $lines += $line
    }

    return $lines
}

function Set-Ring {
    param(
        [object[]]$Lines,
        $Percent,
        [Windows.Media.Brush]$Brush
    )

    $count = 0

    if ($null -ne $Percent) {
        $bounded = [Math]::Max(
            0, [Math]::Min(100, [double]$Percent)
        )

        $count = [Math]::Round(
            $Lines.Count * $bounded / 100
        )
    }

    for ($i = 0; $i -lt $Lines.Count; $i++) {
        if ($i -lt $count) {
            $Lines[$i].Stroke = $Brush
        } else {
            $Lines[$i].Stroke = $dimBrush
        }
    }
}

function Set-SpeedRing {
    param(
        [object[]]$Lines,
        [double]$BytesPerSecond,
        [Windows.Media.Brush]$Brush
    )

    # Cumulative speed thresholds:
    # Bars  1-10:  +1 KB/s each
    # Bars 11-20: +10 KB/s each
    # Bars 21-25: +100 KB/s each
    # Bars 26-70: +1 MB/s each

    $threshold = 0.0

    for ($i = 0; $i -lt $Lines.Count; $i++) {
        if ($i -lt 10) {
            $threshold += 1KB
        } elseif ($i -lt 20) {
            $threshold += 10KB
        } elseif ($i -lt 25) {
            $threshold += 100KB
        } else {
            $threshold += 1MB
        }

        if ($BytesPerSecond -ge $threshold) {
            $Lines[$i].Stroke = $Brush
        } else {
            $Lines[$i].Stroke = $dimBrush
        }
    }
}

# Inner circle: CPU left, RAM right.
$cpuLines = @(New-Ring 260 90 180)
$ramLines = @(New-Ring 260 90 -180)

# Middle circle: SSD left, GPU right.
$ssdLines = @(New-Ring 315 90 180)
$gpuLines = @(New-Ring 315 90 -180)

Add-Circle 720 440 230 '#16435A'
Add-Circle 720 440 270 '#16435A'
Add-Circle 720 440 289 '#102A40'
Add-Circle 720 440 325 '#20517C'

# Outer wings: download left, upload right.
$downloadLines = @(New-Ring 351 90 180 70 14 4)
$uploadLines = @(New-Ring 351 90 -180 70 14 4)

# Ethernet: top right.
Add-Circle 1260 190 112 '#20496D' 2
Add-Circle 1260 190 121 '#102D40'

# Wi-Fi: bottom right.
Add-Circle 1260 695 112 '#174A58' 2
Add-Circle 1260 695 121 '#102D40'

function Add-Indicator {
    param([double]$X, [double]$Y)

    $dot = New-Object Windows.Shapes.Ellipse
    $dot.Width = 9
    $dot.Height = 9
    $dot.Fill = $dimBrush

    [Windows.Controls.Canvas]::SetLeft($dot, $X)
    [Windows.Controls.Canvas]::SetTop($dot, $Y)

    [void]$ui.Surface.Children.Add($dot)
    return $dot
}

$wifiDot = Add-Indicator 1256 766
$ethernetDot = Add-Indicator 1256 261

# Run GPU queries separately to keep the interface responsive.
$gpuJob = $null

try {
    $gpuJob = Start-Job -ErrorAction Stop -ScriptBlock {
        while ($true) {
            try {
                $counters = @(
                    Get-CimInstance `
                        -ClassName Win32_PerfFormattedData_GPUPerformanceCounters_GPUEngine `
                        -ErrorAction Stop
                )

                $engines = @{}

                foreach ($counter in $counters) {
                    $name = [string]$counter.Name

                    if ($name -notmatch '^pid_\d+_(.+)$') {
                        continue
                    }

                    $engine = $Matches[1]

                    if (-not $engines.ContainsKey($engine)) {
                        $engines[$engine] = 0.0
                    }

                    $engines[$engine] +=
                        [double]$counter.UtilizationPercentage
                }

                $value = 0

                if ($engines.Count -gt 0) {
                    $value = (
                        $engines.Values |
                        Measure-Object -Maximum
                    ).Maximum
                }

                [pscustomobject]@{
                    Available = $engines.Count -gt 0
                    Value = [Math]::Round(
                        [Math]::Max(
                            0, [Math]::Min(100, $value)
                        )
                    )
                    Timestamp = [DateTime]::UtcNow
                }
            } catch {
                [pscustomobject]@{
                    Available = $false
                    Value = 0
                    Timestamp = [DateTime]::UtcNow
                }
            }

            Start-Sleep -Seconds 3
        }
    }
} catch {
    $gpuJob = $null
}

$script:oldIdle = 0L
$script:oldTotal = 0L
$script:oldAdapters = @{}
$script:oldTime = [DateTime]::UtcNow
$script:lastGpu = $null

$systemRoot = [IO.Path]::GetPathRoot($env:SystemRoot)
$systemDrive = New-Object IO.DriveInfo $systemRoot

function Format-Speed {
    param([double]$BytesPerSecond)

    if ($BytesPerSecond -ge 1GB) {
        return '{0:N2} GB/s' -f ($BytesPerSecond / 1GB)
    }

    if ($BytesPerSecond -ge 1MB) {
        return '{0:N2} MB/s' -f ($BytesPerSecond / 1MB)
    }

    return '{0:N1} KB/s' -f ($BytesPerSecond / 1KB)
}

function Update-Network {
    $stamp = [DateTime]::UtcNow
    $elapsed = ($stamp - $script:oldTime).TotalSeconds

    $current = @{}
    $totalRx = 0.0
    $totalTx = 0.0

    $wifi = @{
        Up = $false
        Rx = 0.0
        Tx = 0.0
    }

    $ethernet = @{
        Up = $false
        Rx = 0.0
        Tx = 0.0
    }

    foreach (
        $adapter in
        [Net.NetworkInformation.NetworkInterface]::GetAllNetworkInterfaces()
    ) {
        if ($adapter.OperationalStatus -ne 'Up') {
            continue
        }

        $type = [int]$adapter.NetworkInterfaceType

        if ($type -eq 71) {
            $target = $wifi
        } elseif ($type -in @(6, 62, 69, 117)) {
            $target = $ethernet
        } else {
            continue
        }

        $target.Up = $true

        try {
            $stats = $adapter.GetIPv4Statistics()

            $current[$adapter.Id] = @(
                [double]$stats.BytesReceived,
                [double]$stats.BytesSent
            )

            if (
                $script:oldAdapters.ContainsKey($adapter.Id) -and
                $elapsed -gt 0
            ) {
                $previous = $script:oldAdapters[$adapter.Id]

                $rx = [Math]::Max(
                    0,
                    ($stats.BytesReceived - $previous[0]) / $elapsed
                )

                $tx = [Math]::Max(
                    0,
                    ($stats.BytesSent - $previous[1]) / $elapsed
                )

                $target.Rx += $rx
                $target.Tx += $tx

                $totalRx += $rx
                $totalTx += $tx
            }
        } catch {
            # Keep connection state if traffic counters are unavailable.
        }
    }

    $script:oldAdapters = $current
    $script:oldTime = $stamp

    $entries = @(
        @{
            Name = 'Wifi'
            Data = $wifi
            Dot = $wifiDot
        },
        @{
            Name = 'Ethernet'
            Data = $ethernet
            Dot = $ethernetDot
        }
    )

    foreach ($entry in $entries) {
        $data = $entry.Data

        if ($data.Up) {
            $rxText = Format-Speed $data.Rx
            $txText = Format-Speed $data.Tx

            $ui[$entry.Name].Text =
                "CONNECTED`nRX $rxText`nTX $txText"

            $entry.Dot.Fill = $cpuBrush
        } else {
            $ui[$entry.Name].Text =
                "DISCONNECTED`nRX --`nTX --"

            $entry.Dot.Fill = $dimBrush
        }
    }

    Set-SpeedRing $downloadLines $totalRx $downloadBrush
    Set-SpeedRing $uploadLines $totalTx $uploadBrush

    $ui.Download.Text = Format-Speed $totalRx
    $ui.Upload.Text = Format-Speed $totalTx
}

function Update-Dashboard {
    $now = Get-Date
    $culture = [Globalization.CultureInfo]::GetCultureInfo('en-US')

    $ui.Time.Text = $now.ToString('hh:mm:ss tt', $culture)

    $ui.Day.Text = $now.ToString(
        'dddd', $culture
    ).ToUpperInvariant()

    $ui.Date.Text = $now.ToString('MMMM dd, yyyy', $culture)

    # CPU usage.
    $idle = 0L
    $kernel = 0L
    $user = 0L

    if ([CommanderSensors]::GetSystemTimes(
        [ref]$idle, [ref]$kernel, [ref]$user
    )) {
        $total = $kernel + $user
        $difference = $total - $script:oldTotal

        if ($script:oldTotal -gt 0 -and $difference -gt 0) {
            $cpu = 100 * (
                1 - ($idle - $script:oldIdle) / $difference
            )

            $cpu = [Math]::Round(
                [Math]::Max(0, [Math]::Min(100, $cpu))
            )

            $ui.Cpu.Text = "$cpu%"
            Set-Ring $cpuLines $cpu $cpuBrush
        }

        $script:oldIdle = $idle
        $script:oldTotal = $total
    } else {
        $ui.Cpu.Text = 'N/A'
        Set-Ring $cpuLines $null $cpuBrush
    }

    # Physical RAM usage.
    $memory = New-Object CommanderSensors+Memory

    if ([CommanderSensors]::GlobalMemoryStatusEx($memory)) {
        $ui.Ram.Text = "$($memory.load)%"

        $ui.RamDetail.Text = '{0:N1} / {1:N1} GB USED' -f (
            (($memory.totalPhys - $memory.availPhys) / 1GB),
            ($memory.totalPhys / 1GB)
        )

        Set-Ring $ramLines $memory.load $ramBrush
    } else {
        $ui.Ram.Text = 'N/A'
        $ui.RamDetail.Text = ''

        Set-Ring $ramLines $null $ramBrush
    }

    # System-drive storage usage.
    try {
        $size = $systemDrive.TotalSize

        if ($size -le 0) {
            throw 'Drive size unavailable.'
        }

        $used = $size - $systemDrive.TotalFreeSpace
        $percent = [Math]::Round(100 * $used / $size)

        $ui.Ssd.Text = "$percent% USED"

        $ui.DiskDetail.Text = '{0} {1:N1} / {2:N1} GB' -f (
            $systemDrive.Name,
            ($used / 1GB),
            ($size / 1GB)
        )

        Set-Ring $ssdLines $percent $ssdBrush
    } catch {
        $ui.Ssd.Text = 'N/A'
        $ui.DiskDetail.Text = ''

        Set-Ring $ssdLines $null $ssdBrush
    }

    # Latest GPU sample.
    if ($null -ne $gpuJob) {
        $samples = @(
            Receive-Job -Job $gpuJob -ErrorAction SilentlyContinue
        )

        if ($samples.Count -gt 0) {
            $script:lastGpu = $samples[-1]
        }
    }

    $gpuAvailable = $false

    if (
        $null -ne $script:lastGpu -and
        $script:lastGpu.Available
    ) {
        $age = (
            [DateTime]::UtcNow -
            [DateTime]$script:lastGpu.Timestamp
        ).TotalSeconds

        $gpuAvailable = $age -lt 15
    }

    if ($gpuAvailable) {
        $ui.Gpu.Text = "$($script:lastGpu.Value)%"
        Set-Ring $gpuLines $script:lastGpu.Value $gpuBrush
    } else {
        $ui.Gpu.Text = 'N/A'
        Set-Ring $gpuLines $null $gpuBrush
    }

    Update-Network
}

$window.Add_KeyDown({
    if ($_.Key -eq 'Escape') {
        $window.Close()
    } elseif ($_.Key -eq 'F11') {
        if ($window.WindowStyle -eq 'None') {
            $window.WindowState = 'Normal'
            $window.WindowStyle = 'SingleBorderWindow'
            $window.Width = 1200
            $window.Height = 790
        } else {
            $window.WindowStyle = 'None'
            $window.WindowState = 'Maximized'
        }
    }
})

$ui.Cpu.Text = '--'
$ui.Ram.Text = '--'
$ui.Gpu.Text = '...'
$ui.Ssd.Text = '--'
$ui.Download.Text = '--'
$ui.Upload.Text = '--'

$timer = New-Object Windows.Threading.DispatcherTimer
$timer.Interval = [TimeSpan]::FromSeconds(1)

$timer.Add_Tick({
    try {
        Update-Dashboard
    } catch {
        Write-Warning "Sensor update failed: $($_.Exception.Message)"
    }
})

try {
    Update-Dashboard
    $timer.Start()
    [void]$window.ShowDialog()
} finally {
    $timer.Stop()

    if ($null -ne $gpuJob) {
        Stop-Job -Job $gpuJob -ErrorAction SilentlyContinue
        Remove-Job -Job $gpuJob -Force -ErrorAction SilentlyContinue
    }
}
