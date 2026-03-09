param(
    [int]$MaxPages = 20,
    [string]$OutDir
)

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $scriptRoot 'wechat_common.ps1')

if ($MaxPages -le 0) {
    throw 'MaxPages must be greater than 0.'
}

if ([string]::IsNullOrWhiteSpace($OutDir)) {
    $OutDir = Join-Path ([System.IO.Path]::GetTempPath()) ("wechat-history-$(Get-Date -Format 'yyyyMMdd-HHmmss')")
}

if (-not (Test-Path -LiteralPath $OutDir)) {
    New-Item -ItemType Directory -Path $OutDir | Out-Null
}

$process = Get-OrStartWeChatProcess
$window = Get-WeChatWindowInfo -Process $process
$focus = Focus-WeChatHistory -Window $window
$stepsPerPage = [Math]::Max(4, [Math]::Min(10, [int][Math]::Round($window.Height / 220)))
$metadataPath = Join-Path $OutDir 'metadata.txt'

@(
    "window=$($window.Left),$($window.Top),$($window.Width),$($window.Height)",
    "focus=($($focus.X),$($focus.Y))",
    "steps_per_page=$stepsPerPage",
    "max_pages=$MaxPages"
) | Set-Content -Path $metadataPath

$previousHash = $null

for ($page = 1; $page -le $MaxPages; $page++) {
    $outFile = Join-Path $OutDir ('page-{0:D3}.png' -f $page)
    $window = Get-WeChatWindowInfo -Process $process
    Save-WeChatWindowCapture -Window $window -Path $outFile
    Add-WeChatCaptureRecord -Path $outFile

    $currentHash = (Get-FileHash -Path $outFile -Algorithm SHA256).Hash
    Add-Content -Path $metadataPath -Value "$(Split-Path -Leaf $outFile) $currentHash"

    if ($previousHash -and $previousHash -eq $currentHash) {
        Remove-Item -LiteralPath $outFile -Force
        Add-Content -Path $metadataPath -Value "Reached a stable viewport at page $($page - 1)."
        break
    }

    $previousHash = $currentHash

    if ($page -lt $MaxPages) {
        Invoke-WeChatClick -X $focus.X -Y $focus.Y
        for ($step = 0; $step -lt $stepsPerPage; $step++) {
            Invoke-WeChatWheel -Delta 120
        }
        Start-Sleep -Milliseconds 500
    }
}

Write-Output ([System.IO.Path]::GetFullPath($OutDir))
