@echo off
echo ======================================================================
echo Starting SecureMed IoT FastAPI Gateway...
echo ======================================================================
cd /d "%~dp0..\backend"
if exist ".venv\Scripts\python.exe" (
    call .venv\Scripts\activate.bat
    python -m uvicorn main:app --host 0.0.0.0 --port 8000 --reload
) else (
    echo Python virtual environment not found. Please run setup first!
    pause
)
