param(
    [string]$Target = $env:ROKU_DEV_TARGET,
    [string]$Password = $env:ROKU_DEV_PASSWORD,
    [switch]$Remove,
    [switch]$BuildOnly
)

# Simple wrapper to package and install/remove the dev channel using the existing Makefile.
# Requires: make, curl, zip in PATH (same as the Makefile), and dev mode enabled on the Roku.

$projectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $projectRoot

if (-not $Target) {
    Write-Error "ROKU_DEV_TARGET is missing. Pass -Target or set the env var.";
    exit 1
}

# Propagate credentials to make (DEVPASSWORD is read in app.mk; defaults to rokudev:1088 there)
if ($Password) {
    $env:DEVPASSWORD = $Password
}
$env:ROKU_DEV_TARGET = $Target

$make = Get-Command make -ErrorAction SilentlyContinue
if (-not $make) {
    Write-Error "make is not available in PATH. Install make (e.g., Git for Windows / MSYS) or run the Makefile manually.";
    exit 1
}

$target = if ($Remove) { "remove" } elseif ($BuildOnly) { "SpamFilms3" } else { "install" }

Write-Host "Running: make $target" -ForegroundColor Cyan
& $make.Source $target
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

if (-not $Remove -and -not $BuildOnly) {
    Write-Host "Install complete to $Target" -ForegroundColor Green
} elseif ($BuildOnly) {
    Write-Host "Build complete; zip at dist/apps/SpamFilms3.zip" -ForegroundColor Green
} else {
    Write-Host "Removed dev app from $Target" -ForegroundColor Green
}
