Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not ('WeChatNativeMethods' -as [type])) {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
    Add-Type -AssemblyName UIAutomationClient
    Add-Type -AssemblyName UIAutomationTypes
    Add-Type @"
using System;
using System.Runtime.InteropServices;

public struct RECT {
    public int Left;
    public int Top;
    public int Right;
    public int Bottom;
}

public static class WeChatNativeMethods {
    [DllImport("user32.dll")]
    public static extern bool SetForegroundWindow(IntPtr hWnd);

    [DllImport("user32.dll")]
    public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);

    [DllImport("user32.dll")]
    public static extern bool GetWindowRect(IntPtr hWnd, out RECT rect);

    [DllImport("user32.dll")]
    public static extern bool SetCursorPos(int x, int y);

    [DllImport("user32.dll")]
    public static extern void mouse_event(uint dwFlags, uint dx, uint dy, uint dwData, UIntPtr dwExtraInfo);
}
"@
}

function Get-WeChatStateDirectory {
    $path = Join-Path ([System.IO.Path]::GetTempPath()) 'send-wechat-message'
    if (-not (Test-Path -LiteralPath $path)) {
        New-Item -ItemType Directory -Path $path | Out-Null
    }
    $path
}

function Get-WeChatCaptureStateFile {
    Join-Path (Get-WeChatStateDirectory) 'captures.txt'
}

function Add-WeChatCaptureRecord {
    param([Parameter(Mandatory)][string]$Path)

    Add-Content -Path (Get-WeChatCaptureStateFile) -Value $Path
}

function New-WeChatTempPngPath {
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss-fff'
    Join-Path ([System.IO.Path]::GetTempPath()) "wechat-window-$stamp.png"
}

function Get-WeChatExecutablePath {
    $command = Get-Command 'WeChat.exe' -ErrorAction SilentlyContinue
    if ($command) {
        return $command.Source
    }

    $command = Get-Command 'Weixin.exe' -ErrorAction SilentlyContinue
    if ($command) {
        return $command.Source
    }

    $candidates = @(
        (Join-Path $env:LOCALAPPDATA 'Tencent\WeChat\WeChat.exe'),
        (Join-Path $env:LOCALAPPDATA 'Programs\Tencent\WeChat\WeChat.exe'),
        (Join-Path $env:ProgramFiles 'Tencent\WeChat\WeChat.exe'),
        (Join-Path ${env:ProgramFiles(x86)} 'Tencent\WeChat\WeChat.exe'),
        (Join-Path $env:USERPROFILE 'Weixin\Weixin.exe')
    ) | Where-Object { $_ -and (Test-Path -LiteralPath $_) }

    $candidates | Select-Object -First 1
}

function Wait-WeChatMainWindow {
    param(
        [Parameter(Mandatory)][System.Diagnostics.Process]$Process,
        [int]$TimeoutSeconds = 15
    )

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    while ((Get-Date) -lt $deadline) {
        $Process.Refresh()
        if ($Process.MainWindowHandle -ne 0) {
            return $Process
        }
        Start-Sleep -Milliseconds 300
    }

    throw "WeChat started, but no main window was detected within $TimeoutSeconds seconds."
}

function Get-WeChatProcess {
    $candidates = @('WeChat', 'Weixin') |
        ForEach-Object { Get-Process -Name $_ -ErrorAction SilentlyContinue } |
        Where-Object { $_.MainWindowHandle -ne 0 }

    $wechatTitle = "`u{5FAE}`u{4FE1}"
    $preferred = $candidates |
        Where-Object { $_.MainWindowTitle -eq $wechatTitle }

    if ($preferred) {
        return ($preferred | Select-Object -First 1)
    }

    $candidates | Select-Object -First 1
}

function Get-OrStartWeChatProcess {
    $process = Get-WeChatProcess
    if ($process) {
        return $process
    }

    $exe = Get-WeChatExecutablePath
    if (-not $exe) {
        throw 'WeChat or Weixin was not found in the common install locations.'
    }

    $process = Start-Process -FilePath $exe -PassThru
    Start-Sleep -Seconds 1
    Wait-WeChatMainWindow -Process $process
}

function Activate-WeChatWindow {
    param([Parameter(Mandatory)][System.Diagnostics.Process]$Process)

    $Process = Wait-WeChatMainWindow -Process $Process

    [void][WeChatNativeMethods]::ShowWindowAsync($Process.MainWindowHandle, 9)
    [void][WeChatNativeMethods]::SetForegroundWindow($Process.MainWindowHandle)

    try {
        $shell = New-Object -ComObject WScript.Shell
        [void]$shell.AppActivate($Process.Id)
    }
    catch {
    }

    Start-Sleep -Milliseconds 250
    $Process.Refresh()
    $Process
}

