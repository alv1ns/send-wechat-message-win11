param(
    [string]$Talker,
    [string]$SessionKeyword,
    [int]$Limit = 200,
    [string]$Start,
    [string]$End,
    [string]$Keyword,
    [string]$OutFile
)

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $scriptRoot 'weflow_common.ps1')

if ([string]::IsNullOrWhiteSpace($Talker)) {
    if ([string]::IsNullOrWhiteSpace($SessionKeyword)) {
        throw 'Provide either -Talker or -SessionKeyword.'
    }

    $session = Resolve-WeFlowSession -Keyword $SessionKeyword
    $Talker = $session.username
}
else {
    $session = $null
}

$response = Get-WeFlowMessages -Talker $Talker -Limit $Limit -Start $Start -End $End -Keyword $Keyword -ChatLab
$messages = if ($response.messages) { $response.messages } else { @() }
$summaryLines = ConvertTo-WeFlowSummaryText -Messages $messages -MaxItems $Limit

$header = @(
    "Session: $($response.meta.name)",
    "Talker: $Talker",
    "Platform: $($response.meta.platform)",
    "Type: $($response.meta.type)",
    "ExportedAt: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')",
    ''
)

$content = @($header + $summaryLines) -join [Environment]::NewLine

if ([string]::IsNullOrWhiteSpace($OutFile)) {
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $safeName = if ($response.meta.name) { ($response.meta.name -replace '[\\/:*?"<>|]', '_') } else { $Talker }
    $OutFile = Join-Path ([System.IO.Path]::GetTempPath()) "weflow-summary-$safeName-$stamp.txt"
}

$fullPath = [System.IO.Path]::GetFullPath($OutFile)
$directory = Split-Path -Parent $fullPath
if ($directory -and -not (Test-Path -LiteralPath $directory)) {
    New-Item -ItemType Directory -Path $directory | Out-Null
}

Set-Content -Path $fullPath -Value $content -Encoding UTF8
Write-Output $fullPath
