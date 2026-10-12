const { app, Tray, Menu, nativeImage } = require('electron');
const https = require('https');
const path = require('path');
const fs = require('fs');
const initSqlJs = require('sql.js');

let tray = null;
let updateTimer = null;

const DB_PATH = path.join(
  process.env.APPDATA || '',
  'Cursor',
  'User',
  'globalStorage',
  'state.vscdb'
);

async function readAccessToken() {
  if (!fs.existsSync(DB_PATH)) {
    throw new Error('未找到 Cursor 数据库，请先登录 Cursor');
  }
  const SQL = await initSqlJs();
  const fileBuffer = fs.readFileSync(DB_PATH);
  const db = new SQL.Database(fileBuffer);
  const result = db.exec("SELECT value FROM ItemTable WHERE key = 'cursorAuth/accessToken'");
  db.close();
  if (!result.length || !result[0].values.length) {
    throw new Error('未找到登录 Token，请先在 Cursor 中登录');
  }
  return result[0].values[0][0];
}

function postJson(url, token) {
  return new Promise((resolve, reject) => {
    const body = '{}';
    const req = https.request(
      url,
      {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${token}`,
          'Content-Type': 'application/json',
          'Connect-Protocol-Version': '1',
          'Content-Length': Buffer.byteLength(body),
          'User-Agent': 'cursor-usage-tray',
        },
      },
      (res) => {
        let data = '';
        res.on('data', (c) => (data += c));
        res.on('end', () => {
          if (res.statusCode >= 200 && res.statusCode < 300) {
            try {
              resolve(JSON.parse(data || '{}'));
            } catch (e) {
              reject(e);
            }
          } else {
            reject(new Error(`HTTP ${res.statusCode}`));
          }
        });
      }
    );
    req.on('error', reject);
    req.setTimeout(12000, () => req.destroy(new Error('timeout')));
    req.write(body);
    req.end();
  });
}

async function fetchUsage(token) {
  const [period, sand] = await Promise.all([
    postJson('https://api2.cursor.sh/aiserver.v1.DashboardService/GetCurrentPeriodUsage', token).catch(() => null),
    postJson('https://api2.cursor.sh/aiserver.v1.DashboardService/GetSandUsageStatus', token).catch(() => null),
  ]);

  const plan = period?.planUsage || {};
  const cursorPct = plan.autoPercentUsed ?? 0;
  const otherPct = plan.apiPercentUsed ?? 0;
  const botPct = sand?.usagePercent ?? sand?.usage_percent ?? 0;

  return {
    cursorPct: Math.round(cursorPct),
    otherPct: Math.round(otherPct),
    botPct: Math.round(botPct),
    raw: { period, sand },
  };
}

function makeIcon(pct) {
  // Simple colored circle based on max usage
  const size = 16;
  const canvas = Buffer.alloc(size * size * 4);
  let r = 50, g = 180, b = 80; // green
  if (pct >= 85) { r = 220; g = 50; b = 50; }
  else if (pct >= 60) { r = 230; g = 170; b = 40; }

  for (let y = 0; y < size; y++) {
    for (let x = 0; x < size; x++) {
      const dx = x - size / 2 + 0.5;
      const dy = y - size / 2 + 0.5;
      const dist = Math.sqrt(dx * dx + dy * dy);
      const idx = (y * size + x) * 4;
      if (dist < size / 2 - 1) {
        canvas[idx] = r;
        canvas[idx + 1] = g;
        canvas[idx + 2] = b;
        canvas[idx + 3] = 255;
      } else {
        canvas[idx + 3] = 0;
      }
    }
  }
  return nativeImage.createFromBuffer(canvas, { width: size, height: size });
}

async function updateTray() {
  try {
    const token = await readAccessToken();
    const u = await fetchUsage(token);
    const maxPct = Math.max(u.cursorPct, u.otherPct, u.botPct);

    const tooltip = [
      `Cursor Models: ${u.cursorPct}%`,
      `Other Models: ${u.otherPct}%`,
      `Grok Bot: ${u.botPct}%`,
    ].join('\n');

    if (tray) {
      tray.setImage(makeIcon(maxPct));
      tray.setToolTip(tooltip);
    }
  } catch (err) {
    if (tray) {
      tray.setToolTip(`Cursor Usage: ${err.message}`);
    }
  }
}

function createTray() {
  const icon = makeIcon(0);
  tray = new Tray(icon);
  tray.setToolTip('Cursor Usage Monitor');

  const menu = Menu.buildFromTemplate([
    { label: '立即刷新', click: updateTray },
    { type: 'separator' },
    { label: '退出', click: () => app.quit() },
  ]);
  tray.setContextMenu(menu);

  updateTray();
  updateTimer = setInterval(updateTray, 5 * 60 * 1000); // 5 minutes
}

app.whenReady().then(createTray);

app.on('window-all-closed', (e) => {
  e.preventDefault(); // keep running in tray
});

app.on('before-quit', () => {
  if (updateTimer) clearInterval(updateTimer);
});
