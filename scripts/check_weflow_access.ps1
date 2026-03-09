$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $scriptRoot 'weflow_common.ps1')

$health = Test-WeFlowHealth
[pscustomobject]@{
    BaseUrl = Get-WeFlowBaseUrl
    Status  = $health.status
} | Format-List
