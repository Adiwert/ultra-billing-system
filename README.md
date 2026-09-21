# Quote & Invoice Maker (Flutter / Dart, Android)

Offline-first app: quotations, invoices, purchase orders, proforma invoices, delivery notes, receipts,
customers, saved products, PDF export/share, PDF + CSV reports. Data is stored on the phone (SQLite).

## Get the APK (pick one)

### A. GitHub Actions (no installs on your PC)
1. Create a new GitHub repo and upload the contents of this folder (including `.github/`).
2. Open the repo -> Actions -> "Build Android APK" -> Run workflow.
3. When it finishes, download `quote-invoice-maker-apk` from the run page and unzip -> `app-release.apk`.
4. Copy it to your phone and install (allow "install unknown apps").

### B. On your own computer
1. Install Flutter (https://docs.flutter.dev/get-started/install) and Android Studio (for the Android SDK); run `flutter doctor`.
2. Run `build_apk.sh` (Mac/Linux) or `build_apk.bat` (Windows).
3. APK: `build/app/outputs/flutter-apk/app-release.apk`.

The script runs `flutter create --platforms=android .` which generates the `android/` folder around the
existing `lib/` and `pubspec.yaml`.

## Project layout
- `lib/models.dart`   document, customer, item models + totals maths
- `lib/store.dart`    SQLite + settings + local account
- `lib/pdf_gen.dart`  document PDF and report PDF
- `lib/screens/`      auth, home, settings, customers/products, document list + editor, reports

New to app development? Read docs/BEGINNERS_GUIDE.md first.

To put this on GitHub and get the APK: docs/GITHUB_UPLOAD_GUIDE.md
