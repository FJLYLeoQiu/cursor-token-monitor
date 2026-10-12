# Cursor Usage - Always-visible floating window
# Run: powershell -ExecutionPolicy Bypass -File .\CursorUsageTray.ps1

Write-Host "=== Cursor Usage Monitor ===" -ForegroundColor Cyan

try {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
} catch {
    Write-Host "Failed to load WinForms: $_" -ForegroundColor Red
    pause
    exit 1
}

$script:done = $false

# ---------- Floating window ----------
$form = New-Object System.Windows.Forms.Form
$form.Text = "Cursor Usage"
$form.Size = New-Object System.Drawing.Size(240, 100)
$form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedToolWindow
$form.TopMost = $true
$form.StartPosition = [System.Windows.Forms.FormStartPosition]::Manual
$form.BackColor = [System.Drawing.Color]::FromArgb(20, 20, 20)
$form.ShowInTaskbar = $true
$form.Opacity = 0.95

$label = New-Object System.Windows.Forms.Label
$label.Dock = [System.Windows.Forms.DockStyle]::Fill
$label.Font = New-Object System.Drawing.Font("Consolas", 11, [System.Drawing.FontStyle]::Bold)
$label.ForeColor = [System.Drawing.Color]::White
$label.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
$label.Padding = New-Object System.Windows.Forms.Padding(10, 8, 6, 6)
$label.Text = "Loading usage..."
$form.Controls.Add($label)

# Safe position: 100px from bottom-right of primary screen
$screen = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
$x = [Math]::Max(20, $screen.Right - 260)
$y = [Math]::Max(20, $screen.Bottom - 140)
$form.Location = New-Object System.Drawing.Point($x, $y)
Write-Host "Window position: $x, $y" -ForegroundColor Gray

# Drag support
$script:dragging = $false
$script:dragOffset = $null
$form.add_MouseDown({
    $script:dragging = $true
    $script:dragOffset = $form.PointToClient([System.Windows.Forms.Cursor]::Position)
})
$form.add_MouseMove({
    if ($script:dragging) {
        $p = [System.Windows.Forms.Cursor]::Position
        $form.Location = New-Object System.Drawing.Point(($p.X - $script:dragOffset.X), ($p.Y - $script:dragOffset.Y))
    }
})
$form.add_MouseUp({ $script:dragging = $false })

# ---------- Tray ----------
$notify = New-Object System.Windows.Forms.NotifyIcon
$notify.Icon = [System.Drawing.SystemIcons]::Information
$notify.Text = "Cursor Usage"
$notify.Visible = $true

$menu = New-Object System.Windows.Forms.ContextMenuStrip
$refreshItem = $menu.Items.Add("Refresh")
$showItem = $menu.Items.Add("Show Window")
$exitItem = $menu.Items.Add("Exit")
$notify.ContextMenuStrip = $menu

$refreshItem.add_Click({ Update-Usage })
$showItem.add_Click({ 
    $form.Visible = $true
    $form.Activate()
    $form.BringToFront()
})
$exitItem.add_Click({ $script:done = $true })

function Get-CursorToken {
    $dbPath = Join-Path $env:APPDATA "Cursor\User\globalStorage\state.vscdb"
    Write-Host "DB path: $dbPath" -ForegroundColor Gray
    if (-not (Test-Path $dbPath)) { throw "Cursor DB not found at $dbPath" }

    if (Get-Command sqlite3 -ErrorAction SilentlyContinue) {
        $token = & sqlite3 $dbPath "SELECT value FROM ItemTable WHERE key = 'cursorAuth/accessToken';" 2>$null
        if ($token) { return $token.Trim() }
    }

    $pyCode = 'import sqlite3,os; p=os.path.join(os.environ["APPDATA"],"Cursor","User","globalStorage","state.vscdb"); con=sqlite3.connect(p); cur=con.cursor(); cur.execute("SELECT value FROM ItemTable WHERE key=''cursorAuth/accessToken''"); row=cur.fetchone(); print(row[0] if row else ""); con.close()'
    $token = python -c $pyCode 2>$null
    if ($token) { return $token.Trim() }
    throw "Cannot read token (need Python or sqlite3)"
}

function Invoke-CursorApi {
    param($url, $token)
    try {
        $headers = @{
            Authorization = "Bearer $token"
            "Content-Type" = "application/json"
            "Connect-Protocol-Version" = "1"
        }
        return Invoke-RestMethod -Uri $url -Method Post -Headers $headers -Body "{}" -TimeoutSec 15
    } catch {
        Write-Host "API call failed: $($_.Exception.Message)" -ForegroundColor Yellow
        return $null
    }
}

function Update-Usage {
    try {
        Write-Host "Refreshing..." -ForegroundColor Yellow
        $token = Get-CursorToken
        $period = Invoke-CursorApi "https://api2.cursor.sh/aiserver.v1.DashboardService/GetCurrentPeriodUsage" $token
        $sand   = Invoke-CursorApi "https://api2.cursor.sh/aiserver.v1.DashboardService/GetSandUsageStatus" $token

        $cursorPct = 0; $otherPct = 0; $botPct = 0
        if ($period -and $period.planUsage) {
            if ($null -ne $period.planUsage.autoPercentUsed) { $cursorPct = [int]$period.planUsage.autoPercentUsed }
            if ($null -ne $period.planUsage.apiPercentUsed)  { $otherPct  = [int]$period.planUsage.apiPercentUsed }
        }
        if ($sand) {
            if ($null -ne $sand.usagePercent) { $botPct = [int]$sand.usagePercent }
            elseif ($null -ne $sand.usage_percent) { $botPct = [int]$sand.usage_percent }
        }

        $text = "Cursor:  $cursorPct%`r`nOther:   $otherPct%`r`nGrok Bot: $botPct%"
        $label.Text = $text
        $notify.Text = "Cursor $cursorPct% | Other $otherPct% | Bot $botPct%"

        $max = [Math]::Max($cursorPct, [Math]::Max($otherPct, $botPct))
        if ($max -ge 85) {
            $notify.Icon = [System.Drawing.SystemIcons]::Error
            $label.ForeColor = [System.Drawing.Color]::FromArgb(255, 110, 110)
        } elseif ($max -ge 60) {
            $notify.Icon = [System.Drawing.SystemIcons]::Warning
            $label.ForeColor = [System.Drawing.Color]::FromArgb(255, 210, 90)
        } else {
            $notify.Icon = [System.Drawing.SystemIcons]::Information
            $label.ForeColor = [System.Drawing.Color]::FromArgb(130, 230, 150)
        }
        Write-Host $text -ForegroundColor Green
    } catch {
        $msg = $_.Exception.Message
        $label.Text = "Error:`r`n$msg"
        $notify.Text = "Error"
        Write-Host "Error: $msg" -ForegroundColor Red
    }
}

# Show window first
$form.Show()
$form.Activate()
$form.BringToFront()
Write-Host "Window shown." -ForegroundColor Green

Update-Usage

$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 300000
$timer.add_Tick({ Update-Usage })
$timer.Start()

Write-Host "Running. Close this console or right-click tray icon to exit." -ForegroundColor Cyan

try {
    while (-not $script:done) {
        [System.Windows.Forms.Application]::DoEvents()
        Start-Sleep -Milliseconds 100
    }
} finally {
    Write-Host "Exiting..." -ForegroundColor Cyan
    $timer.Stop()
    $notify.Visible = $false
    $notify.Dispose()
    $form.Close()
}
