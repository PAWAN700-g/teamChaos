# PowerShell Runner for SecureMed IoT Flutter Dashboard
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$FrontendDir = Join-Path $ScriptDir "..\frontend"
Set-Location $FrontendDir

Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host "Starting SecureMed IoT Flutter Dashboard (Target: Chrome)..." -ForegroundColor Green
Write-Host "======================================================================" -ForegroundColor Cyan

flutter run -d chrome
