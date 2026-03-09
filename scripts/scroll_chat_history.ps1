param(
    [int]$Steps = 8,
    [int]$WheelDelta = 120,
    [int]$FocusX,
    [int]$FocusY
)

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $scriptRoot 'wechat_common.ps1')

if ($Steps -lt 0) {
    throw 'Steps must be a non-negative integer.'
}

if ($WheelDelta -eq 0) {
    throw 'WheelDelta must be non-zero.'
}

$process = Get-OrStartWeChatProcess
$window = Get-WeChatWindowInfo -Process $process

if ($PSBoundParameters.ContainsKey('FocusX') -and $PSBoundParameters.ContainsKey('FocusY')) {
    Invoke-WeChatClick -X $FocusX -Y $FocusY
    $point = [pscustomobject]@{ X = $FocusX; Y = $FocusY }
}
else {
    $point = Focus-WeChatHistory -Window $window
}

if ($env:SCROLL_CHAT_HISTORY_DRY_RUN -eq '1') {
    Write-Output "Dry run: steps=$Steps wheelDelta=$WheelDelta focus=($($point.X),$($point.Y))"
    return
}

for ($index = 0; $index -lt $Steps; $index++) {
    Invoke-WeChatWheel -Delta $WheelDelta
}

Write-Output "Scrolled chat history: steps=$Steps wheelDelta=$WheelDelta focus=($($point.X),$($point.Y))"
