@echo off
cd /d "%~dp0"
call flutter create --platforms=android --org com.stewart.quoteinvoice --project-name quote_invoice_maker .
if exist test rmdir /s /q test
call flutter pub get
call flutter build apk --release
echo APK: %cd%\build\app\outputs\flutter-apk\app-release.apk
pause
