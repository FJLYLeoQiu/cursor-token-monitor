# Cursor Token Monitor (with Grok Bot)

**Know where your Cursor + Grok Bot allowance goes — not just how much is left.**

This is a fork of [ahmed404abd/cursor-token-monitor](https://github.com/ahmed404abd/cursor-token-monitor) with added **Grok Bot weekly usage monitoring**.

Lives in the **bottom status bar** of Cursor (right side) — e.g. a lightning icon with text like **`Cursor 12% · Other 8% · Bot 35%`**. The label tints **green → yellow → orange → red** from your total usage. Click it to open the private Token Cockpit.

### New in this fork
- **Grok Bot (Sand) weekly usage**: Fetches `GetSandUsageStatus` and displays the weekly percent used in the status bar (and rotates in rotate mode).
- Same auth token as Cursor — no extra setup.
- Status bar shows `Bot XX%` alongside Cursor Models / Other Models when available.

Cursor Token Monitor turns your signed-in account data into plan health, dual Pro quotas, **Grok Bot weekly pool**, burn runway, cache-efficiency analytics, model comparisons, trends, a 90-day heatmap, and alerts — without sending usage to a third-party service.

**Original features preserved.** See upstream for full screenshot tour.

### Built for questions Cursor's basic usage page cannot answer

- Which model is consuming the most of my allowance?
- At this burn rate, when will Cursor Models / Other Models hit 100%?
- How many days of runway do I have?
- How much of my **Grok Bot weekly** allowance is left?
- When does Grok Bot reset?

Works in **Cursor** (VS Code–compatible). It reads your existing local Cursor sign-in and calls Cursor’s own usage APIs (including Sand for Grok Bot). Your code, chats, and usage history stay on your machine.

## Requirements

1. **Cursor** desktop app (signed in)
2. That’s it — **no Python** and no extra runtimes

## Getting started

1. Clone / download this fork
2. `npm install && npm run compile`
3. Package with `vsce package` or load the extension in Cursor
4. Look at the **bottom-right status bar** for the usage meter (now includes Bot %)
5. Click it to open the **Token Cockpit** dashboard

## Status bar example

`$(zap) Cursor 15% · Other 22% · $3.40/$20 · Bot 41%`

In rotate mode it also cycles a dedicated `$(robot) GrokBot 41%` variant.

## Privacy & security

- Reads `cursorAuth/accessToken` from your **local** Cursor database (read-only SQLite)
- Uses that token only to call `api2.cursor.sh` (including `/aiserver.v1.DashboardService/GetSandUsageStatus` for Grok Bot)
- Does **not** upload your code, chats, or token elsewhere

## License

MIT (same as upstream)
