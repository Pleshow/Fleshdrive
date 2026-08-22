param(
    [string]$GodotPath = "",
    [int]$SuiteTimeoutSeconds = 180
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($GodotPath)) {
    $EnvironmentGodot = [Environment]::GetEnvironmentVariable(
        "GODOT_CONSOLE_PATH"
    )
    if (-not [string]::IsNullOrWhiteSpace($EnvironmentGodot)) {
        $GodotPath = $EnvironmentGodot
    }
    else {
        foreach ($CommandName in @("godot4", "godot")) {
            $GodotCommand = Get-Command $CommandName -ErrorAction SilentlyContinue
            if ($null -ne $GodotCommand) {
                $GodotPath = $GodotCommand.Source
                break
            }
        }
    }
}

if ([string]::IsNullOrWhiteSpace($GodotPath)) {
    throw "Godot was not found. Pass -GodotPath or set GODOT_CONSOLE_PATH to the Godot 4.7 console executable."
}

if (-not (Test-Path -LiteralPath $GodotPath)) {
    $GodotCommand = Get-Command $GodotPath -ErrorAction SilentlyContinue
    if ($null -eq $GodotCommand) {
        throw "Godot executable not found: $GodotPath"
    }
    $GodotPath = $GodotCommand.Source
}

$ProjectPath = Split-Path -Parent $PSScriptRoot
$LogDirectory = Join-Path $ProjectPath ".godot\release_gate"
New-Item -ItemType Directory -Force -Path $LogDirectory | Out-Null

$Tests = @(
    Get-ChildItem -LiteralPath (Join-Path $ProjectPath "Tests") `
        -Filter "*_test.gd" -File |
        Sort-Object Name |
        Select-Object -ExpandProperty Name
)

if ($Tests.Count -eq 0) {
    throw "Release gate found no active test suites."
}

$Failures = 0
foreach ($Test in $Tests) {
    $Name = [IO.Path]::GetFileNameWithoutExtension($Test)
    $Log = Join-Path $LogDirectory ($Name + ".log")
    if (Test-Path -LiteralPath $Log) {
        Remove-Item -LiteralPath $Log -Force
    }
    $Arguments = @(
        "--headless",
        "--path", $ProjectPath,
        "--script", ("res://Tests/" + $Test),
        "--log-file", $Log
    )
    $Process = Start-Process -FilePath $GodotPath -ArgumentList $Arguments -NoNewWindow -PassThru
    if (-not $Process.WaitForExit($SuiteTimeoutSeconds * 1000)) {
        Stop-Process -Id $Process.Id -Force
        Write-Warning "Release suite timed out after $SuiteTimeoutSeconds seconds: $Test"
        $Failures++
        continue
    }
    # PowerShell can expose the default non-zero ExitCode value until the
    # asynchronous stream handlers are drained and the process object refreshes.
    $Process.WaitForExit()
    $Process.Refresh()
    if ($null -ne $Process.ExitCode -and $Process.ExitCode -ne 0) {
        Write-Warning "Release suite returned exit code $($Process.ExitCode): $Test"
        $Failures++
        continue
    }
    $LogText = Get-Content -LiteralPath $Log -Raw -ErrorAction SilentlyContinue
    if ($LogText -match "(?m)^SCRIPT ERROR:" -or $LogText -match "(?m)^ERROR: FAIL:") {
        Write-Warning "Release suite logged a script error or failed assertion: $Test"
        $Failures++
    }
    elseif ($LogText -notmatch "(?m)^.*TEST PASSED\r?$") {
        Write-Warning "Release suite did not report its completion marker: $Test"
        $Failures++
    }
}

if ($Failures -gt 0) {
    throw "Release gate failed: $Failures test suite(s) failed. Logs: $LogDirectory"
}

Write-Host "Release gate passed: $($Tests.Count) suite(s). Logs: $LogDirectory"
