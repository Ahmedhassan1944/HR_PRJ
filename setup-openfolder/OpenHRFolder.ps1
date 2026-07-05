# =============================================================
# OpenHRFolder.ps1 — Handler for the openfolder:// protocol
# Place this file at: C:\HR-Tools\OpenHRFolder.ps1
# =============================================================
# Windows calls this script with the full URI as the first argument.
# Example: openfolder://D%3A%5CProjects%5CGoogleAppsScript(HR)
# We decode it and open in Windows Explorer.

param([string]$Uri)

try {
    # Strip the protocol prefix
    $encoded = $Uri -replace '^openfolder://', ''

    # URL-decode (handles %20, %5C, %3A, parentheses, etc.)
    $path = [System.Uri]::UnescapeDataString($encoded)

    # Remove any trailing slash left over from the URI
    $path = $path.TrimEnd('/')

    # Open Windows Explorer at the decoded path
    if ($path -ne '') {
        Start-Process explorer.exe -ArgumentList "`"$path`""
    }
} catch {
    # Silent failure — never show an error dialog to the user
}
