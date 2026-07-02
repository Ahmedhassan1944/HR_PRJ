# PROMPT — Quick Wins: Backend Security & Reliability Fixes

## ⚠️ CRITICAL RULES
- Make ALL 5 changes below in order. Do not skip any.
- Output **5 separate code blocks**, one per change. Nothing else — no explanation, no summary.
- Do NOT touch `Script.html`, `Index.html`, `Styles.html`, or `Tests.js`.

---

## CONTEXT

This is a Google Apps Script project. All changes are backend-only across 3 files:
- `Database.js`
- `BackupService.js`
- `DriveManager.js`

---

## CHANGE 1 — `Database.js`: Replace hardcoded SPREADSHEET_ID with PropertiesService

**FIND** (exact match — top of file):
```js
const SPREADSHEET_ID = '13tFylpQlgxVu-6H86NRBrkoGbe7eoKoG6iBaPVJYUOE'; // <-- INSERT YOUR SHEET ID
```

**REPLACE WITH:**
```js
// ── Read IDs from Script Properties (Project Settings → Script Properties) ──
// Required keys: SPREADSHEET_ID
const SPREADSHEET_ID = PropertiesService.getScriptProperties().getProperty('SPREADSHEET_ID');
```

> After applying: go to Apps Script → Project Settings → Script Properties →
> add key `SPREADSHEET_ID` with your Sheet ID as the value.

---

## CHANGE 2 — `Database.js`: Add status whitelist in `api_updateCandidateStatus`

**FIND** (exact match — start of function body):
```js
function api_updateCandidateStatus(candidateId, newStatus) {
  try {
    const sheet = getSheet_(SHEET_CANDIDATES);
```

**REPLACE WITH:**
```js
function api_updateCandidateStatus(candidateId, newStatus) {
  const ALLOWED_STATUSES = new Set([
    'New Candidate',
    'Documents Requested',
    'Documents Under Preparing',
    'Pending Passport',
    'Pending Photo',
    'Pending Academic Certificate',
    'Pending Medical',
    'Booked a medical examination',
    'Documents Complete',
    'Visa Pending',
    'Visa Completed',
    'Mobilized',
    'Closed'
  ]);

  if (!ALLOWED_STATUSES.has(newStatus)) {
    return { success: false, error: 'Invalid status value: ' + newStatus };
  }

  try {
    const sheet = getSheet_(SHEET_CANDIDATES);
```

---

## CHANGE 3 — `Database.js`: Remove live schema mutation for Notes column

**FIND** (exact match — inside `api_updateCandidateDetails`):
```js
        if (updates.notes !== undefined) {
          // If Notes column missing, gracefully append it as Column N
          if (notesCol === -1) {
            sheet.getRange(1, headers.length + 1).setValue('Notes');
            sheet.getRange(i + 1, headers.length + 1).setValue(updates.notes);
          } else {
            sheet.getRange(i + 1, notesCol + 1).setValue(updates.notes);
          }
        }
```

**REPLACE WITH:**
```js
        if (updates.notes !== undefined) {
          if (notesCol === -1) {
            // Notes column missing — skip silently and log; do not mutate schema at runtime
            Logger.log('WARNING: Notes column not found in tbl_Candidates. Add it manually.');
          } else {
            sheet.getRange(i + 1, notesCol + 1).setValue(updates.notes);
          }
        }
```

---

## CHANGE 4 — `BackupService.js`: Replace hardcoded IDs + add try/catch + email alert

**FIND** (entire file content — exact match):
```js
function createDailyBackup() {

  const BACKUP_FOLDER_ID = "1FuRicJiOtskOUmE9hr65CeYpVyaZIkoO";

const ss = SpreadsheetApp.openById("13tFylpQlgxVu-6H86NRBrkoGbe7eoKoG6iBaPVJYUOE");
  const timestamp = Utilities.formatDate(
    new Date(),
    Session.getScriptTimeZone(),
    "yyyy-MM-dd_HH-mm"
  );

  const backupName =
    ss.getName() + "_Backup_" + timestamp;

  const file = DriveApp.getFileById(ss.getId());

  file.makeCopy(
    backupName,
    DriveApp.getFolderById(BACKUP_FOLDER_ID)
  );

  Logger.log("Backup Created: " + backupName);
}
```

