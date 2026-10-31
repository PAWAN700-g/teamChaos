@echo off
echo ======================================================================
echo Starting SecureMed IoT Flutter Dashboard...
echo ======================================================================
cd /d "%~dp0..\frontend"
flutter run -d chrome
