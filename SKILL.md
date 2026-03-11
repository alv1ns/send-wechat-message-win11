---
name: send-wechat-message
description: Send or draft WeChat desktop messages on Windows 11 through GUI automation, including opening WeChat, verifying foreground control and UI Automation access, navigating the visible chat list, checking the active chat title, writing exact Unicode text into the composer through UI Automation or clipboard paste, capturing verification screenshots, and sending only after explicit user confirmation. It also supports WeFlow-based group-chat summarization through the local HTTP API. Use when a user asks to open WeChat or 微信 on Windows, send a message to a contact or another account, prepare a message before sending, confirm delivery with a screenshot, summarize a group chat, or troubleshoot Codex control of the Windows WeChat app.
---

# Send WeChat Message

## Overview

This skill supports two Windows workflows:

- GUI mode for opening WeChat, checking the active chat title, drafting messages, verifying screenshots, and sending after approval
- WeFlow mode for reading and summarizing group-chat history from WeFlow's local HTTP API without relying on live scrolling

Prefer deterministic steps, verify state with screenshots or title checks, and never send until the user explicitly confirms.

## Quick Start

For GUI mode:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\check_wechat_access.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\capture_wechat_window.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\get_active_chat_title.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\get_active_chat_title.ps1 -Expected "文件传输助手" -Exact
```

For WeFlow mode:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\check_weflow_access.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\find_weflow_session.ps1 -Keyword "项目群"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\prepare_weflow_summary.ps1 -SessionKeyword "项目群" -Limit 300
```

## GUI Workflow

1. Verify that WeChat is installed and controllable.
2. Bring the main WeChat or Weixin window to the foreground.
3. Capture the current window.
4. Run `scripts\get_active_chat_title.ps1` when you need a quick title-level verification, or pass `-Expected` for a fail-fast check.
5. Open or manually confirm the correct conversation.
6. Focus the composer and write the exact message text.
7. Stop and ask for confirmation before sending.
8. Send only after confirmation, then capture proof.
9. Clean temporary screenshots after the user has seen the verification.

## Search Strategy

Treat search-based chat switching as semi-automatic on Windows.

When the target chat is not visible:

1. Use `Ctrl+F` to focus WeChat search.
2. Type or paste the search text conservatively.
3. Wait for the dropdown results.
4. Try keyboard selection only after the result is visibly highlighted.
5. Capture the window and verify the title area.
6. Run `scripts\get_active_chat_title.ps1` if you want a quick text-level title check, or use `-Expected` to verify the exact chat before drafting.
7. If the title is still wrong, ask the user to open the target chat manually.

## Drafting The Message

After the correct chat is open:

1. Focus the composer.
2. Use `scripts\focus_composer_and_set_value.ps1 -Message "<message>"` instead of simulated typing.
3. Capture the window and verify that the exact text appears in the composer.

The helper first tries Windows UI Automation `ValuePattern` and falls back to clipboard paste. In live testing, the clipboard-paste fallback was the most reliable path for the current Qt-based Windows WeChat composer.

## Sending

Use `scripts\send_current_draft.ps1` only after the user explicitly confirms.

The helper first tries to invoke the visible send button through UI Automation, then falls back to clicking the bottom-right send area.

## Reading History

When the task is to inspect older messages in a chat:

1. Open the correct conversation.
2. Capture the current state.
3. Use `scripts\scroll_chat_history.ps1` with modest wheel increments.
4. Capture again after each scroll window.
5. Stop when you reach the desired date boundary or the chat no longer moves upward.

For a review set, use `scripts\capture_chat_history_sequence.ps1 -MaxPages 20`.

## WeFlow Integration

Group-chat summaries in this branch are WeFlow-only. Ensure:

1. WeFlow is installed locally
2. the local HTTP API service is running
3. the target group can be found through the WeFlow sessions API

Recommended summary workflow:

1. run `scripts\check_weflow_access.ps1`
2. run `scripts\find_weflow_session.ps1 -Keyword "<group name>"`
3. run `scripts\prepare_weflow_summary.ps1 -SessionKeyword "<group name>" -Limit 300`
4. read the generated text file and summarize it for the user



## Script List

- `scripts\check_wechat_access.ps1`
- `scripts\check_weflow_access.ps1`
- `scripts\capture_wechat_window.ps1`
- `scripts\get_active_chat_title.ps1 [-Expected "<name>"] [-Exact]`
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

This repository is public. Keep examples generic:

- do not include real chat screenshots
- do not expose local usernames or sensitive machine paths
- do not publish real contact names or message contents unless intentionally anonymized
- prefer reusable placeholders in examples
- clean temporary screenshots after successful sends









