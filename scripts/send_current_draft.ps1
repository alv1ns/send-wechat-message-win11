$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $scriptRoot 'wechat_common.ps1')

$process = Get-OrStartWeChatProcess
$window = Get-WeChatWindowInfo -Process $process
$button = Find-WeChatSendButtonElement -Window $window

if ($button) {
    if (Try-InvokeWeChatElement -Element $button) {
        Write-Output 'Current draft sent through the WeChat send button.'
        return
    }

    $point = Get-WeChatElementCenterPoint -Element $button
    if ($point) {
        Invoke-WeChatClick -X $point.X -Y $point.Y
        Write-Output 'Current draft sent by clicking the WeChat send button.'
        return
    }
}

$fallbackPoint = Get-WeChatRelativePoint -Window $window -XRatio 0.92 -YRatio 0.93
Invoke-WeChatClick -X $fallbackPoint.X -Y $fallbackPoint.Y

Write-Output 'Current draft sent by clicking the bottom-right send area.'