**REPLACE WITH:**
```js
function createDailyBackup() {
  try {
    const props          = PropertiesService.getScriptProperties();
    const spreadsheetId  = props.getProperty('SPREADSHEET_ID');
    const backupFolderId = props.getProperty('BACKUP_FOLDER_ID');

    if (!spreadsheetId || !backupFolderId) {
      throw new Error('Missing Script Properties: SPREADSHEET_ID or BACKUP_FOLDER_ID not set.');
    }

    const ss        = SpreadsheetApp.openById(spreadsheetId);
    const timestamp = Utilities.formatDate(
      new Date(),
      Session.getScriptTimeZone(),
      'yyyy-MM-dd_HH-mm'
    );
    const backupName = ss.getName() + '_Backup_' + timestamp;
    const file       = DriveApp.getFileById(ss.getId());

    file.makeCopy(backupName, DriveApp.getFolderById(backupFolderId));
    Logger.log('Backup Created: ' + backupName);

  } catch (e) {
    Logger.log('BACKUP FAILED: ' + e.message);
    MailApp.sendEmail(
      Session.getEffectiveUser().getEmail(),
      '⚠️ HR System — Daily Backup Failed',
      'The daily backup failed with the following error:\n\n' +
      e.message +
      '\n\nPlease check the Apps Script execution log immediately.'
    );
  }
}
```

> After applying: add key `BACKUP_FOLDER_ID` to Script Properties alongside `SPREADSHEET_ID`.

---

## CHANGE 5 — `DriveManager.js`: Add server-side file type & size validation

**FIND** (exact match — start of function body inside `api_uploadFileToDrive`):
```js
function api_uploadFileToDrive(candidateId, folderId, docType, fileName, base64Data, mimeType) {
  try {
    const folder = DriveApp.getFolderById(folderId);
    
    // Decode and build the file blob
    const decoded = Utilities.base64Decode(base64Data);
```

**REPLACE WITH:**
```js
function api_uploadFileToDrive(candidateId, folderId, docType, fileName, base64Data, mimeType) {
  // ── Server-side validation (never trust the client) ──────────────────
  const ALLOWED_MIME_TYPES = new Set([
    'application/pdf',
    'image/jpeg',
    'image/png'
  ]);
  const MAX_FILE_BYTES = 10 * 1024 * 1024; // 10 MB

  if (!ALLOWED_MIME_TYPES.has(mimeType)) {
    return { success: false, error: 'File type not allowed: ' + mimeType + '. Only PDF, JPG, PNG are accepted.' };
  }

  // Estimate original size from base64 length (base64 inflates by ~4/3)
  const estimatedBytes = Math.floor(base64Data.length * 0.75);
  if (estimatedBytes > MAX_FILE_BYTES) {
    return { success: false, error: 'File exceeds the 10 MB size limit.' };
  }
  // ─────────────────────────────────────────────────────────────────────

  try {
    const folder = DriveApp.getFolderById(folderId);

    // Decode and build the file blob
    const decoded = Utilities.base64Decode(base64Data);
```

---

## MANDATORY OUTPUT FORMAT

Output exactly **5 code blocks** in this order — nothing else:

1. ` ```js ` — SPREADSHEET_ID via PropertiesService (Change 1)
2. ` ```js ` — `api_updateCandidateStatus` with whitelist (Change 2)
3. ` ```js ` — `api_updateCandidateDetails` Notes fix (Change 3)
4. ` ```js ` — Full `createDailyBackup` replacement (Change 4)
5. ` ```js ` — `api_uploadFileToDrive` with server-side validation (Change 5)

---

## RISK TABLE

| # | File | Target | Risk |
|---|------|--------|------|
| 1 | `Database.js` | Top-level `SPREADSHEET_ID` constant | 🟢 Safe — requires Script Property to be set first |
| 2 | `Database.js` | `api_updateCandidateStatus` | 🟢 Safe — rejects invalid values, valid ones pass through |
| 3 | `Database.js` | `api_updateCandidateDetails` Notes block | 🟢 Safe — removes silent schema mutation, logs warning instead |
| 4 | `BackupService.js` | Entire `createDailyBackup` function | 🟢 Safe — same logic, adds error handling |
| 5 | `DriveManager.js` | `api_uploadFileToDrive` entry guard | 🟢 Safe — only rejects disallowed types/oversized files |

**⚠️ Before deploying Change 1:** Set `SPREADSHEET_ID` (and `BACKUP_FOLDER_ID` for Change 4)
in Apps Script → Project Settings → Script Properties.
Otherwise `getSheet_()` will receive `null` and all DB calls will fail.

**Zero frontend changes. Zero HTML or CSS touched.**