function Get-WeChatWindowInfo {
    param([Parameter(Mandatory)][System.Diagnostics.Process]$Process)

    $Process = Activate-WeChatWindow -Process $Process
    $rect = New-Object RECT

    if (-not [WeChatNativeMethods]::GetWindowRect($Process.MainWindowHandle, [ref]$rect)) {
        throw 'Failed to read the WeChat window bounds.'
    }

    [pscustomobject]@{
        Process = $Process
        Handle  = $Process.MainWindowHandle
        Left    = $rect.Left
        Top     = $rect.Top
        Right   = $rect.Right
        Bottom  = $rect.Bottom
        Width   = $rect.Right - $rect.Left
        Height  = $rect.Bottom - $rect.Top
    }
}

function Resolve-WeChatOutputPath {
    param([string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return (New-WeChatTempPngPath)
    }

    $fullPath = [System.IO.Path]::GetFullPath($Path)
    $directory = Split-Path -Parent $fullPath
    if ($directory -and -not (Test-Path -LiteralPath $directory)) {
        New-Item -ItemType Directory -Path $directory | Out-Null
    }
    $fullPath
}

function Save-WeChatWindowCapture {
    param(
        [Parameter(Mandatory)][pscustomobject]$Window,
        [Parameter(Mandatory)][string]$Path
    )

    $bitmap = New-Object System.Drawing.Bitmap $Window.Width, $Window.Height
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)

    try {
        $graphics.CopyFromScreen($Window.Left, $Window.Top, 0, 0, $bitmap.Size)
        $bitmap.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png)
    }
    finally {
        $graphics.Dispose()
        $bitmap.Dispose()
    }
}

function Get-WeChatRelativePoint {
    param(
        [Parameter(Mandatory)][pscustomobject]$Window,
        [Parameter(Mandatory)][double]$XRatio,
        [Parameter(Mandatory)][double]$YRatio
    )

    [pscustomobject]@{
        X = [int][Math]::Round($Window.Left + ($Window.Width * $XRatio))
        Y = [int][Math]::Round($Window.Top + ($Window.Height * $YRatio))
    }
}

function Invoke-WeChatClick {
    param(
        [Parameter(Mandatory)][int]$X,
        [Parameter(Mandatory)][int]$Y
    )

    [void][WeChatNativeMethods]::SetCursorPos($X, $Y)
    Start-Sleep -Milliseconds 80
    [WeChatNativeMethods]::mouse_event(0x0002, 0, 0, 0, [UIntPtr]::Zero)
    [WeChatNativeMethods]::mouse_event(0x0004, 0, 0, 0, [UIntPtr]::Zero)
    Start-Sleep -Milliseconds 120
}

function Invoke-WeChatDrag {
    param(
        [Parameter(Mandatory)][int]$StartX,
        [Parameter(Mandatory)][int]$StartY,
        [Parameter(Mandatory)][int]$EndX,
        [Parameter(Mandatory)][int]$EndY,
        [int]$HoldMs = 60
    )

    [void][WeChatNativeMethods]::SetCursorPos($StartX, $StartY)
    Start-Sleep -Milliseconds 80
    [WeChatNativeMethods]::mouse_event(0x0002, 0, 0, 0, [UIntPtr]::Zero)
    Start-Sleep -Milliseconds $HoldMs
    [void][WeChatNativeMethods]::SetCursorPos($EndX, $EndY)
    Start-Sleep -Milliseconds 80
    [WeChatNativeMethods]::mouse_event(0x0004, 0, 0, 0, [UIntPtr]::Zero)
    Start-Sleep -Milliseconds 120
}

function ConvertTo-WeChatWheelData {
    param([int]$Delta)

    [BitConverter]::ToUInt32([BitConverter]::GetBytes($Delta), 0)
}

function Invoke-WeChatWheel {
    param([int]$Delta)

    [WeChatNativeMethods]::mouse_event(0x0800, 0, 0, (ConvertTo-WeChatWheelData -Delta $Delta), [UIntPtr]::Zero)
    Start-Sleep -Milliseconds 60
}

function Send-WeChatKeys {
    param([Parameter(Mandatory)][string]$Keys)

    [System.Windows.Forms.SendKeys]::SendWait($Keys)
    Start-Sleep -Milliseconds 120
}

