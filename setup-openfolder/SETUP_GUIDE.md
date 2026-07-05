# Setup Guide — "Open Folder" Button (openfolder:// Protocol)

## Why is this needed?

Browsers block web pages from opening local folders directly for security
reasons. Google Apps Script web apps are also hosted on Google's servers,
so `file://` links get intercepted and redirected to Google Drive.

The solution is a **custom URI protocol** — the same technique used by
VS Code (`vscode://`), Spotify (`spotify://`), and Slack (`slack://`).
Once registered on a Windows PC, any browser can trigger it to open
Windows Explorer at the correct path.

---

## One-Time Setup (per Windows PC)

Do this **once** on each computer that will use the "Open Folder" button.
No admin rights required.

### Steps

1. **Download both files** from this folder:
   - `OpenHRFolder.ps1`
   - `setup-openfolder-protocol.bat`

2. **Put both files in the same folder** (e.g., your Downloads folder).

3. **Double-click `setup-openfolder-protocol.bat`**.

4. Click **Yes** if Windows asks about running a script.

5. You should see:
   ```
   [OK] Created folder: C:\HR-Tools
   [OK] Copied handler to: C:\HR-Tools\OpenHRFolder.ps1
   [OK] Registered openfolder:// protocol in Windows Registry
   Setup complete!
   ```

6. **Done.** The "Open Folder" button in the HR system now works.

---

## How it works

```
Click "Open Folder" in HR Web App
        ↓
Browser opens: openfolder://D%3A%5CProjects%5CHR
        ↓
Windows sees "openfolder://" → looks up registry
        ↓
Registry says: run PowerShell with this URI
        ↓
PowerShell decodes the path → D:\Projects\HR
        ↓
PowerShell runs: explorer.exe "D:\Projects\HR"
        ↓
Windows Explorer opens the folder ✅
```

---

## Uninstall

To remove the protocol registration:

```batch
reg delete "HKCU\Software\Classes\openfolder" /f
del "C:\HR-Tools\OpenHRFolder.ps1"
```

---

## Corporate / IT Deployment

For deploying to multiple PCs via Group Policy or a deployment tool,
distribute both files and run the `.bat` silently:

```batch
setup-openfolder-protocol.bat
```

The batch script is non-interactive when run non-interactively (the
`pause` at the end only waits when run in a visible window).
