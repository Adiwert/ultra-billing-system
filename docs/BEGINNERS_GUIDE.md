# Beginner's Guide: Quote & Invoice Maker

This guide assumes you have never built software before. It explains:

1. What was built, and how apps like it work
2. What you need to download and install (and why)
3. How to turn the source code into an APK you can install on your phone
4. What every file in the project does
5. How to change things yourself
6. What to learn next, in order
7. Honest status: what is finished and what is not

---

## Part 1. The big picture

### What is an app, really?

An Android app is a program written in a programming language, then **compiled** (translated) into a
single file called an **APK** (Android Package). You copy the APK to a phone and install it. Everything
you see on screen (buttons, lists, forms) is described by code.

### What did I build?

A phone app for small businesses. It creates six kinds of documents: quotation, invoice, purchase order,
proforma invoice, delivery note, and receipt. It stores customers and products, makes PDFs you can share
on WhatsApp or email, and produces reports.

### Which tools did I choose, and why?

| Choice | What it is | Why |
|---|---|---|
| **Dart** | The programming language | You asked for Dart. It is easy to read and is the language Flutter uses. |
| **Flutter** | A toolkit made by Google for building apps | One codebase, and it draws every button itself so the app looks the same on every Android phone and adapts to any screen size. |
| **Material 3** | Google's design system | Ready-made buttons, cards, forms, navigation bars. |
| **SQLite** | A small database inside the phone | Stores customers, products and documents permanently. No internet or server needed. |
| **SharedPreferences** | A tiny key/value store | Stores settings (business name, currency, number prefixes) and the login. |

### "Offline-first" (the design decision you approved)

Everything is stored on the phone. There is **no server**. Advantages: nothing to pay for, no setup,
works without internet. Trade-offs: no sync between two phones, and if the phone is lost or the app is
uninstalled the data is gone (there is no backup feature yet). "Login" is a local password protecting the
app on that one phone.

---

## Part 2. Vocabulary (read this once, refer back later)

| Word | Meaning |
|---|---|
| **Source code** | The text files a programmer writes (`.dart` files here). |
| **SDK** | Software Development Kit: a bundle of tools, libraries and instructions for building a certain kind of software. "Flutter SDK", "Android SDK". |
| **Compiler / build** | The program that turns source code into a runnable app. "Building" = compiling + packaging. |
| **APK** | The installable Android app file. |
| **IDE** | The editor you write code in (Android Studio, VS Code). Optional for just building. |
| **Package / dependency** | Code someone else wrote that we reuse (for example, `pdf` makes PDFs). Listed in `pubspec.yaml`. |
| **pub.dev** | The website/library store where Dart packages live. `flutter pub get` downloads them. |
| **Widget** | In Flutter, everything on screen is a widget: text, button, a whole screen. Widgets are nested like boxes inside boxes. |
| **State** | Data that can change while the app runs (what you typed, the list of invoices). When state changes, the screen redraws. |
| **Screen** | A full-page widget (Settings, Invoice editor). Moving between screens is called navigation. |
| **Model** | A small piece of code describing a thing, e.g. an Invoice has a number, date, customer, items. |
| **Emulator** | A pretend phone that runs on your PC. |
| **Gradle** | The Android build tool Flutter calls behind the scenes. It downloads a lot the first time. |
| **Debug vs release build** | Debug is slower and for developing. Release is optimised and is the one you give to users. |
| **Signing** | Android requires every APK to be signed with a digital key. My build uses a temporary "debug" key. Google Play needs your own key. |

---

## Part 3. What to download (Windows PC)

Your computer is Windows 64-bit. You need about **10-15 GB free disk space** and a decent internet
connection (first setup downloads several GB). Do these in order.

### 3.1 Git for Windows
- **What:** a tool for tracking code versions. Flutter needs it internally.
- **Get it:** https://git-scm.com/download/win , run the installer, accept the defaults.

