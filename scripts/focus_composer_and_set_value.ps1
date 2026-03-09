param([Parameter(Mandatory)][string]$Message)

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $scriptRoot 'wechat_common.ps1')

$process = Get-OrStartWeChatProcess
$window = Get-WeChatWindowInfo -Process $process

if (Try-SetWeChatComposerValue -Window $window -Message $Message) {
    Write-Output 'Message written into the composer through UI Automation.'
    return
}

[void](Focus-WeChatComposer -Window $window)
Send-WeChatKeys -Keys '^a'

if ([string]::IsNullOrEmpty($Message)) {
    Send-WeChatKeys -Keys '{BACKSPACE}'
    Write-Output 'Composer cleared.'
    return
}

$snapshot = Save-WeChatClipboardSnapshot

try {
    Set-WeChatClipboardText -Text $Message
    Send-WeChatKeys -Keys '^v'
}
finally {
    Restore-WeChatClipboardSnapshot -Snapshot $snapshot
}

Write-Output 'Message pasted into the composer.'
