# Cursor Usage Tray

独立的 Windows 系统托盘应用，显示 Cursor Models / Other Models / Grok Bot 用量百分比。

**特点**
- 不需要打开 Cursor 或 VS Code
- 鼠标悬停即可查看用量
- 图标颜色随用量变化（绿 / 黄 / 红）
- 每 5 分钟自动刷新
- 查询用量**不会消耗**任何 token / 额度

## 使用方法

```bash
cd tray
npm install
npm start
```

或打包成便携版：

```bash
npm run dist
```

生成的 `.exe` 在 `dist/` 目录。

## 原理

1. 从 `%APPDATA%\Cursor\User\globalStorage\state.vscdb` 读取 `cursorAuth/accessToken`
2. 调用 Cursor Dashboard 只读接口：
   - `GetCurrentPeriodUsage`（Cursor Models / Other Models）
   - `GetSandUsageStatus`（Grok Bot 周额度）
3. 更新系统托盘图标和 Tooltip

## 注意

- 需要先在 Cursor 中登录过账号
- 首次运行如果提示安全警告，选择仍要运行即可
