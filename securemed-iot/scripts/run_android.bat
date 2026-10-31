@echo off
echo ======================================================================
echo Starting SecureMed IoT Android App on Device / Emulator...
echo ======================================================================
cd /d "%~dp0..\frontend"
flutter run -d android