function Focus-WeChatChatList {
    param([Parameter(Mandatory)][pscustomobject]$Window)

    $point = Get-WeChatRelativePoint -Window $Window -XRatio 0.14 -YRatio 0.26
    Invoke-WeChatClick -X $point.X -Y $point.Y
    $point
}

function Focus-WeChatComposer {
    param([Parameter(Mandatory)][pscustomobject]$Window)

    $point = Get-WeChatRelativePoint -Window $Window -XRatio 0.66 -YRatio 0.88
    Invoke-WeChatClick -X $point.X -Y $point.Y
    $point
}

function Focus-WeChatHistory {
    param([Parameter(Mandatory)][pscustomobject]$Window)

    $point = Get-WeChatRelativePoint -Window $Window -XRatio 0.64 -YRatio 0.32
    Invoke-WeChatClick -X $point.X -Y $point.Y
    $point
}

function Get-WeChatAutomationRoot {
    param([Parameter(Mandatory)][pscustomobject]$Window)

    [System.Windows.Automation.AutomationElement]::FromHandle($Window.Handle)
}

function Find-WeChatComposerElement {
    param([Parameter(Mandatory)][pscustomobject]$Window)

    $root = Get-WeChatAutomationRoot -Window $Window
    if (-not $root) {
        return $null
    }

    $condition = New-Object System.Windows.Automation.PropertyCondition(
        [System.Windows.Automation.AutomationElement]::ControlTypeProperty,
        [System.Windows.Automation.ControlType]::Edit
    )

    $elements = $root.FindAll([System.Windows.Automation.TreeScope]::Descendants, $condition)
    foreach ($element in $elements) {
        $rect = $element.Current.BoundingRectangle
        if ($rect.Height -lt 20) {
            continue
        }
        if ($rect.Bottom -lt ($Window.Top + ($Window.Height * 0.68))) {
            continue
        }
        return $element
    }

    $null
}

function Try-SetWeChatComposerValue {
    param(
        [Parameter(Mandatory)][pscustomobject]$Window,
        [Parameter(Mandatory)][string]$Message
    )

    $composer = Find-WeChatComposerElement -Window $Window
    if (-not $composer) {
        return $false
    }

    try {
        $composer.SetFocus()
        Start-Sleep -Milliseconds 120
    }
    catch {
    }

    try {
        $pattern = $composer.GetCurrentPattern([System.Windows.Automation.ValuePattern]::Pattern)
        if ($pattern) {
            $pattern.SetValue($Message)
            return $true
        }
    }
    catch {
    }

    $false
}

function Find-WeChatSendButtonElement {
    param([Parameter(Mandatory)][pscustomobject]$Window)

    $root = Get-WeChatAutomationRoot -Window $Window
    if (-not $root) {
        return $null
    }

    $condition = New-Object System.Windows.Automation.PropertyCondition(
        [System.Windows.Automation.AutomationElement]::ControlTypeProperty,
        [System.Windows.Automation.ControlType]::Button
    )

    $elements = $root.FindAll([System.Windows.Automation.TreeScope]::Descendants, $condition)
    foreach ($element in $elements) {
        $name = $element.Current.Name
        if ([string]::IsNullOrWhiteSpace($name)) {
            continue
        }
        $sendLabel = "`u{53D1}`u{9001}"
        if ($name -like "*$sendLabel*" -or $name -like '*Send*') {
            return $element
        }
    }

    $null
}

function Try-InvokeWeChatElement {
    param([Parameter(Mandatory)]$Element)

    try {
        $pattern = $Element.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern)
        if ($pattern) {
            $pattern.Invoke()
            return $true
        }
    }
    catch {
    }

    $false
}

function Get-WeChatElementCenterPoint {
    param([Parameter(Mandatory)]$Element)

    $rect = $Element.Current.BoundingRectangle
    if ($rect.Width -le 0 -or $rect.Height -le 0) {
        return $null
    }

    [pscustomobject]@{
        X = [int][Math]::Round($rect.Left + ($rect.Width / 2))
        Y = [int][Math]::Round($rect.Top + ($rect.Height / 2))
    }
}

function Save-WeChatClipboardSnapshot {
    try {
        [System.Windows.Forms.Clipboard]::GetDataObject()
    }
    catch {
        $null
    }
}

function Set-WeChatClipboardText {
    param([Parameter(Mandatory)][string]$Text)

    [System.Windows.Forms.Clipboard]::SetText($Text)
}

function Restore-WeChatClipboardSnapshot {
    param($Snapshot)

    if ($null -eq $Snapshot) {
        return
    }

    try {
        [System.Windows.Forms.Clipboard]::SetDataObject($Snapshot, $true)
    }
    catch {
    }
}
