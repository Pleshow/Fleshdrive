param(
    [Parameter(Mandatory = $true)]
    [string]$GodotPath,
    [int]$TimeoutSeconds = 180
)

$ErrorActionPreference = "Stop"
$ProjectPath = Split-Path -Parent $PSScriptRoot
$Log = Join-Path $ProjectPath ".godot\balance_benchmark.log"
$Arguments = @(
    "--headless", "--path", $ProjectPath,
    "--script", "res://Tests/production_hardening_test.gd",
    "--log-file", $Log
)
$Process = Start-Process -FilePath $GodotPath -ArgumentList $Arguments `
    -PassThru -NoNewWindow
if (-not $Process.WaitForExit($TimeoutSeconds * 1000)) {
    Stop-Process -Id $Process.Id -Force
    throw "Balance benchmark timed out after $TimeoutSeconds seconds."
}
$Process.WaitForExit()
$Process.Refresh()
if ($Process.ExitCode -ne 0) {
    throw "Balance benchmark failed. Log: $Log"
}
$Text = Get-Content -LiteralPath $Log -Raw
if ($Text -match "SCRIPT ERROR:" -or $Text -match "ERROR: FAIL:") {
    throw "Balance benchmark logged a script error or failed assertion. Log: $Log"
}
Write-Host "Balance benchmark passed. Report: Reports\production_hardening_soak.json"
