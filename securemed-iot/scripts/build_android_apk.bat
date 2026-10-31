@echo off
echo ======================================================================
echo Building SecureMed IoT Android APK...
echo ======================================================================
cd /d "%~dp0..\frontend"
call flutter build apk --debug
echo.
echo Output APK: securemed-iot\frontend\build\app\outputs\flutter-apk\app-debug.apk
echo ======================================================================
pause
