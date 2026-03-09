# Troubleshooting

## WeChat Not Found

If `WeChat.exe` is not discovered automatically, check these common Windows paths:

```powershell
$env:LOCALAPPDATA\Tencent\WeChat\WeChat.exe
$env:LOCALAPPDATA\Programs\Tencent\WeChat\WeChat.exe
$env:ProgramFiles\Tencent\WeChat\WeChat.exe
${env:ProgramFiles(x86)}\Tencent\WeChat\WeChat.exe
$env:USERPROFILE\Weixin\Weixin.exe
```

If WeChat is installed elsewhere, add that directory to `PATH` or update the helper. Some current Windows installs use `Weixin.exe` under the user profile instead of `WeChat.exe`.

## WeFlow API Is Not Reachable

Symptoms:

- `check_weflow_access.ps1` fails
- requests to `http://127.0.0.1:5031/health` time out
- session queries return connection errors

Fixes:

1. open WeFlow
2. go to `设置` -> `API 服务`
3. click `启动服务`
4. rerun:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\check_weflow_access.ps1
```

If WeFlow is listening on a non-default address, set `WEFLOW_BASE_URL` before running the scripts.

## WeFlow Finds Multiple Sessions

If `prepare_weflow_summary.ps1` reports multiple matches for the same keyword, refine the search keyword or pass the exact `talker` ID instead.

Use:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\find_weflow_session.ps1 -Keyword "项目群"
```

Then rerun with the selected `username` via `-Talker`.

## WeChat Opens But Cannot Be Controlled

Symptoms:

- WeChat launches, but the window never comes to the foreground
- screenshots capture the wrong app
- `check_wechat_access.ps1` fails while reading the main window

Fixes:

1. Unlock the desktop session and keep WeChat on the interactive desktop.
2. Avoid running WeChat elevated while Codex is not elevated.
3. Re-run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\check_wechat_access.ps1
```

## Chat List Moves In The Wrong Place

`navigate_chat_list.ps1` assumes the standard left-pane chat list layout.

Preferred recovery:

1. capture the current window
2. confirm the left chat list is visible
3. click the intended row manually once if needed
4. retry `navigate_chat_list.ps1`

## Search Finds A Chat But Does Not Switch Into It

This is a known behavior in the current Windows flow: search can populate the result visually without reliably switching the active conversation.

Preferred recovery:

1. do not trust search alone
2. capture the window and verify the chat title after the search action
3. if the title is still wrong, ask the user to open the target chat manually
4. only draft after the title area matches the intended target

## Paste Does Nothing

The composer helper first attempts UI Automation `ValuePattern`, then falls back to clipboard paste. If nothing appears in the draft:

1. make sure the correct conversation is open
2. capture the window and confirm the composer is visible
3. retry the helper
4. if it still fails, click the input box manually once and rerun the same script

Use:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\focus_composer_and_set_value.ps1 -Message "<message>"
```

In live testing, the clipboard-paste fallback worked more reliably than trying to read or re-query the Qt input box value afterward.

## Group Chat Cannot Be Found

On Windows WeChat, group chats are easier to reopen when the current PC already has local history for that group.

If a group does not appear in local results:

- ask the user to sync or open the group once manually
- then retry the same search flow

## Typed Chinese Text Changes Unexpectedly

Character-by-character typing is more vulnerable to IME interference.

Preferred fix:

- do not simulate long text typing
- use `focus_composer_and_set_value.ps1`, which prefers UI Automation and otherwise pastes the full Unicode message in one step

## Literal `\n` Appears In The Draft

Pass real newlines, not the two characters `\` and `n`.

Preferred fix:

```powershell
$msg = "First paragraph`r`n`r`nSecond paragraph"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\focus_composer_and_set_value.ps1 -Message $msg
```

## Screenshot Captures The Wrong Window

Use `capture_wechat_window.ps1` instead of ad hoc capture tooling. The helper activates WeChat, reads the current window rectangle, and captures only that area.

If the screenshot is still wrong:

- make sure WeChat has a visible main window
- restore it from the taskbar if minimized
- rerun the capture helper

## History Does Not Scroll

If `Page Up` works inconsistently, use the provided wheel-scrolling helper instead:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\scroll_chat_history.ps1 -Steps 8 -WheelDelta 120
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\capture_wechat_window.ps1
```

If scrolling still does nothing, retry with explicit focus coordinates inside the message area:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\scroll_chat_history.ps1 -Steps 8 -WheelDelta 120 -FocusX 900 -FocusY 360
```

## Need A Reviewable Screenshot Set

When you need a whole review set, use:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\capture_chat_history_sequence.ps1 -MaxPages 20
```

It captures overlapping pages into a temporary directory and records hashes in `metadata.txt`.
