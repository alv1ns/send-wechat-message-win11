param([string]$OutPath)

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $scriptRoot 'wechat_common.ps1')

$process = Get-OrStartWeChatProcess
$window = Get-WeChatWindowInfo -Process $process
$resolvedPath = Resolve-WeChatOutputPath -Path $OutPath

Save-WeChatWindowCapture -Window $window -Path $resolvedPath
Add-WeChatCaptureRecord -Path $resolvedPath

Write-Output $resolvedPath
