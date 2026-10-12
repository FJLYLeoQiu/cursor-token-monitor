# Cursor Usage Tray

Windows 系统托盘 + 悬浮窗监控 Cursor Models / Other Models / Grok Bot 用量。

## 隐私说明（重要）

**本仓库是公开的，所有人都能看到源码。**

但请放心：

- 源码中**没有任何**账号、密码、Token 或个人数据
- 脚本只在**你自己的电脑上运行**时，读取本地 Cursor 已保存的登录状态  
  （`%APPDATA%\Cursor\User\globalStorage\state.vscdb` 中的 `cursorAuth/accessToken`）
- Token 不会上传到任何第三方，只用于调用 Cursor 官方的只读用量接口
- 查询用量本身不消耗额度
- 别人看到源码，也无法获取你的账号或用量数据

如果你担心本地 Token 被脚本读取，可以随时退出 Cursor 登录，或删除/重命名 `state.vscdb` 后再运行。

## 推荐：纯 PowerShell 版（零安装）

```powershell
powershell -ExecutionPolicy Bypass -File .\CursorUsageTray.ps1
```

或双击 `StartTray.bat`。

**特点**
- 无需安装任何依赖
- 桌面悬浮窗直接显示用量（可拖动）
- 托盘图标右键可刷新 / 退出
- 每 5 分钟自动刷新
- 查询用量不消耗 token
- 需要本机已安装 Python（用于读取本地 SQLite）

## 备选：Electron 版

```powershell
npm install --registry=https://registry.npmmirror.com
npm start
```
