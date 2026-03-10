param(
    [string]$Expected,
    [switch]$Exact
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Normalize-WeChatChatTitle {
    param([Parameter(Mandatory)][string]$Title)

    $normalized = $Title.Trim()
    $normalized = [regex]::Replace($normalized, '\s+', ' ')
    $normalized = [regex]::Replace($normalized, '\(\d+\)$', '')
    return $normalized.Trim()
}

function Get-WeChatTitleCandidates {
    param(
        [Parameter(Mandatory)]$Root,
        [Parameter(Mandatory)]$Window
    )

    $headerTop = $Window.Top
    $headerBottom = $Window.Top + [Math]::Round($Window.Height * 0.24)
    $headerLeft = $Window.Left + [Math]::Round($Window.Width * 0.34)
    $headerRight = $Window.Left + [Math]::Round($Window.Width * 0.78)

    $controlTypes = @(
        [System.Windows.Automation.ControlType]::Text,
        [System.Windows.Automation.ControlType]::Edit,
        [System.Windows.Automation.ControlType]::Custom
    )

    foreach ($controlType in $controlTypes) {
        $condition = New-Object System.Windows.Automation.PropertyCondition(
            [System.Windows.Automation.AutomationElement]::ControlTypeProperty,
            $controlType
        )

        $elements = $Root.FindAll([System.Windows.Automation.TreeScope]::Descendants, $condition)
        foreach ($element in $elements) {
            $name = $element.Current.Name
            if ([string]::IsNullOrWhiteSpace($name)) {
                continue
            }

            $rect = $element.Current.BoundingRectangle
            if ($rect.Width -lt 30 -or $rect.Height -lt 10) {
                continue
            }

            if ($rect.Top -lt $headerTop -or $rect.Top -gt $headerBottom) {
                continue
            }

            if ($rect.Left -lt $headerLeft -or $rect.Right -gt $headerRight) {
                continue
            }

            $trimmedName = $name.Trim()
            if ($trimmedName -match '^\(\d+\)$') {
                continue
            }

            $normalizedName = Normalize-WeChatChatTitle -Title $trimmedName
            if ([string]::IsNullOrWhiteSpace($normalizedName)) {
                continue
            }

            [pscustomobject]@{
                Name = $trimmedName
                NormalizedName = $normalizedName
                Left = [int]$rect.Left
                Top = [int]$rect.Top
                Width = [int]$rect.Width
                Height = [int]$rect.Height
            }
        }
    }
}

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $scriptRoot 'wechat_common.ps1')

$process = Get-OrStartWeChatProcess
$window = Get-WeChatWindowInfo -Process $process
$root = Get-WeChatAutomationRoot -Window $window
if (-not $root) {
    throw 'Windows UI Automation could not inspect the active WeChat window.'
}

$candidates = @()
for ($attempt = 1; $attempt -le 5; $attempt++) {
    $candidates = @(Get-WeChatTitleCandidates -Root $root -Window $window)
    if ($candidates.Count -gt 0) {
        break
    }

    Start-Sleep -Milliseconds 250
    $window = Get-WeChatWindowInfo -Process $process
    $root = Get-WeChatAutomationRoot -Window $window
}

if (-not $candidates -or $candidates.Count -eq 0) {
    throw 'Could not determine the active chat title from the WeChat window.'
}

$windowCenter = $window.Left + ($window.Width / 2)
$title = $candidates |
    Group-Object -Property NormalizedName |
    ForEach-Object {
        $_.Group |
            Sort-Object @{ Expression = { $_.Width }; Descending = $true }, @{ Expression = { [Math]::Abs(($_.Left + ($_.Width / 2)) - $windowCenter) }; Ascending = $true }, @{ Expression = { $_.Top }; Ascending = $true } |
            Select-Object -First 1
    } |
    Sort-Object @{ Expression = { $_.Width }; Descending = $true }, @{ Expression = { [Math]::Abs(($_.Left + ($_.Width / 2)) - $windowCenter) }; Ascending = $true }, @{ Expression = { $_.Top }; Ascending = $true } |
    Select-Object -First 1

if ($Expected) {
    $expectedNormalized = Normalize-WeChatChatTitle -Title $Expected
    $matches = if ($Exact) {
        $title.NormalizedName -eq $expectedNormalized
    }
    else {
        $escapedExpected = [System.Management.Automation.WildcardPattern]::Escape($expectedNormalized)
        $title.NormalizedName -like "*$escapedExpected*"
    }

    if (-not $matches) {
        throw "Active chat title mismatch. Expected '$expectedNormalized', actual '$($title.NormalizedName)'."
    }
}

$title.NormalizedName
