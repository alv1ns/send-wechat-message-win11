# send-wechat-message

A Codex skill for sending WeChat desktop messages on Windows 11.

It now also supports integrating with [WeFlow](https://github.com/hicccc77/WeFlow) as a local chat-history source for group-chat summarization.

## What changed

- Replaced the macOS `osascript` and Accessibility workflow with Windows foreground activation, UI Automation, clipboard, and screen-capture helpers.
- Rewrote the skill instructions around the Windows WeChat desktop client.
- Swapped the shell helpers from `.sh` to `.ps1`.
- Added compatibility for installations that expose `Weixin.exe` instead of `WeChat.exe`.

## Included scripts

- `scripts\check_wechat_access.ps1`
- `scripts\check_weflow_access.ps1`
- `scripts\capture_wechat_window.ps1`
- `scripts\find_weflow_session.ps1`
- `scripts\export_weflow_messages.ps1`
- `scripts\prepare_weflow_summary.ps1`
- `scripts\navigate_chat_list.ps1`
- `scripts\focus_composer_and_set_value.ps1`
- `scripts\focus_composer_and_paste.ps1`
- `scripts\send_current_draft.ps1`
- `scripts\scroll_chat_history.ps1`
- `scripts\capture_chat_history_sequence.ps1`
- `scripts\cleanup_wechat_temp_screenshots.ps1`

## Quick start

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\check_wechat_access.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\capture_wechat_window.ps1
```

Then use the screenshot output to verify the current WeChat state before drafting or sending any message.

## Tested best path

Based on live validation on this machine, the most reliable Windows workflow is:

- manually open the target chat if it is not already active
- use `scripts\focus_composer_and_set_value.ps1` to draft
- confirm the draft from a screenshot
- send only after explicit approval

Search-driven chat switching is still semi-automatic and should be followed by a screenshot check before drafting.

## WeFlow mode

If you have WeFlow running locally with its API service enabled, use it as the preferred source for group-chat summaries:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\check_weflow_access.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\find_weflow_session.ps1 -Keyword "项目群"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\prepare_weflow_summary.ps1 -SessionKeyword "项目群" -Limit 300
```

This path uses WeFlow's local API on `http://127.0.0.1:5031` by default and avoids brittle GUI scrolling for large summaries.

## Draft safely

```powershell
$msg = "hello from Codex"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\focus_composer_and_set_value.ps1 -Message $msg
```

The helper tries UI Automation first and falls back to clipboard paste if the composer does not expose a writable value pattern. In live testing, the clipboard-paste fallback was the most reliable path for the current Qt-based WeChat input box.

## Send only after confirmation

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\send_current_draft.ps1
```

The intended workflow is still conservative: draft first, ask the user to confirm, then send and capture proof.
