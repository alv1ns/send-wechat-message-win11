---
name: send-wechat-message
description: Send or draft WeChat desktop messages on Windows 11 through GUI automation, including opening WeChat, verifying foreground control and UI Automation access, navigating the visible chat list, writing exact Unicode text into the composer through UI Automation or clipboard paste, capturing verification screenshots, and sending only after explicit user confirmation. Use when a user asks to open WeChat or 微信 on Windows, send a message to a contact or another account, prepare a message before sending, confirm delivery with a screenshot, or troubleshoot Codex control of the Windows WeChat app.
---

# Send WeChat Message

This skill can work in two modes on Windows:

- GUI mode for opening WeChat, drafting messages, confirming screenshots, and sending after approval
- WeFlow mode for reading and summarizing group-chat history from WeFlow's local HTTP API without relying on live window scrolling

## Overview

Automate the Windows 11 WeChat desktop client conservatively. Prefer deterministic GUI steps, verify state with screenshots, and never send until the user explicitly confirms.

## Workflow

1. Verify that WeChat is installed and that Codex can control it.
2. Bring the main WeChat or Weixin window to the foreground and capture the current window.
3. Identify whether the target conversation is already visible in the chat list.
4. Prefer clicking the left chat pane once and then using arrow-key navigation in the visible chat list.
5. If the target is a group chat, confirm it has local chat history before relying on search results.
6. Open the target chat, focus the composer, and write the exact message text into the composer.
7. Stop and ask for confirmation before sending.
8. Send only after confirmation, then capture a proof screenshot.
9. Clean temporary screenshots after the user has seen the verification.
10. When the task is to read older messages, scroll the chat history upward in small increments and capture each checkpoint.

## Quick Start

Run the helpers from the skill directory:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\check_wechat_access.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\capture_wechat_window.ps1
```

If both succeed, use the returned screenshot path with `view_image` to understand the current WeChat state before making further inputs.

If WeFlow is installed and its local API service is enabled, prefer that path for summarizing group chats:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\check_weflow_access.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\find_weflow_session.ps1 -Keyword "项目群"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\prepare_weflow_summary.ps1 -SessionKeyword "项目群" -Limit 300
```

The generated text file is intended for Codex to read and summarize.

## WeFlow Integration

When the user wants to summarize a group chat, prefer WeFlow over GUI screenshots if all of the following are true:

1. WeFlow is installed locally
2. the local HTTP API service is running
3. the target group can be found through the WeFlow sessions API

Why prefer WeFlow:

- it reads exported message data directly instead of depending on a visible window
- it supports session lookup, pagination, date filters, and keyword filters
- it can emit ChatLab-compatible output for downstream analysis

Recommended summary workflow:

1. run `scripts\check_weflow_access.ps1`
2. run `scripts\find_weflow_session.ps1 -Keyword "<group name>"`
3. run `scripts\prepare_weflow_summary.ps1 -SessionKeyword "<group name>" -Limit 300`
4. read the generated text file and summarize it for the user

Use GUI scrolling and screenshots only as a fallback when WeFlow is unavailable or the target session is missing from the API.

## Navigation Strategy

Prefer these controls in this order:

1. `scripts\capture_wechat_window.ps1` to inspect which chat is currently selected.
2. `scripts\navigate_chat_list.ps1 -Offset <int>` to move from the current selection to a visible target chat.
3. Capture again and verify the title area matches the intended recipient.

The navigation helper first clicks inside the visible left chat pane and then sends arrow keys. This avoids depending on uncertain global shortcuts while keeping the actual conversation switch deterministic.

If the desired contact is not visible in the current chat list, either:

- use WeChat search manually with screenshots and small verification steps, or
- ask the user to bring the target chat into view before continuing.

This skill is optimized for the visible-chat path because Windows WeChat still exposes a sparse accessibility tree.

In live validation on Windows 11, the most reliable path was:

1. let the user open the target chat manually when it is not already selected
2. capture the main window
3. draft through the composer helper
4. ask for confirmation
5. send and capture proof

## Search Strategy

When the target chat is not visible:

1. Use `Ctrl+F` to focus WeChat search.
2. Type or paste the search text conservatively after verifying focus.
3. Wait for the dropdown results to render.
4. Use arrow keys to move onto the local result.
5. Press Return only after a local chat or group result is highlighted.

Do not press Return immediately after typing into search. In current Windows builds, that can jump into the wrong result or open a different search surface instead of the local conversation.

Treat search-based chat switching as semi-automatic on Windows. After any search attempt, capture the window and verify the title area before drafting or sending. If the title is not correct, stop and ask the user to open the target chat manually.

For group chats, local search works best only when the group already has local history on the current PC. If the group is missing, ask the user to sync or open the group once manually before retrying.

## Drafting The Message

After the correct chat is open:

1. Focus the composer.
2. Use `scripts\focus_composer_and_set_value.ps1 -Message "<message>"` instead of simulated typing.
3. Capture the window and verify that the exact text appears in the composer.

The helper first tries Windows UI Automation `ValuePattern` and falls back to clipboard paste after focusing the composer. This avoids most IME transformations and is more reliable than character-by-character typing.

In live testing, the clipboard-paste fallback was the most reliable path for the current Qt-based Windows WeChat composer.