### 3.2 Flutter SDK
- **What:** the Flutter toolkit and the Dart language, together.
- **Get it:** https://docs.flutter.dev/get-started/install/windows/mobile , download the zip.
- **Install:**
  1. Unzip to a simple path without spaces, e.g. `C:\dev\flutter`.
     Do **not** put it in `C:\Program Files` (permission problems).
  2. Add `C:\dev\flutter\bin` to your **PATH** so the `flutter` command works everywhere:
     Start menu -> "Edit the system environment variables" -> Environment Variables ->
     under "User variables" select `Path` -> Edit -> New -> paste `C:\dev\flutter\bin` -> OK.
  3. Close and reopen any terminal, then run `flutter --version` to check.

### 3.3 Android Studio (this also provides the Android SDK and Java)
- **What:** Google's official Android editor. We mostly need what it installs: the **Android SDK**
  (the tools that make APKs) and a bundled **Java** runtime that Gradle uses.
- **Get it:** https://developer.android.com/studio
- **Install:** run it, accept defaults, and let the setup wizard download the SDK.
- **Then add two extras:** open Android Studio -> More Actions -> SDK Manager ->
  **SDK Tools** tab -> tick **Android SDK Command-line Tools (latest)** -> Apply.
  Also on the **SDK Platforms** tab keep the newest Android version ticked.

I noticed your computer already has `.android` and `.gradle` folders, so you may already have Android
Studio installed. If so, just check the extras above.

### 3.4 Accept the Android licences
Open **PowerShell** and run:

```
flutter doctor --android-licenses
```
Press `y` and Enter for each question.

### 3.5 Turn on Windows Developer Mode
Flutter's plugins use symbolic links, which Windows only allows in Developer Mode.
Run `start ms-settings:developers` in PowerShell and switch **Developer Mode** on.

### 3.6 Check everything
```
flutter doctor
```
You want green ticks next to **Flutter**, **Windows Version**, **Android toolchain** and
**Android Studio**. Anything marked with a red cross tells you what is missing; follow its message.
(Visual Studio and Chrome items do not matter; we only build for Android.)

