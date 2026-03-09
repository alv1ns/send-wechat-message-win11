$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $scriptRoot 'wechat_common.ps1')

$process = Get-OrStartWeChatProcess
$window = Get-WeChatWindowInfo -Process $process
$root = Get-WeChatAutomationRoot -Window $window

if (-not $root) {
    throw 'WeChat opened, but Windows UI Automation could not inspect the main window.'
}

Write-Output 'WeChat is installed and the main window is controllable through foreground activation and UI Automation.'
