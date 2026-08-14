param(
    [string]$GodotPath = ""
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
    "publication_readiness_test.gd",
    "release_hardening_test.gd",
    "production_hardening_test.gd",
    "vertical_slice_lockdown_test.gd",
    "playtest_feedback_regression_test.gd",
    "isometric_arena_test.gd",
    "dusk_garden_arena_test.gd",
    "primary_build_infrastructure_test.gd",
    "run_integrity_regression_test.gd",
    "ink_crimson_visual_system_test.gd"
)

$Failures = 0
foreach ($Test in $Tests) {
    $Name = [IO.Path]::GetFileNameWithoutExtension($Test)
    $Log = Join-Path $LogDirectory ($Name + ".log")
    & $GodotPath --headless --path $ProjectPath --script ("res://Tests/" + $Test) --log-file $Log
    if ($LASTEXITCODE -ne 0) {
        $Failures++
    }
}

if ($Failures -gt 0) {
    throw "Release gate failed: $Failures test suite(s) failed. Logs: $LogDirectory"
}

Write-Host "Release gate passed. Logs: $LogDirectory"