If the draft needs line breaks, pass real newline characters. Do not build the message as a plain string containing literal `\n`, because WeChat will receive those characters verbatim.

## Sending

Use `scripts\send_current_draft.ps1` only after the user explicitly confirms. The helper first tries to invoke the visible `发送` or `Send` button through UI Automation, then falls back to clicking the bottom-right send area.

## Reading History

When the task is to inspect older messages in a chat:

1. Open the correct conversation first.
2. Capture the current screen state.
3. Use `scripts\scroll_chat_history.ps1` with modest wheel increments so messages are not skipped.
4. Capture again after each scroll window.
5. Stop when you reach the desired date boundary, or when the chat no longer moves upward.

Prefer many small scrolls over a few large jumps. Moderate wheel scrolling is more reliable than `Page Up`, and less likely to skip context than aggressive jumps.

Recommended starting command:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\scroll_chat_history.ps1 -Steps 8 -WheelDelta 120
```

If the history pane does not move, click inside the chat history first or pass explicit focus coordinates.

For a whole review set, capture a sequence into a temporary directory:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\capture_chat_history_sequence.ps1 -MaxPages 20
```

This uses overlapping screenshots and stops when the viewport no longer changes.

## Script List

- `scripts\check_wechat_access.ps1`
- `scripts\check_weflow_access.ps1`
- `scripts\capture_wechat_window.ps1`
- `scripts\find_weflow_session.ps1 -Keyword "<name>"`
- `scripts\export_weflow_messages.ps1 [-Talker <id> | -SessionKeyword <name>]`
- `scripts\prepare_weflow_summary.ps1 [-Talker <id> | -SessionKeyword <name>]`
- `scripts\navigate_chat_list.ps1 -Offset <int>`
- `scripts\focus_composer_and_set_value.ps1 -Message "<message>"`
- `scripts\focus_composer_and_paste.ps1 -Message "<message>"`
- `scripts\send_current_draft.ps1`
- `scripts\scroll_chat_history.ps1 [-Steps <int>] [-WheelDelta <int>] [-FocusX <int>] [-FocusY <int>]`
- `scripts\capture_chat_history_sequence.ps1 [-MaxPages <int>] [-OutDir <path>]`
- `scripts\cleanup_wechat_temp_screenshots.ps1`

## Privacy

This repository is public. Published examples and docs should stay generic:

- do not include real chat screenshots
- do not expose local usernames or sensitive machine paths
- do not publish real contact names or message contents unless intentionally anonymized
- prefer reusable placeholders in examples
- clean temporary screenshots after successful sends

## 中文

`send-wechat-message` 现在改成面向 Windows 11 微信桌面端的 Codex skill，也兼容当前机器上常见的 `Weixin.exe` 安装形式。

现在也支持结合 `WeFlow` 的本地 HTTP API 做群聊总结，不必完全依赖微信窗口滚动截图。

它遵循保守流程：

- 先检查微信安装、窗口前台切换和 UI Automation 可用性
- 用截图确认当前窗口状态
- 在左侧可见会话列表中先点中列表，再用方向键移动
- 优先用 UI Automation 写入输入框；不支持或不稳定时回退到剪贴板粘贴
- 发出前必须先获得用户明确确认
- 发送后再截图留证，并清理临时截图
- 总结群聊时优先走 WeFlow API，拿到结构化消息后再总结

### 典型流程

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\check_wechat_access.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\capture_wechat_window.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\navigate_chat_list.ps1 -Offset 1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\focus_composer_and_set_value.ps1 -Message "hello from Codex"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\send_current_draft.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\capture_wechat_window.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\cleanup_wechat_temp_screenshots.ps1
```

不要在没有用户明确确认的情况下自动发送。验证完成后，应及时清理临时截图。

### 多段消息与换行

`focus_composer_and_set_value.ps1` 支持真实换行。不要把字面量 `\n` 放进普通字符串里再期待脚本自动解释。

推荐这样传：

```powershell
$msg = "第一段`r`n`r`n第二段"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\focus_composer_and_set_value.ps1 -Message $msg
```

### 群聊与搜索经验

- 群聊通常需要当前 Windows 电脑已经有本地聊天记录，搜索结果才更稳定
- 在搜索框输入后不要立刻回车
- 先等结果出现，再用方向键选中目标结果后回车
- Windows 微信里“搜索后自动切换到联系人”目前不够稳，优先让用户手动打开目标会话再继续
- 失焦风险高时，优先截图确认再继续下一步

### 群聊总结优先级

- 如果本机启用了 WeFlow API，优先用 `prepare_weflow_summary.ps1` 导出可总结文本
- 如果 WeFlow 不可用，再退回到微信窗口滚动截图方案
- 涉及最近几百条消息、时间筛选、关键词筛选时，WeFlow 路径明显更稳

### 读取历史消息

- `Page Up` 不一定稳定
- 更稳的做法是先把焦点放到聊天正文区域，再发送小幅滚轮事件
- 先小步滚动、逐屏截图，确认方向和密度后再继续往上读

示例：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\scroll_chat_history.ps1 -Steps 8 -WheelDelta 120
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\capture_wechat_window.ps1
```
