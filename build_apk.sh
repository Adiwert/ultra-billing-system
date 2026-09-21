#!/usr/bin/env bash
# Build the APK on your own computer (needs Flutter + Android SDK: https://docs.flutter.dev/get-started/install)
set -e
cd "$(dirname "$0")"
flutter create --platforms=android --org com.stewart.quoteinvoice --project-name quote_invoice_maker .
rm -rf test
sed -i.bak 's/android:label="[^"]*"/android:label="Quote \& Invoice"/' android/app/src/main/AndroidManifest.xml && rm -f android/app/src/main/AndroidManifest.xml.bak
flutter pub get
flutter build apk --release
echo "APK: $(pwd)/build/app/outputs/flutter-apk/app-release.apk"
