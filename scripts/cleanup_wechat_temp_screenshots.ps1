$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $scriptRoot 'wechat_common.ps1')

$stateFile = Get-WeChatCaptureStateFile
$deleted = 0

function Remove-TrackedCapture {
    param([string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return
    }

    if (Test-Path -LiteralPath $Path) {
        Remove-Item -LiteralPath $Path -Force
        $script:deleted++
    }
}

if (Test-Path -LiteralPath $stateFile) {
    Get-Content -Path $stateFile | ForEach-Object { Remove-TrackedCapture -Path $_ }
    Remove-Item -LiteralPath $stateFile -Force
}

Get-ChildItem -Path ([System.IO.Path]::GetTempPath()) -Filter 'wechat-window-*.png' -ErrorAction SilentlyContinue |
    ForEach-Object { Remove-TrackedCapture -Path $_.FullName }

Write-Output "Deleted $deleted temporary screenshot file(s)."
