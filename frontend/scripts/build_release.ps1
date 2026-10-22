param (
    [string]$Target = "apk",
    [string]$SymbolsDir = "build/app/outputs/symbols",
    [switch]$AllowLocalDebugSigning,
    [switch]$EnforceProductionSigning
)

$ErrorActionPreference = "Stop"

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host " My Root — Flutter Hardened Release Build" -ForegroundColor Cyan
Write-Host " Target: $Target" -ForegroundColor Cyan
Write-Host " Symbol Directory: $SymbolsDir" -ForegroundColor Cyan

$extraArgs = @()

if ($EnforceProductionSigning) {
    Write-Host " Policy: PRODUCTION SIGNING ENFORCED (-PenforceProductionSigning=true)" -ForegroundColor Green
    $extraArgs += "-PenforceProductionSigning=true"
}

if ($AllowLocalDebugSigning) {
    Write-Host " Mode: NON-PRODUCTION Local Debug Signing" -ForegroundColor Yellow
    Write-Host " WARNING: Artifact will be signed with Android debug key." -ForegroundColor Yellow
    Write-Host "          This artifact MUST NOT be deployed to production." -ForegroundColor Yellow
    $extraArgs += "-PallowLocalDebugSigning=true"
} else {
    Write-Host " Mode: PRODUCTION SIGNING REQUIRED" -ForegroundColor Green
    Write-Host " NOTICE: Build will fail closed if production signing" -ForegroundColor Green
    Write-Host "         credentials are not explicitly configured." -ForegroundColor Green
}
Write-Host "==========================================" -ForegroundColor Cyan

# Ensure symbol output directory exists
if (!(Test-Path $SymbolsDir)) {
    New-Item -ItemType Directory -Force -Path $SymbolsDir | Out-Null
}

$cmdArgs = @("build", $Target, "--release", "--obfuscate", "--split-debug-info=$SymbolsDir") + $extraArgs

Write-Host "Executing: flutter $cmdArgs" -ForegroundColor Yellow

& flutter @cmdArgs

if ($LASTEXITCODE -ne 0) {
    Write-Host "==========================================" -ForegroundColor Red
    Write-Host " Release build failed with exit code $LASTEXITCODE" -ForegroundColor Red
    Write-Host "==========================================" -ForegroundColor Red
    exit $LASTEXITCODE
}

Write-Host "==========================================" -ForegroundColor Green
Write-Host " Release build completed successfully!" -ForegroundColor Green
Write-Host " Symbol files saved to: $SymbolsDir" -ForegroundColor Green
Write-Host " Retain symbol files securely for crash symbolication." -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
