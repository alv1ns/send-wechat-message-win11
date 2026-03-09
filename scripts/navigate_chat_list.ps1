param([Parameter(Mandatory)][int]$Offset)

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $scriptRoot 'wechat_common.ps1')

if ($Offset -eq 0) {
    return
}

$process = Get-OrStartWeChatProcess
$window = Get-WeChatWindowInfo -Process $process
[void](Focus-WeChatChatList -Window $window)

$steps = [Math]::Abs($Offset)
$key = if ($Offset -gt 0) { '{DOWN}' } else { '{UP}' }

for ($index = 0; $index -lt $steps; $index++) {
    Send-WeChatKeys -Keys $key
}

Write-Output "Moved the visible chat-list selection by $Offset row(s)."
