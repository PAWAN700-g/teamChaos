# PowerShell Runner for SecureMed IoT Android App
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$FrontendDir = Join-Path $ScriptDir "..\frontend"
Set-Location $FrontendDir

Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host "Starting SecureMed IoT on Android (Emulator / Connected Device)..." -ForegroundColor Green
Write-Host "======================================================================" -ForegroundColor Cyan

flutter run -d android
