param(
    [Parameter(Mandatory)]
    [string]$Keyword,
    [int]$Limit = 20
)

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $scriptRoot 'weflow_common.ps1')

$response = Get-WeFlowSessions -Keyword $Keyword -Limit $Limit
if (-not $response.success) {
    throw 'WeFlow session query failed.'
}

$response.sessions |
    Select-Object username, displayName, lastMessage, lastTime, unreadCount |
    ConvertTo-Json -Depth 4
