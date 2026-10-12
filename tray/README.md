# Cursor Usage Tray

Windows 系统托盘监控 Cursor Models / Other Models / Grok Bot 用量。

## 推荐：纯 PowerShell 版（零安装）

不需要 `npm install`，直接运行：

```powershell
powershell -ExecutionPolicy Bypass -File .\CursorUsageTray.ps1
```

或右键 → 使用 PowerShell 运行。

**特点**
- 无需安装任何依赖
- 托盘图标 + 悬停显示用量
- 每 5 分钟自动刷新
- 查询用量不消耗 token
- 需要本机已安装 Python（用于读取 SQLite，大多数开发环境都有）

## 备选：Electron 版

如果更喜欢 Node 方案：

```powershell
npm install --registry=https://registry.npmmirror.com
npm start
```

使用国内镜像可大幅加快 Electron 下载。
