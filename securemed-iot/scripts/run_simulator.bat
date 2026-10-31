@echo off
echo ======================================================================
echo Starting SecureMed IoT Medical Device Simulator...
echo ======================================================================
cd /d "%~dp0..\device_simulator"
if exist "..\backend\.venv\Scripts\python.exe" (
    call ..\backend\.venv\Scripts\activate.bat
    python simulator.py
) else (
    python simulator.py
)
pause
