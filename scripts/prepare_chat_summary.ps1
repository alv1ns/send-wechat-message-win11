param(
    [string]$Talker,
    [string]$SessionKeyword,
    [int]$Limit = 200,
    [int]$MaxPages = 20,
    [int]$StepsPerPage,
    [int]$WheelDelta,
    [int]$PauseMs,
    [ValidateSet('wheel', 'scrollbar')]
    [string]$ScrollMode = 'wheel',
    [double]$ScrollbarXRatio,
    [double]$ScrollbarStartYRatio,
    [double]$ScrollbarEndYRatio,
    [double]$CropLeftRatio = 0.30,
    [double]$CropTopRatio = 0.22,
    [double]$CropRightRatio = 0.98,
    [double]$CropBottomRatio = 0.82,
    [switch]$NoCrop,
    [string]$Start,
    [string]$End,
    [string]$Keyword,
    [string]$WeFlowOutFile,
    [string]$OcrOutFile,
    [string]$LanguageTag,
    [switch]$AllowFallback,
    [switch]$ForceOcr
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $scriptRoot 'weflow_common.ps1')

$weflowReady = $false
$weflowError = $null
$weflowAttempted = $false

if (-not $ForceOcr) {
    try {
        Test-WeFlowHealth | Out-Null
        $weflowReady = $true
    }
    catch {
        $weflowError = $_.Exception.Message
    }
}

if ($weflowReady) {
    if ([string]::IsNullOrWhiteSpace($Talker) -and [string]::IsNullOrWhiteSpace($SessionKeyword)) {
        if ($AllowFallback) {
            $weflowError = 'WeFlow is available, but -Talker or -SessionKeyword was not provided.'
        }
        else {
            throw 'WeFlow is available. Provide -Talker or -SessionKeyword, or pass -AllowFallback/-ForceOcr.'
        }
    }

    try {
        $weflowAttempted = $true
        $weflowArgs = @{}
        if (-not [string]::IsNullOrWhiteSpace($Talker)) {
            $weflowArgs.Talker = $Talker
        }
        if (-not [string]::IsNullOrWhiteSpace($SessionKeyword)) {
            $weflowArgs.SessionKeyword = $SessionKeyword
        }
        if ($Limit -gt 0) {
            $weflowArgs.Limit = $Limit
        }
        if (-not [string]::IsNullOrWhiteSpace($Start)) {
            $weflowArgs.Start = $Start
        }
        if (-not [string]::IsNullOrWhiteSpace($End)) {
            $weflowArgs.End = $End
        }
        if (-not [string]::IsNullOrWhiteSpace($Keyword)) {
            $weflowArgs.Keyword = $Keyword
        }
        if (-not [string]::IsNullOrWhiteSpace($WeFlowOutFile)) {
            $weflowArgs.OutFile = $WeFlowOutFile
        }

        if ($weflowArgs.Count -gt 0) {
            $path = & (Join-Path $scriptRoot 'prepare_weflow_summary.ps1') @weflowArgs
        }
        else {
            throw 'WeFlow parameters were not provided.'
        }
        Write-Output 'Mode: WeFlow'
        Write-Output $path
        return
    }
    catch {
        $weflowError = $_.Exception.Message
        if (-not $AllowFallback) {
            throw
        }
    }
}

$captureArgs = @{
    MaxPages = $MaxPages
}
if ($StepsPerPage -gt 0) {
    $captureArgs.StepsPerPage = $StepsPerPage
}
if ($WheelDelta -gt 0) {
    $captureArgs.WheelDelta = $WheelDelta
}
if ($PauseMs -gt 0) {
    $captureArgs.PauseMs = $PauseMs
}
if (-not [string]::IsNullOrWhiteSpace($ScrollMode)) {
    $captureArgs.ScrollMode = $ScrollMode
}
if ($ScrollbarXRatio -gt 0) {
    $captureArgs.ScrollbarXRatio = $ScrollbarXRatio
}
if ($ScrollbarStartYRatio -gt 0) {
    $captureArgs.ScrollbarStartYRatio = $ScrollbarStartYRatio
}
if ($ScrollbarEndYRatio -gt 0) {
    $captureArgs.ScrollbarEndYRatio = $ScrollbarEndYRatio
}

$historyDir = & (Join-Path $scriptRoot 'capture_chat_history_sequence.ps1') @captureArgs
$ocrArgs = @{
    InputDir = $historyDir
}

if (-not [string]::IsNullOrWhiteSpace($OcrOutFile)) {
    $ocrArgs.OutFile = $OcrOutFile
}
if (-not [string]::IsNullOrWhiteSpace($LanguageTag)) {
    $ocrArgs.LanguageTag = $LanguageTag
}
if (-not $NoCrop) {
    $ocrArgs.CropLeftRatio = $CropLeftRatio
    $ocrArgs.CropTopRatio = $CropTopRatio
    $ocrArgs.CropRightRatio = $CropRightRatio
    $ocrArgs.CropBottomRatio = $CropBottomRatio
}

$ocrPath = & (Join-Path $scriptRoot 'ocr_chat_history.ps1') @ocrArgs
Write-Output 'Mode: OCR'
Write-Output $ocrPath

if ($weflowError) {
    Write-Output "WeFlowError: $weflowError"
}
