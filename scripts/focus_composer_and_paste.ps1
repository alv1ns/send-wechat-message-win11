param([Parameter(Mandatory)][string]$Message)

$script = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) 'focus_composer_and_set_value.ps1'
& $script -Message $Message
