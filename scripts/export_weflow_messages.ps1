param(
    [string]$Talker,
    [string]$SessionKeyword,
    [int]$Limit = 200,
    [int]$Offset = 0,
    [string]$Start,
    [string]$End,
    [string]$Keyword,
    [switch]$ChatLab,
    [switch]$Media,
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

$response = Get-WeFlowMessages -Talker $Talker -Limit $Limit -Offset $Offset -Start $Start -End $End -Keyword $Keyword -ChatLab:$ChatLab -Media:$Media
$json = $response | ConvertTo-Json -Depth 8

if (-not [string]::IsNullOrWhiteSpace($OutFile)) {
    $fullPath = [System.IO.Path]::GetFullPath($OutFile)
    $directory = Split-Path -Parent $fullPath
    if ($directory -and -not (Test-Path -LiteralPath $directory)) {
        New-Item -ItemType Directory -Path $directory | Out-Null
    }
    Set-Content -Path $fullPath -Value $json -Encoding UTF8
    Write-Output $fullPath
    return
}

$json
