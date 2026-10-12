# Cursor Usage Tray - Pure PowerShell
# Run: powershell -ExecutionPolicy Bypass -File .\CursorUsageTray.ps1

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$script:done = $false

$notify = New-Object System.Windows.Forms.NotifyIcon
$notify.Icon = [System.Drawing.SystemIcons]::Information
$notify.Text = "Cursor Usage: loading..."
$notify.Visible = $true

$menu = New-Object System.Windows.Forms.ContextMenuStrip
$refreshItem = $menu.Items.Add("Refresh")
$exitItem = $menu.Items.Add("Exit")
$notify.ContextMenuStrip = $menu

$refreshItem.add_Click({ Update-Usage })
$exitItem.add_Click({ $script:done = $true })

function Get-CursorToken {
    $dbPath = Join-Path $env:APPDATA "Cursor\User\globalStorage\state.vscdb"
    if (-not (Test-Path $dbPath)) {
        throw "Cursor DB not found. Please login to Cursor first."
    }

    if (Get-Command sqlite3 -ErrorAction SilentlyContinue) {
        $token = & sqlite3 $dbPath "SELECT value FROM ItemTable WHERE key = 'cursorAuth/accessToken';" 2>$null
        if ($token) { return $token.Trim() }
    }

    $pyCode = 'import sqlite3,os; p=os.path.join(os.environ["APPDATA"],"Cursor","User","globalStorage","state.vscdb"); con=sqlite3.connect(p); cur=con.cursor(); cur.execute("SELECT value FROM ItemTable WHERE key=''cursorAuth/accessToken''"); row=cur.fetchone(); print(row[0] if row else ""); con.close()'
    $token = python -c $pyCode 2>$null
    if ($token) { return $token.Trim() }

    throw "Cannot read token. Install Python or sqlite3."
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
        return $null
    }
}

function Update-Usage {
    try {
        $token = Get-CursorToken
        $period = Invoke-CursorApi "https://api2.cursor.sh/aiserver.v1.DashboardService/GetCurrentPeriodUsage" $token
        $sand   = Invoke-CursorApi "https://api2.cursor.sh/aiserver.v1.DashboardService/GetSandUsageStatus" $token

        $cursorPct = 0
        $otherPct = 0
        $botPct = 0

        if ($period -and $period.planUsage) {
            if ($null -ne $period.planUsage.autoPercentUsed) { $cursorPct = [int]$period.planUsage.autoPercentUsed }
            if ($null -ne $period.planUsage.apiPercentUsed)  { $otherPct  = [int]$period.planUsage.apiPercentUsed }
        }
        if ($sand) {
            if ($null -ne $sand.usagePercent) { $botPct = [int]$sand.usagePercent }
            elseif ($null -ne $sand.usage_percent) { $botPct = [int]$sand.usage_percent }
        }

        $text = "Cursor Models: $cursorPct%`nOther Models: $otherPct%`nGrok Bot: $botPct%"
        $notify.Text = $text

        $max = [Math]::Max($cursorPct, [Math]::Max($otherPct, $botPct))
        if ($max -ge 85) { $notify.Icon = [System.Drawing.SystemIcons]::Error }
        elseif ($max -ge 60) { $notify.Icon = [System.Drawing.SystemIcons]::Warning }
        else { $notify.Icon = [System.Drawing.SystemIcons]::Information }
    } catch {
        $notify.Text = "Error: $($_.Exception.Message)"
    }
}

Update-Usage

$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 300000
$timer.add_Tick({ Update-Usage })
$timer.Start()

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
