param(
    [string]$InputDir,
    [string[]]$Images,
    [string]$OutFile,
    [string]$LanguageTag,
    [double]$CropLeftRatio,
    [double]$CropTopRatio,
    [double]$CropRightRatio,
    [double]$CropBottomRatio
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($InputDir) -and (-not $Images -or $Images.Count -eq 0)) {
    throw 'Provide -InputDir or -Images.'
}

$fileList = @()
if (-not [string]::IsNullOrWhiteSpace($InputDir)) {
    if (-not (Test-Path -LiteralPath $InputDir)) {
        throw "Input directory not found: $InputDir"
    }

    $fileList += Get-ChildItem -LiteralPath $InputDir -Filter '*.png' |
        Sort-Object -Property Name |
        Select-Object -ExpandProperty FullName
}

if ($Images) {
    $fileList += $Images
}

$seen = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
$ordered = New-Object System.Collections.Generic.List[string]
foreach ($path in $fileList) {
    if ([string]::IsNullOrWhiteSpace($path)) {
        continue
    }
    if (-not (Test-Path -LiteralPath $path)) {
        continue
    }

    $fullPath = [System.IO.Path]::GetFullPath($path)
    if ($seen.Add($fullPath)) {
        $ordered.Add($fullPath)
    }
}

$fileList = $ordered

if (-not $fileList -or $fileList.Count -eq 0) {
    throw 'No input images found for OCR.'
}

if ([string]::IsNullOrWhiteSpace($OutFile)) {
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $OutFile = Join-Path ([System.IO.Path]::GetTempPath()) "ocr-summary-$stamp.txt"
}

$fullPath = [System.IO.Path]::GetFullPath($OutFile)
$directory = Split-Path -Parent $fullPath
if ($directory -and -not (Test-Path -LiteralPath $directory)) {
    New-Item -ItemType Directory -Path $directory | Out-Null
}

Add-Type -AssemblyName System.Runtime.WindowsRuntime
Add-Type -AssemblyName System.Drawing
[Windows.Storage.StorageFile, Windows.Storage, ContentType = WindowsRuntime] | Out-Null
[Windows.Graphics.Imaging.BitmapDecoder, Windows.Graphics.Imaging, ContentType = WindowsRuntime] | Out-Null
[Windows.Media.Ocr.OcrEngine, Windows.Media.Ocr, ContentType = WindowsRuntime] | Out-Null
[Windows.Globalization.Language, Windows.Globalization, ContentType = WindowsRuntime] | Out-Null

$engine = if (-not [string]::IsNullOrWhiteSpace($LanguageTag)) {
    $language = New-Object Windows.Globalization.Language $LanguageTag
    [Windows.Media.Ocr.OcrEngine]::TryCreateFromLanguage($language)
}
else {
    [Windows.Media.Ocr.OcrEngine]::TryCreateFromUserProfileLanguages()
}

if (-not $engine) {
    throw 'Windows OCR engine is not available on this machine.'
}

