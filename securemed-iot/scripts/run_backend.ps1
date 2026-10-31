# PowerShell Runner for SecureMed IoT FastAPI Gateway
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$BackendDir = Join-Path $ScriptDir "..\backend"
Set-Location $BackendDir

Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host "Starting SecureMed IoT FastAPI Gateway on http://localhost:8000..." -ForegroundColor Green
Write-Host "======================================================================" -ForegroundColor Cyan

$PythonExe = Join-Path $BackendDir ".venv\Scripts\python.exe"
if (Test-Path $PythonExe) {
    & $PythonExe -m uvicorn main:app --host 0.0.0.0 --port 8000 --reload
} else {
    Write-Host "Virtual environment not found at $PythonExe. Using system python..." -ForegroundColor Yellow
    python -m uvicorn main:app --host 0.0.0.0 --port 8000 --reload
}
