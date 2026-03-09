# send-wechat-message

## Attribution

This repository is a fork/adaptation of [tonyshield/send-wechat-message](https://github.com/tonyshield/send-wechat-message), with Windows 11 WeChat support and WeFlow integration added in this fork.

## Acknowledgements

- Forked from and inspired by [tonyshield/send-wechat-message](https://github.com/tonyshield/send-wechat-message).
- Group-chat summarization support in this fork is integrated with [hicccc77/WeFlow](https://github.com/hicccc77/WeFlow).
- WeFlow itself credits other upstream projects in its own README. This fork does not directly vendor those projects' code, so they are not duplicated here; please also see the acknowledgements section in the WeFlow repository for its direct upstream credits.

## English

`send-wechat-message` is a Codex skill for controlling the Windows 11 WeChat desktop app through conservative GUI automation.

It is designed for a conservative workflow:

- verify WeChat or Weixin and window control first
- prefer the main WeChat window titled `微信`
- draft the exact message into the composer
- ask for explicit confirmation before sending
- capture screenshots for verification

It also supports integrating with [WeFlow](https://github.com/hicccc77/WeFlow) as a local chat-history source for group-chat summarization.

### Why Windows uses paste fallback

Live testing showed that the current Qt-based Windows WeChat composer does not always expose a reliable writable value that can be read back after insertion.

The shipped helper therefore prefers this order:

- try UI Automation `ValuePattern`
- fall back to clipboard paste after focusing the composer

In live validation on this machine, the clipboard-paste fallback was the most reliable path.

### Scripts

- `scripts/check_wechat_access.ps1`
- `scripts/check_weflow_access.ps1`
- `scripts/capture_wechat_window.ps1`
- `scripts/find_weflow_session.ps1 -Keyword "<name>"`
- `scripts/export_weflow_messages.ps1 [-Talker <id> | -SessionKeyword <name>]`
- `scripts/prepare_weflow_summary.ps1 [-Talker <id> | -SessionKeyword <name>]`
- `scripts/navigate_chat_list.ps1 -Offset <int>`
- `scripts/focus_composer_and_set_value.ps1 -Message "<message>"`
- `scripts/focus_composer_and_paste.ps1 -Message "<message>"` (compatibility wrapper)
- `scripts/scroll_chat_history.ps1 [-Steps <int>] [-WheelDelta <int>] [-FocusX <int>] [-FocusY <int>]`
- `scripts/capture_chat_history_sequence.ps1 [-MaxPages <int>] [-OutDir <path>]`
- `scripts/send_current_draft.ps1`
- `scripts/cleanup_wechat_temp_screenshots.ps1`

### Typical flow

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\check_wechat_access.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\capture_wechat_window.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\focus_composer_and_set_value.ps1 -Message "hello from Codex"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\capture_wechat_window.ps1
```

Do not send automatically without explicit user confirmation.

After verification, clean temporary screenshots.

### Multiline messages

`focus_composer_and_set_value.ps1` accepts real newline characters. Do not pass literal `\n` sequences in a plain string and expect them to be reinterpreted.

Prefer this form:

```powershell
$msg = "First paragraph`r`n`r`nSecond paragraph"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\focus_composer_and_set_value.ps1 -Message $msg
```

### Group chat and search notes

- Group-chat search works better only after local history exists on the current Windows client.
- In search, do not press `Enter` immediately after entering text.
- Search-based chat switching is still semi-automatic on Windows.
- After any search attempt, capture the window and verify the title area before drafting or sending.
- If the title is not correct, ask the user to open the target chat manually.

### Reading chat history

- `Page Up` is not reliable for WeChat history reading.
- A better approach is to focus the chat body and send small wheel-scroll events.
- Use small increments first, capture each checkpoint, and stop when the date boundary is reached.

Example:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\scroll_chat_history.ps1 -Steps 8 -WheelDelta 120
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\capture_wechat_window.ps1
```

The helper computes a default focus point inside the chat-history pane, so you usually do not need to pass coordinates manually.

For a whole review set, capture a sequence into a temporary directory:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\capture_chat_history_sequence.ps1 -MaxPages 20
```

This uses overlapping screenshots and stops when the viewport no longer changes.

### WeFlow mode

If WeFlow is installed locally and its API service is enabled, prefer it for summarizing group chats:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\check_weflow_access.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\find_weflow_session.ps1 -Keyword "项目群"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\prepare_weflow_summary.ps1 -SessionKeyword "项目群" -Limit 300
```

This path uses WeFlow's local API on `http://127.0.0.1:5031` by default and avoids brittle GUI scrolling for large summaries.

### Privacy

This repository is public. Published examples and docs should stay generic:

- do not include real chat screenshots
- do not expose local usernames or sensitive machine paths
- do not publish real contact names or message contents unless intentionally anonymized
- prefer reusable placeholders in examples
- clean temporary screenshots after successful sends

## 中文

### 致谢

- 本项目 fork / 改造自 [tonyshield/send-wechat-message](https://github.com/tonyshield/send-wechat-message)。
- 本分支的群聊总结能力集成了 [hicccc77/WeFlow](https://github.com/hicccc77/WeFlow)。
- `WeFlow` 在其 README 中还致谢了其他上游项目。由于本仓库没有直接 vendoring 这些项目的代码，这里不重复逐一列出；如需查看其直接上游致谢，请同时参考 WeFlow 仓库中的致谢说明。

`send-wechat-message` 是一个用于控制 Windows 11 微信桌面端的 Codex skill，基于偏保守的 GUI 自动化流程。

它遵循保守流程：

- 先检查微信 / `Weixin.exe` 安装和窗口控制能力
- 优先定位标题为 `微信` 的主窗口
- 把消息准确写进输入框
- 发送前必须先获得用户明确确认
- 用截图验证当前状态和发送结果

它也支持结合 [WeFlow](https://github.com/hicccc77/WeFlow) 的本地 HTTP API 做群聊总结，不必完全依赖微信窗口滚动截图。

### 为什么 Windows 版优先保留粘贴回退

实测里，当前 Qt 版本的 Windows 微信输入框并不总是能稳定暴露可读回的写入值。

因此默认顺序是：

- 先尝试 UI Automation `ValuePattern`
- 不稳定时回退到剪贴板粘贴

在这台机器上的实测结果里，剪贴板粘贴是更稳的路径。

### 脚本列表

- `scripts/check_wechat_access.ps1`
- `scripts/check_weflow_access.ps1`
- `scripts/capture_wechat_window.ps1`
- `scripts/find_weflow_session.ps1 -Keyword "<名称>"`
- `scripts/export_weflow_messages.ps1 [-Talker <id> | -SessionKeyword <name>]`
- `scripts/prepare_weflow_summary.ps1 [-Talker <id> | -SessionKeyword <name>]`
- `scripts/navigate_chat_list.ps1 -Offset <int>`
- `scripts/focus_composer_and_set_value.ps1 -Message "<message>"`
- `scripts/focus_composer_and_paste.ps1 -Message "<message>"`（兼容包装脚本）
- `scripts/scroll_chat_history.ps1 [-Steps <int>] [-WheelDelta <int>] [-FocusX <int>] [-FocusY <int>]`
- `scripts/capture_chat_history_sequence.ps1 [-MaxPages <int>] [-OutDir <path>]`
- `scripts/send_current_draft.ps1`
- `scripts/cleanup_wechat_temp_screenshots.ps1`

### 典型流程

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\check_wechat_access.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\capture_wechat_window.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\focus_composer_and_set_value.ps1 -Message "hello from Codex"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\capture_wechat_window.ps1
```

不要在没有用户明确确认的情况下自动发送。

验证完成后，应及时清理临时截图。

### 多段消息与换行

`focus_composer_and_set_value.ps1` 支持真实换行。不要把字面量 `\n` 放进普通字符串里再期待脚本自动解释。

推荐这样传：

```powershell
$msg = "第一段`r`n`r`n第二段"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\focus_composer_and_set_value.ps1 -Message $msg
```

### 群聊与搜索经验

- 群聊通常需要当前 Windows 电脑已经有本地聊天记录，搜索结果才更稳定。
- 在搜索框输入后不要立刻回车。
- Windows 里的“搜索后自动切换到联系人 / 群聊”目前仍不够稳。
- 每次搜索后都应该截图确认标题栏，再继续草稿或发送。
- 如果标题不对，优先让用户手动打开目标会话。

### 读取历史消息

- `Page Up` 对微信历史读取并不稳定。
- 更稳的做法是先把焦点落在聊天正文区域，再发送小幅滚轮事件。
- 先小步滚动、逐屏截图，确认方向和密度后再继续往上读。

示例：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\scroll_chat_history.ps1 -Steps 8 -WheelDelta 120
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\capture_wechat_window.ps1
```

脚本会自动计算聊天正文区域的焦点位置，通常不需要手动传坐标。

如果要把整段历史截图下来给人审核，更适合直接跑：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\capture_chat_history_sequence.ps1 -MaxPages 20
```

它会在临时目录里生成一组带重叠的历史截图，并在滚不动时自动停下。

### WeFlow 总结模式

如果本机安装了 WeFlow 且已经启用 API 服务，优先用它做群聊总结：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\check_weflow_access.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\find_weflow_session.ps1 -Keyword "项目群"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\prepare_weflow_summary.ps1 -SessionKeyword "项目群" -Limit 300
```

默认使用 `http://127.0.0.1:5031` 的本地 API，比 GUI 滚动截图更适合做大批量群聊总结。

### 隐私约束

这个仓库是公开的，文档和示例需要保持通用化：

- 不要提交真实聊天截图
- 不要暴露本机用户名或敏感路径
- 不要公开真实联系人名称或真实消息内容，除非已经明确做过匿名化
- 示例里优先使用可复用的占位写法
- 发送验证完成后应及时清理临时截图

