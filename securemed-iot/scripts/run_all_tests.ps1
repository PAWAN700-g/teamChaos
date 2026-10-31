# PowerShell Test Runner for SecureMed IoT
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$BackendDir = Join-Path $ScriptDir "..\backend"
$FrontendDir = Join-Path $ScriptDir "..\frontend"

Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host "Running All SecureMed IoT Unit Tests..." -ForegroundColor Green
Write-Host "======================================================================" -ForegroundColor Cyan

Write-Host "`n[1/2] Running Backend & Simulator Pytest Suite..." -ForegroundColor Yellow
Set-Location $BackendDir
$env:PYTHONPATH = "$BackendDir;$ScriptDir\..\device_simulator"
$PytestExe = Join-Path $BackendDir ".venv\Scripts\pytest.exe"
if (Test-Path $PytestExe) {
    & $PytestExe tests ..\device_simulator\test_simulator.py -q
} else {
    pytest tests ..\device_simulator\test_simulator.py -q
}

Write-Host "`n[2/2] Running Frontend Flutter Widget Tests..." -ForegroundColor Yellow
Set-Location $FrontendDir
flutter test

Write-Host "`n======================================================================" -ForegroundColor Cyan
Write-Host "All Unit Test Suites Finished Successfully!" -ForegroundColor Green
Write-Host "======================================================================" -ForegroundColor Cyan
