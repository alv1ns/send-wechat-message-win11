param(
    [int]$MaxPages = 20,
    [string]$OutDir,
    [int]$StepsPerPage,
    [int]$WheelDelta = 120,
    [int]$PauseMs = 500,
    [ValidateSet('wheel', 'scrollbar')]
    [string]$ScrollMode = 'wheel',
    [double]$ScrollbarXRatio = 0.965,
    [double]$ScrollbarStartYRatio = 0.30,
    [double]$ScrollbarEndYRatio = 0.60
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
$stepsPerPage = if ($StepsPerPage -gt 0) {
    $StepsPerPage
}
else {
    [Math]::Max(4, [Math]::Min(10, [int][Math]::Round($window.Height / 220)))
}
$scrollModeValue = $ScrollMode.ToLowerInvariant()
if ($scrollModeValue -eq 'scrollbar' -and $StepsPerPage -le 0) {
    $stepsPerPage = 1
}
$metadataPath = Join-Path $OutDir 'metadata.txt'
$scrollbarStart = $null
$scrollbarEnd = $null

if ($scrollModeValue -eq 'scrollbar') {
    $scrollbarStart = Get-WeChatRelativePoint -Window $window -XRatio $ScrollbarXRatio -YRatio $ScrollbarStartYRatio
    $scrollbarEnd = Get-WeChatRelativePoint -Window $window -XRatio $ScrollbarXRatio -YRatio $ScrollbarEndYRatio
}

@(
    "window=$($window.Left),$($window.Top),$($window.Width),$($window.Height)",
    "focus=($($focus.X),$($focus.Y))",
    "steps_per_page=$stepsPerPage",
    "wheel_delta=$WheelDelta",
    "pause_ms=$PauseMs",
    "scroll_mode=$scrollModeValue",
    "scrollbar_start=$($scrollbarStart.X),$($scrollbarStart.Y)",
    "scrollbar_end=$($scrollbarEnd.X),$($scrollbarEnd.Y)",
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
        if ($scrollModeValue -eq 'scrollbar') {
            for ($step = 0; $step -lt $stepsPerPage; $step++) {
                Invoke-WeChatDrag -StartX $scrollbarStart.X -StartY $scrollbarStart.Y -EndX $scrollbarEnd.X -EndY $scrollbarEnd.Y
                Start-Sleep -Milliseconds $PauseMs
            }
        }
        else {
            Invoke-WeChatClick -X $focus.X -Y $focus.Y
            for ($step = 0; $step -lt $stepsPerPage; $step++) {
                Invoke-WeChatWheel -Delta $WheelDelta
            }
            Start-Sleep -Milliseconds $PauseMs
        }
    }
}

Write-Output ([System.IO.Path]::GetFullPath($OutDir))
