# PowerShell Script to Build SecureMed IoT Android APK
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$FrontendDir = Join-Path $ScriptDir "..\frontend"
Set-Location $FrontendDir

Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host "Building SecureMed IoT Android Debug APK..." -ForegroundColor Green
Write-Host "======================================================================" -ForegroundColor Cyan

flutter build apk --debug

$ApkPath = Join-Path $FrontendDir "build\app\outputs\flutter-apk\app-debug.apk"
if (Test-Path $ApkPath) {
    Write-Host "`n[SUCCESS] Android APK built successfully at:" -ForegroundColor Green
    Write-Host $ApkPath -ForegroundColor Yellow
} else {
    Write-Host "`n[ERROR] APK build output not found." -ForegroundColor Red
}