### 3.7 Optional but recommended
- **VS Code** (https://code.visualstudio.com) with the **Flutter** extension, for reading and editing
  code comfortably. Android Studio also works.
- **A real Android phone**: Settings -> About phone -> tap "Build number" 7 times -> back to Settings ->
  Developer options -> turn on **USB debugging**. Then a USB cable lets you run the app directly.

---

## Part 4. Turning the code into an APK

### Option A: on your PC (after Part 3)

1. Unzip `quote_invoice_maker.zip` somewhere simple, e.g. `C:\dev\quote_invoice_maker`.
2. Double-click **`build_apk.bat`**. It runs these commands for you:

| Command | What it does |
|---|---|
| `flutter create --platforms=android ...` | Generates the `android/` folder, the technical wrapper Android needs around our Dart code. I deliberately did not hand-write it because Flutter generates a version matching your installed Flutter, which is far less error-prone. It never overwrites our `lib/` code. |
| `flutter pub get` | Downloads all the packages in `pubspec.yaml` from pub.dev. |
| `flutter build apk --release` | Compiles everything into the final APK. First time takes 5-15 minutes and downloads a lot. |

3. Your APK appears at
   `build\app\outputs\flutter-apk\app-release.apk`.
4. Copy it to the phone (USB, Google Drive, WhatsApp to yourself) and open it. Android will ask you to
   allow "Install unknown apps" for the app you opened it from.

### Option B: on GitHub (nothing installed)

The file `.github/workflows/build-apk.yml` tells GitHub's free servers to do Option A for you.
Create a GitHub account and a new repository, upload the project, and open
**Actions -> Build Android APK -> Run workflow**. When done, download the APK from that run's page.

### Trying the app on a phone connected by USB (fast way to test)
```
cd C:\dev\quote_invoice_maker
flutter run
```
While it runs, press `r` in the terminal after you edit code to see changes instantly
(this is Flutter's "hot reload").

---

## Part 5. What I did, file by file

The project folder:

```
quote_invoice_maker/
  pubspec.yaml            list of packages and app name
  build_apk.bat / .sh     one-click build scripts
  .github/workflows/      GitHub automatic build recipe
  docs/                   this guide
  lib/                    ALL the app's own code lives here
    main.dart
    models.dart
    store.dart
    pdf_gen.dart
    widgets.dart
    screens/
      auth.dart
      home.dart
      customers.dart
      doc_list.dart
      doc_edit.dart
      settings.dart
      reports.dart
```

### `pubspec.yaml`: the shopping list
Names the app and lists the packages used:
- `sqflite`, `path`, `path_provider`: the database and finding where to store files on the phone
- `shared_preferences`: saving settings
- `image_picker`: choosing a logo/signature/QR from the gallery
- `pdf`, `printing`: building PDF files, and the share/print preview
- `share_plus`: the phone's Share sheet (used for CSV files)
- `intl`: formatting dates and money
- `crypto`: scrambling (hashing) passwords

### `lib/main.dart`: the front door
Every Flutter app starts at `main()`. Ours opens the database, then shows either the login screen or the
home screen depending on whether you are logged in. It also sets the theme (colours) and limits how much
the phone's "font size" setting can stretch the text so layouts never break.

### `lib/models.dart`: describing your business data
- `DocType`: the six document types, and the labels/rules for each (e.g. a delivery note has no prices,
  a receipt has no discount).
- `Party`: a customer.
- `LineItem`: one product row (name, description, quantity, price, tax %).
- `Charge`: an "other charge", such as shipping.
- `DocModel`: one whole document. It also does the maths: subtotal, discount, tax, other charges, total,
  paid and balance.

Money maths lives here in one place so the screen and the PDF always agree.

### `lib/store.dart`: memory
The only file that talks to the database and to saved settings.
- **Database tables:** `customers`, `products`, `docs`. Each row stores the item as JSON text.
  (JSON is a plain-text way to write structured data, e.g. `{"name": "Ali"}`.)
- **Settings:** grouped, e.g. `business`, `doc_invoice`, `columns`, `general`.
  `get()` returns your saved value or a sensible default.
- **Numbering:** builds `INV-0001` from prefix + serial, and increases the serial after each save.
- **Account:** register, login, logout, change password, delete account. Passwords are never stored;
  only a SHA-256 hash (a one-way scramble) is. This is fine for a private local app, but it is not
  bank-grade security.
- **Images:** copies the logo/signature/QR into the app's private storage.

### `lib/pdf_gen.dart`: printing
Builds the A4 PDF for a document: header with logo, customer box, item table, totals, payment
instructions (bank text and QR), terms, bottom message, signature. It respects your document settings
(show/hide discount, tax, shipping, bank, QR, signature). It also builds report PDFs.

### `lib/widgets.dart`: reusable pieces
`Field` (a labelled text box), `ImageField` (pick a picture), `SignaturePad` (draw a signature with your
finger), and small helpers. Reusing these keeps the screens short.

### `lib/screens/`
| File | What you see |
|---|---|
| `auth.dart` | Create account (first launch) / log in |
| `home.dart` | Bottom bar with 4 tabs: Documents, Customers, Reports, Settings. The Documents tab is the grid of six document types. |
| `doc_list.dart` | List of one type (e.g. all invoices), search, share PDF, duplicate, delete, "Convert to..." (quotation to invoice, invoice to receipt, ...) |
| `doc_edit.dart` | The create/edit form: customer, products, other charges, discount, totals, paid info, terms, notes, PDF preview |
| `customers.dart` | Customer list and saved products |
| `reports.dart` | Choose type, customer, dates; download PDF or CSV |
| `settings.dart` | Profile, Business info, six document settings pages, column headings, date & currency, Subscription (placeholder), Logout |

### How the pieces work together: creating an invoice
1. You tap **Invoices** on `home.dart`, then **New Invoice** in `doc_list.dart`.
2. `doc_edit.dart` makes a blank `DocModel`, asking `store.dart` for the next number (`INV-0001`) and
   your default terms from Settings.
3. As you type, each keystroke updates the `DocModel` and calls `setState`, so the totals redraw at once.
4. **Save** calls `store.saveDoc()`, which writes it to SQLite and bumps the serial number to 2.
5. **Share as PDF** calls `pdf_gen.dart` to draw the page, then Android's share sheet sends it.

### How the app "fits any screen"
- Layouts scroll (`ListView`) instead of assuming a fixed height.
- The dashboard grid uses `maxCrossAxisExtent`, so it shows 2 columns on a phone and more on a tablet.
- Rows switch layout by available width (`LayoutBuilder`).
- `SafeArea` keeps content out from under notches and the navigation bar.
- Text scaling is capped between 0.85x and 1.3x.

---

## Part 6. Making changes yourself (recipes)

| I want to... | Do this |
|---|---|
| Change the app colour | `lib/main.dart`, change `0xFF1F4E79` (a hex colour) |
| Change the default currency | `lib/store.dart`, in `defaults()` under `'general'` change `'RM'` |
| Change default number prefixes | `lib/models.dart`, the `defaultPrefix` list (or use Settings in the app) |
| Change app name shown on the phone | `android/app/src/main/AndroidManifest.xml`, `android:label` |
| Change PDF colours | top of `lib/pdf_gen.dart` (`_accent`, `_light`, `_grey`) |
| Add a field to customers (e.g. website) | Add it to `Party` in `models.dart` (constructor, `toJson`, `fromJson`), then add a `Field(...)` in `customers.dart`. Old data keeps working because missing values default to empty. |
| Change the app icon | Add the package `flutter_launcher_icons` (search pub.dev for instructions) |

After changing code, run `flutter run` to test, or `build_apk.bat` again for a new APK.

---

## Part 7. If something goes wrong

| Problem | What to try |
|---|---|
| `flutter` is not recognised | PATH not set; reopen the terminal; recheck 3.2 |
| `flutter doctor` says Android licences not accepted | Run `flutter doctor --android-licenses` |
| "cmdline-tools component is missing" | Install Android SDK Command-line Tools (3.3) |
| Build fails with "symlink" or "Developer Mode" | Turn on Developer Mode (3.5) |
| Very slow first build | Normal. Gradle downloads a lot once. |
| Red compile errors mentioning a `.dart` file and line | Copy the message and send it to me. See Part 8, this is expected for a first build. |
| `flutter pub get` fails with version conflicts | Send me the message; version numbers in `pubspec.yaml` may need adjusting. |
| Phone says "App not installed" | Uninstall any older copy first, and allow unknown apps |
| Try clean start | `flutter clean` then build again |

---

## Part 8. Honest status

**Written but not yet compiled.** The environment I worked in could not download the Flutter engine or the
Android SDK (blocked by network policy), so I wrote the code carefully and reviewed it by reading, but
never actually ran it. Expect that your first build may show a few small errors (typos, a package version
that moved on). They are normally quick to fix; send me the exact messages.

**Not done / limitations**
- Subscription is a "Coming soon" placeholder, as you chose.
- No cloud sync, no backup/restore, no multi-device.
- No forgot-password recovery (it is a local account).
- The APK is signed with a debug key. Google Play needs a proper signing key and store listing.
- PDFs use a standard Latin font, so unusual currency symbols and non-Latin text (e.g. Chinese) may not
  print. Codes such as "RM" or "USD" are fine. Supporting Chinese needs an embedded font.
- Only Android. iPhone would need a Mac to build.

---

## Part 9. What to learn, in order

You do not need to learn everything to use or tweak this app. If you want to truly understand it:

1. **Dart basics** (1-2 weeks): variables, functions, classes, lists/maps, `async`/`await`, null safety.
   Official: https://dart.dev/language and the interactive https://dartpad.dev
2. **Flutter first app** (1-2 weeks): widgets, layout (Row/Column/Expanded), StatefulWidget and
   `setState`, navigation. Official codelabs: https://docs.flutter.dev/codelabs
   and the "Widget of the week" video series on the Flutter YouTube channel.
3. **Local storage** (1 week): SQLite with `sqflite`, SharedPreferences. Documented on pub.dev.
4. **Read this project in this order:** `models.dart` -> `store.dart` -> `widgets.dart` -> `home.dart`
   -> `customers.dart` -> `doc_list.dart` -> `doc_edit.dart` -> `pdf_gen.dart`.
5. **Later topics:** state management (Provider/Riverpod), Firebase (login and cloud sync),
   Google Play Billing (real subscriptions), publishing to Google Play.

Tip: change something tiny (a label, a colour), run it, and watch what happens. That is the fastest way
to learn.