function Invoke-WinRtTask {
    param(
        [Parameter(Mandatory)]$AsyncOperation,
        [Type]$ResultType
    )

    if ($ResultType) {
        $asyncInterface = [Windows.Foundation.IAsyncOperation`1].MakeGenericType($ResultType)
        $typedOperation = $AsyncOperation -as $asyncInterface
        if (-not $typedOperation) {
            $typedOperation = $AsyncOperation
        }

        $method = [System.WindowsRuntimeSystemExtensions].GetMethods() |
            Where-Object { $_.Name -eq 'AsTask' -and $_.IsGenericMethodDefinition -and $_.GetGenericArguments().Count -eq 1 -and $_.GetParameters().Count -eq 1 } |
            Select-Object -First 1

        $task = $method.MakeGenericMethod($ResultType).Invoke($null, @($typedOperation))
        return $task.GetAwaiter().GetResult()
    }

    $actionMethod = [System.WindowsRuntimeSystemExtensions].GetMethod('AsTask', [Type[]]@([Windows.Foundation.IAsyncAction]))
    $actionTask = $actionMethod.Invoke($null, @($AsyncOperation))
    $actionTask.GetAwaiter().GetResult()
}

function Get-OcrTextFromFile {
    param([Parameter(Mandatory)][string]$Path)

    $inputPath = $Path
    $tempPath = $null

    if ($CropLeftRatio -gt 0 -and $CropTopRatio -gt 0 -and $CropRightRatio -gt 0 -and $CropBottomRatio -gt 0) {
        $bitmap = [System.Drawing.Bitmap]::FromFile($Path)
        try {
            $left = [Math]::Max(0, [Math]::Min($bitmap.Width - 1, [int][Math]::Round($bitmap.Width * $CropLeftRatio)))
            $top = [Math]::Max(0, [Math]::Min($bitmap.Height - 1, [int][Math]::Round($bitmap.Height * $CropTopRatio)))
            $right = [Math]::Max($left + 1, [Math]::Min($bitmap.Width, [int][Math]::Round($bitmap.Width * $CropRightRatio)))
            $bottom = [Math]::Max($top + 1, [Math]::Min($bitmap.Height, [int][Math]::Round($bitmap.Height * $CropBottomRatio)))
            $width = $right - $left
            $height = $bottom - $top

            $rect = New-Object System.Drawing.Rectangle($left, $top, $width, $height)
            $cropped = $bitmap.Clone($rect, $bitmap.PixelFormat)
            try {
                $tempPath = Join-Path ([System.IO.Path]::GetTempPath()) ("ocr-crop-{0}.png" -f ([Guid]::NewGuid().ToString('N')))
                $cropped.Save($tempPath, [System.Drawing.Imaging.ImageFormat]::Png)
                $inputPath = $tempPath
            }
            finally {
                $cropped.Dispose()
            }
        }
        finally {
            $bitmap.Dispose()
        }
    }

    $file = Invoke-WinRtTask -AsyncOperation ([Windows.Storage.StorageFile]::GetFileFromPathAsync($inputPath)) -ResultType ([Windows.Storage.StorageFile])
    $stream = Invoke-WinRtTask -AsyncOperation ($file.OpenAsync([Windows.Storage.FileAccessMode]::Read)) -ResultType ([Windows.Storage.Streams.IRandomAccessStream])

    try {
        $decoder = Invoke-WinRtTask -AsyncOperation ([Windows.Graphics.Imaging.BitmapDecoder]::CreateAsync($stream)) -ResultType ([Windows.Graphics.Imaging.BitmapDecoder])
        $bitmap = Invoke-WinRtTask -AsyncOperation ($decoder.GetSoftwareBitmapAsync()) -ResultType ([Windows.Graphics.Imaging.SoftwareBitmap])
        $result = Invoke-WinRtTask -AsyncOperation ($engine.RecognizeAsync($bitmap)) -ResultType ([Windows.Media.Ocr.OcrResult])
        $result.Text
    }
    finally {
        if ($stream) {
            $stream.Dispose()
        }
        if ($tempPath -and (Test-Path -LiteralPath $tempPath)) {
            Remove-Item -LiteralPath $tempPath -Force
        }
    }
}

$outputLines = @(
    "OcrExport: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')",
    "ImageCount: $($fileList.Count)",
    ''
)

foreach ($file in $fileList) {
    $outputLines += "## $(Split-Path -Leaf $file)"
    try {
        $text = Get-OcrTextFromFile -Path $file
        if ([string]::IsNullOrWhiteSpace($text)) {
            $outputLines += '[no text detected]'
        }
        else {
            $outputLines += $text.Trim()
        }
    }
    catch {
        $outputLines += "[ocr failed] $($_.Exception.Message)"
    }
    $outputLines += ''
}

Set-Content -Path $fullPath -Value ($outputLines -join [Environment]::NewLine) -Encoding UTF8
Write-Output $fullPath
