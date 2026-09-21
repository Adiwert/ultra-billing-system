# Uploading this project to GitHub (and getting your APK from it)

## Why GitHub?
GitHub is a website that stores your code online (a "repository", or "repo"). It also has free build
servers ("GitHub Actions"). This project includes a recipe (`.github/workflows/build-apk.yml`) that tells
those servers: "install Flutter, build the app, give me the APK". So you can get an APK without installing
Flutter and Android Studio on your PC.

Key words:
- **Git**: the program on your PC that tracks changes to your files.
- **GitHub**: the website that stores a copy of your Git project.
- **Commit**: a saved snapshot of your files, with a short message.
- **Push**: send your commits from your PC up to GitHub.
- **Repository (repo)**: the project's folder on GitHub.

---

## Step 0. Before you start
1. Delete the leftover file `quote_invoice_maker.zip` in this folder (I could not delete it for you; it
   is not needed, and is ignored by Git anyway).
2. Create a free account at https://github.com/signup (verify your email).

## Step 1. Install Git for Windows
Download from https://git-scm.com/download/win and install with the default options.
Check it: open PowerShell and run `git --version`. You should see a version number.

## Step 2. Create an empty repository on GitHub
1. Log in to GitHub. Click the **+** at the top right -> **New repository**.
2. Repository name: `ultra-billing-system`
3. Choose **Private** (only you can see it) or **Public**. Private is recommended for a business app.
4. **Do NOT** tick "Add a README", ".gitignore" or "license". The repo must be empty because your folder
   already has those files.
5. Click **Create repository**. Keep this page open; it shows your repo address, like
   `https://github.com/YOUR-USERNAME/ultra-billing-system.git`

## Step 3. Push your folder (command line method, recommended)
Open **PowerShell** and run these one at a time. Replace the name/email/username with yours.

```powershell
cd D:\ultra-billing-system

# Tell Git who you are (only needed once per computer)
git config --global user.name "Your Name"
git config --global user.email "you@example.com"

# Turn the folder into a Git project, on a branch called main
git init -b main

# Choose all files (respecting .gitignore), then save a snapshot
git add .
git commit -m "Initial commit: quote and invoice maker app"

# Connect to your GitHub repo and upload
git remote add origin https://github.com/YOUR-USERNAME/ultra-billing-system.git
git push -u origin main
```

What each line does:
- `cd` moves into your project folder.
- `git init -b main` creates the hidden `.git` folder where Git keeps history.
- `git add .` marks every file to be included; `git commit` saves the snapshot.
- `git remote add origin ...` tells Git where the GitHub repo lives ("origin" is just a nickname).
- `git push -u origin main` uploads it.

**Logging in:** the first push opens a browser window to sign in to GitHub. Approve it. (If it asks for a
password in the terminal, GitHub no longer accepts your normal password. Create a *Personal access
token* at GitHub -> Settings -> Developer settings -> Personal access tokens -> Tokens (classic), tick
`repo` and `workflow`, and paste that token as the password.)

Refresh the GitHub page. You should see your files, including `lib`, `pubspec.yaml` and `.github`.

## Alternative: GitHub Desktop (no commands)
1. Install https://desktop.github.com and sign in.
2. File -> **Add local repository** -> choose `D:\ultra-billing-system` -> if it says it is not a Git
   repository, click "create a repository here".
3. Type a summary like "Initial commit" -> **Commit to main** -> **Publish repository** (choose private or
   public).

## Alternative: upload in the browser (no install)
On your repo page click **uploading an existing file**, drag in the contents of the folder, and commit.
Caution: the browser may skip the hidden `.github` folder. If it does, the APK build will not appear.
Make sure `.github/workflows/build-apk.yml` is visible in the repo after upload. The Git or Desktop methods
avoid this problem.

---

## Step 4. Build the APK on GitHub
1. On your repo page, click the **Actions** tab. (If GitHub shows a button to enable workflows, click it.)
2. The build starts by itself after your push. You can also start it manually: click
   **Build Android APK** in the left list -> **Run workflow** -> **Run workflow**.
3. Wait about 5-10 minutes. A yellow dot means running, a green tick means success, a red cross means
   failure.
4. Click the finished run. Scroll to **Artifacts** at the bottom and click
   **quote-invoice-maker-apk** to download a zip. Unzip it to get `app-release.apk`.
5. Copy `app-release.apk` to your phone, tap it, allow "Install unknown apps" when asked.

Notes:
- Artifacts are kept for 90 days by default, then deleted. Download and keep the APK.
- The repo has no `android/` folder on purpose. The build recipe generates it fresh each time, so it always
  matches the current Flutter version.

## Step 5. If the build fails (red cross)
The first build of code that has never been compiled may have small mistakes. This is normal.
1. Click the failed run -> click the red step (e.g. "flutter build apk" or "flutter analyze").
2. Copy the last 30-50 lines of the log, especially lines that contain `Error:` and a file name.
3. Send them to me and I will fix the code. Then update GitHub (next section).

## Updating GitHub after changes
Whenever files change (from me or you):
```powershell
cd D:\ultra-billing-system
git add .
git commit -m "Describe what changed"
git push
```
The push triggers a new build automatically.

## Common problems
| Problem | Fix |
|---|---|
| `git` is not recognised | Reopen PowerShell after installing Git, or reinstall it |
| `remote origin already exists` | Run `git remote set-url origin https://github.com/YOUR-USERNAME/ultra-billing-system.git` |
| `Updates were rejected` / `fetch first` | You ticked "Add a README" when creating the repo. Easiest: delete the repo on GitHub and create it again empty. |
| Authentication failed | Use the browser sign-in, or a Personal access token (see Step 3) |
| Actions tab has no workflow | `.github/workflows/build-apk.yml` did not upload. Check it exists in the repo. |
| "dubious ownership" error | Run `git config --global --add safe.directory D:/ultra-billing-system` |

## Safety tips
- Never upload passwords, API keys, or signing keystore files (`.jks`, `.keystore`). If you later create a
  release signing key for Google Play, keep it out of Git.
- Private repos are safest for business software.
