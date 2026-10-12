# Cursor Usage Tray + Always-visible floating window
# Run: powershell -ExecutionPolicy Bypass -File .\CursorUsageTray.ps1

Write-Host "Starting Cursor Usage Monitor..." -ForegroundColor Cyan

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$script:done = $false

# ---------- Floating window ----------
$form = New-Object System.Windows.Forms.Form
$form.Text = "Cursor Usage"
$form.Size = New-Object System.Drawing.Size(220, 90)
$form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::None
$form.TopMost = $true
$form.StartPosition = [System.Windows.Forms.FormStartPosition]::Manual
$form.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 30)
$form.ShowInTaskbar = $false

$label = New-Object System.Windows.Forms.Label
$label.Dock = [System.Windows.Forms.DockStyle]::Fill
$label.Font = New-Object System.Drawing.Font("Consolas", 10)
$label.ForeColor = [System.Drawing.Color]::White
$label.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
$label.Padding = New-Object System.Windows.Forms.Padding(8, 6, 4, 4)
$label.Text = "Loading..."
$form.Controls.Add($label)

# Position bottom-right
$screen = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
$form.Location = New-Object System.Drawing.Point(($screen.Right - 230), ($screen.Bottom - 110))

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

# ---------- Tray icon ----------
$notify = New-Object System.Windows.Forms.NotifyIcon
$notify.Icon = [System.Drawing.SystemIcons]::Information
$notify.Text = "Cursor Usage"
$notify.Visible = $true

$menu = New-Object System.Windows.Forms.ContextMenuStrip
$refreshItem = $menu.Items.Add("Refresh")
$hideItem = $menu.Items.Add("Hide/Show Window")
$exitItem = $menu.Items.Add("Exit")
$notify.ContextMenuStrip = $menu

$refreshItem.add_Click({ Update-Usage })
$hideItem.add_Click({ $form.Visible = -not $form.Visible })
$exitItem.add_Click({ $script:done = $true })

function Get-CursorToken {
    $dbPath = Join-Path $env:APPDATA "Cursor\User\globalStorage\state.vscdb"
    if (-not (Test-Path $dbPath)) { throw "Cursor DB not found" }

    if (Get-Command sqlite3 -ErrorAction SilentlyContinue) {
        $token = & sqlite3 $dbPath "SELECT value FROM ItemTable WHERE key = 'cursorAuth/accessToken';" 2>$null
        if ($token) { return $token.Trim() }
    }

    $pyCode = 'import sqlite3,os; p=os.path.join(os.environ["APPDATA"],"Cursor","User","globalStorage","state.vscdb"); con=sqlite3.connect(p); cur=con.cursor(); cur.execute("SELECT value FROM ItemTable WHERE key=''cursorAuth/accessToken''"); row=cur.fetchone(); print(row[0] if row else ""); con.close()'
    $token = python -c $pyCode 2>$null
    if ($token) { return $token.Trim() }
    throw "Need Python or sqlite3"
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
    } catch { return $null }
}

function Update-Usage {
    try {
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
            $label.ForeColor = [System.Drawing.Color]::FromArgb(255, 100, 100)
        } elseif ($max -ge 60) {
            $notify.Icon = [System.Drawing.SystemIcons]::Warning
            $label.ForeColor = [System.Drawing.Color]::FromArgb(255, 200, 80)
        } else {
            $notify.Icon = [System.Drawing.SystemIcons]::Information
            $label.ForeColor = [System.Drawing.Color]::FromArgb(120, 220, 140)
        }
        Write-Host $text -ForegroundColor Green
    } catch {
        $msg = $_.Exception.Message
        $label.Text = "Error: $msg"
        $notify.Text = "Error: $msg"
        Write-Host "Error: $msg" -ForegroundColor Red
    }
}

$form.Show()
Update-Usage

$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 300000
$timer.add_Tick({ Update-Usage })
$timer.Start()

Write-Host "Floating window is shown (bottom-right). Drag to move." -ForegroundColor Cyan
Write-Host "Tray icon: right-click for menu." -ForegroundColor Cyan

try {
    while (-not $script:done) {
        [System.Windows.Forms.Application]::DoEvents()
        Start-Sleep -Milliseconds 100
    }
} finally {
    $timer.Stop()
    $notify.Visible = $false
    $notify.Dispose()
    $form.Close()
}
