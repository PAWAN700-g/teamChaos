# PowerShell Runner for SecureMed IoT Device Simulator
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$SimDir = Join-Path $ScriptDir "..\device_simulator"
$BackendVenvPython = Join-Path $ScriptDir "..\backend\.venv\Scripts\python.exe"

Set-Location $SimDir

Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host "Starting SecureMed IoT Medical Device Simulator..." -ForegroundColor Green
Write-Host "======================================================================" -ForegroundColor Cyan

if (Test-Path $BackendVenvPython) {
    & $BackendVenvPython simulator.py $args
} else {
    python simulator.py $args
}
