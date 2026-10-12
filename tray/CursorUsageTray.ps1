# Cursor Usage Tray - Pure PowerShell, no npm/electron required
# Run: powershell -ExecutionPolicy Bypass -File .\CursorUsageTray.ps1

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$script:done = $false
$script:tooltip = "Cursor Usage: 初始化中..."

# Tray icon
$notify = New-Object System.Windows.Forms.NotifyIcon
$notify.Icon = [System.Drawing.SystemIcons]::Information
$notify.Text = $script:tooltip
$notify.Visible = $true

# Context menu
$menu = New-Object System.Windows.Forms.ContextMenuStrip
$refreshItem = $menu.Items.Add("立即刷新")
$exitItem = $menu.Items.Add("退出")
$notify.ContextMenuStrip = $menu

$refreshItem.add_Click({ Update-Usage })
$exitItem.add_Click({ $script:done = $true })

function Get-CursorToken {
    $dbPath = Join-Path $env:APPDATA "Cursor\User\globalStorage\state.vscdb"
    if (-not (Test-Path $dbPath)) { throw "未找到 Cursor 数据库，请先登录 Cursor" }

    # Use sqlite3 if available, otherwise try python
    if (Get-Command sqlite3 -ErrorAction SilentlyContinue) {
        $token = & sqlite3 $dbPath "SELECT value FROM ItemTable WHERE key = 'cursorAuth/accessToken';" 2>$null
        if ($token) { return $token.Trim() }
    }

    # Fallback: python + sqlite3 (most Windows have python or can use it)
    $py = @"
import sqlite3, os
p = os.path.join(os.environ['APPDATA'], 'Cursor', 'User', 'globalStorage', 'state.vscdb')
con = sqlite3.connect(p)
cur = con.cursor()
cur.execute("SELECT value FROM ItemTable WHERE key = 'cursorAuth/accessToken'")
row = cur.fetchone()
print(row[0] if row else '')
con.close()
"@
    $token = python -c $py 2>$null
    if ($token) { return $token.Trim() }
    throw "无法读取 Token，请确认已安装 Python 或 sqlite3"
}

function Invoke-CursorApi {
    param($url, $token)
    try {
        $headers = @{
            Authorization = "Bearer $token"
            "Content-Type" = "application/json"
            "Connect-Protocol-Version" = "1"
        }
        $resp = Invoke-RestMethod -Uri $url -Method Post -Headers $headers -Body "{}" -TimeoutSec 15
        return $resp
    } catch { return $null }
}

function Update-Usage {
    try {
        $token = Get-CursorToken
        $period = Invoke-CursorApi "https://api2.cursor.sh/aiserver.v1.DashboardService/GetCurrentPeriodUsage" $token
        $sand   = Invoke-CursorApi "https://api2.cursor.sh/aiserver.v1.DashboardService/GetSandUsageStatus" $token

        $cursorPct = [int]($period.planUsage.autoPercentUsed ?? 0)
        $otherPct  = [int]($period.planUsage.apiPercentUsed ?? 0)
        $botPct    = [int]($sand.usagePercent ?? $sand.usage_percent ?? 0)

        $script:tooltip = "Cursor Models: $cursorPct%`nOther Models: $otherPct%`nGrok Bot: $botPct%"
        $notify.Text = $script:tooltip

        # Simple color hint via icon (Information = blue/green-ish)
        $max = [Math]::Max($cursorPct, [Math]::Max($otherPct, $botPct))
        if ($max -ge 85) { $notify.Icon = [System.Drawing.SystemIcons]::Error }
        elseif ($max -ge 60) { $notify.Icon = [System.Drawing.SystemIcons]::Warning }
        else { $notify.Icon = [System.Drawing.SystemIcons]::Information }
    } catch {
        $notify.Text = "Cursor Usage: $($_.Exception.Message)"
    }
}

# Initial load
Update-Usage

# Refresh every 5 minutes
$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 300000
$timer.add_Tick({ Update-Usage })
$timer.Start()

# Message loop
try {
    while (-not $script:done) {
        [System.Windows.Forms.Application]::DoEvents()
        Start-Sleep -Milliseconds 200
    }
} finally {
    $timer.Stop()
    $notify.Visible = $false
    $notify.Dispose()
}
