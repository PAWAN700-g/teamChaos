@echo off
echo ======================================================================
echo Running All SecureMed IoT Unit Tests...
echo ======================================================================

echo [1/2] Running Backend Pytest Suite...
cd /d "%~dp0..\backend"
if exist ".venv\Scripts\pytest.exe" (
    call .venv\Scripts\pytest.exe
) else (
    pytest
)

echo.
echo [2/2] Running Frontend Flutter Widget Tests...
cd /d "%~dp0..\frontend"
call flutter test

echo.
echo ======================================================================
echo All Unit Test Suites Finished.
echo ======================================================================
pause
