Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-WeFlowBaseUrl {
    if (-not [string]::IsNullOrWhiteSpace($env:WEFLOW_BASE_URL)) {
        return $env:WEFLOW_BASE_URL.TrimEnd('/')
    }

    'http://127.0.0.1:5031'
}

function Invoke-WeFlowApi {
    param(
        [Parameter(Mandatory)]
        [string]$Path,
        [hashtable]$Query
    )

    $baseUrl = Get-WeFlowBaseUrl
    $builder = [System.UriBuilder]::new("$baseUrl$Path")

    if ($Query) {
        $pairs = foreach ($key in $Query.Keys) {
            $value = $Query[$key]
            if ($null -eq $value -or [string]::IsNullOrWhiteSpace([string]$value)) {
                continue
            }

            '{0}={1}' -f [System.Uri]::EscapeDataString([string]$key), [System.Uri]::EscapeDataString([string]$value)
        }

        $builder.Query = ($pairs -join '&')
    }

    Invoke-RestMethod -Method Get -Uri $builder.Uri.AbsoluteUri
}

function Test-WeFlowHealth {
    $response = Invoke-WeFlowApi -Path '/health'
    if ($response.status -ne 'ok') {
        throw 'WeFlow API responded, but the health payload was unexpected.'
    }

    $response
}

function Get-WeFlowSessions {
    param(
        [string]$Keyword,
        [int]$Limit = 100
    )

    Invoke-WeFlowApi -Path '/api/v1/sessions' -Query @{
        keyword = $Keyword
        limit   = $Limit
    }
}

function Resolve-WeFlowSession {
    param(
        [Parameter(Mandatory)]
        [string]$Keyword,
        [int]$Limit = 20
    )

    $response = Get-WeFlowSessions -Keyword $Keyword -Limit $Limit
    if (-not $response.success) {
        throw 'WeFlow returned an unsuccessful session query response.'
    }

    if (-not $response.sessions -or $response.sessions.Count -eq 0) {
        throw "No WeFlow sessions matched '$Keyword'."
    }

    $exact = $response.sessions | Where-Object { $_.displayName -eq $Keyword }
    if ($exact.Count -eq 1) {
        return $exact[0]
    }

    $prefix = $response.sessions | Where-Object { $_.displayName -like "$Keyword*" }
    if ($prefix.Count -eq 1) {
        return $prefix[0]
    }

    if ($response.sessions.Count -eq 1) {
        return $response.sessions[0]
    }

    $choices = $response.sessions |
        Select-Object -First 5 |
        ForEach-Object { "{0} ({1})" -f $_.displayName, $_.username }

    throw "Multiple WeFlow sessions matched '$Keyword': $($choices -join '; ')"
}

function Get-WeFlowMessages {
    param(
        [Parameter(Mandatory)]
        [string]$Talker,
        [int]$Limit = 200,
        [int]$Offset = 0,
        [string]$Start,
        [string]$End,
        [string]$Keyword,
        [switch]$ChatLab,
        [switch]$Media
    )

    $query = @{
        talker = $Talker
        limit  = $Limit
        offset = $Offset
        start  = $Start
        end    = $End
        keyword = $Keyword
    }

    if ($ChatLab) {
        $query.format = 'chatlab'
    }

    if ($Media) {
        $query.media = '1'
    }

    Invoke-WeFlowApi -Path '/api/v1/messages' -Query $query
}

function ConvertFrom-WeFlowTimestamp {
    param([Parameter(Mandatory)]$Timestamp)

    $value = [int64]$Timestamp
    if ($value -lt 100000000000) {
        return [DateTimeOffset]::FromUnixTimeSeconds($value).ToLocalTime().DateTime
    }

    [DateTimeOffset]::FromUnixTimeMilliseconds($value).ToLocalTime().DateTime
}

function ConvertTo-WeFlowSummaryText {
    param(
        [Parameter(Mandatory)]$Messages,
        [int]$MaxItems = 200
    )

    $selected = @($Messages | Select-Object -First $MaxItems)
    foreach ($message in $selected) {
        $sender = if ($message.accountName) { $message.accountName } elseif ($message.senderUsername) { $message.senderUsername } elseif ($message.sender) { $message.sender } else { 'unknown' }
        $timestamp = if ($message.timestamp) { ConvertFrom-WeFlowTimestamp -Timestamp $message.timestamp } elseif ($message.createTime) { ConvertFrom-WeFlowTimestamp -Timestamp $message.createTime } else { $null }
        $timeText = if ($timestamp) { $timestamp.ToString('yyyy-MM-dd HH:mm:ss') } else { 'unknown-time' }
        $content = if ([string]::IsNullOrWhiteSpace($message.content)) { '[non-text message]' } else { ($message.content -replace '\r?\n', ' ') }
        '[{0}] {1}: {2}' -f $timeText, $sender, $content
    }
}
