param(
    [Parameter(Mandatory = $true)]
    [string]$GodotPath,
    [int]$TimeoutSeconds = 180
)

$ErrorActionPreference = "Stop"
$ProjectPath = Split-Path -Parent $PSScriptRoot
$Log = Join-Path $ProjectPath ".godot\rendered_performance_profile.log"
$Arguments = @(
    "--path", $ProjectPath,
    "--script", "res://Tools/rendered_performance_profile.gd",
    "--log-file", $Log
)
$Process = Start-Process -FilePath $GodotPath -ArgumentList $Arguments `
    -PassThru -WindowStyle Normal
if (-not $Process.WaitForExit($TimeoutSeconds * 1000)) {
    Stop-Process -Id $Process.Id -Force
    throw "Rendered performance profile timed out after $TimeoutSeconds seconds."
}
$Process.WaitForExit()
$Process.Refresh()
if ($Process.ExitCode -ne 0) {
    throw "Rendered performance profile failed. Log: $Log"
}
Write-Host "Rendered performance profile passed. Log: $Log"
