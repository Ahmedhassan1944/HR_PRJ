# PROMPT — Authorization Layer: Role-Based Access Control

## ⚠️ PREREQUISITES
- Prompt 1 (Quick Wins) MUST be applied.
- Prompt 2 (Fix Test Suite) MUST be applied.

## ⚠️ CRITICAL RULES
- Apply ALL 4 changes in order — do NOT skip the Tests.js change.
  Skipping it will break every existing test.
- Each change contains one or more FIND/REPLACE blocks clearly labeled A, B, C…
- Output **4 code blocks**, one per change, nothing else.
- Do NOT touch `Code.js`, `BackupService.js`, `Styles.html`,
  `Index.html`, or `Script.html`.

---

## CONTEXT

`tbl_Users` sheet schema: `UserID | Email | Role | Name`
Supported roles (exact strings, case-sensitive): `Admin`, `HR`, `Coordinator`, `Viewer`

Two internal helpers will be added to `Database.js`:
- `getCurrentUserRole_()` — looks up the current user's email in `tbl_Users` and returns their role string, or `null` if not found.
- `requireRole_(allowedRoles)` — returns `{ authorized: true }` or `{ authorized: false, error: '...' }`.

Every public mutating `api_*` function then calls `requireRole_` as its very first line.
Read-only functions (`api_getAllCandidates`, `api_getAllDocuments`,
`api_getDocumentsByCandidate`, `api_getDashboardData`) are left open — any authenticated
Google user can read, but only registered roles can write.

**Exception:** `api_getAuditLog` is read-only but contains sensitive actor/action data →
restrict to `Admin` and `HR` only.

---

## CHANGE 1 — `Database.js`: Add auth helpers + role guards (5 blocks)

### Block A — Insert `getCurrentUserRole_` + `requireRole_` after `generateUUID_`

**FIND** (exact match):
```js
function generateUUID_() {
  return Utilities.getUuid();
}

// ─────────────────────────────────────────────
// CANDIDATES
// ─────────────────────────────────────────────
```

**REPLACE WITH:**
```js
function generateUUID_() {
  return Utilities.getUuid();
}

// ─────────────────────────────────────────────
// AUTHORIZATION HELPERS
// ─────────────────────────────────────────────

/**
 * Looks up the current user's role from tbl_Users.
 * Returns the role string ('Admin', 'HR', 'Coordinator', 'Viewer')
 * or null if the user is not registered.
 */
function getCurrentUserRole_() {
  try {
    const email = (Session.getActiveUser().getEmail() || '').toLowerCase();
    if (!email) return null;
    const sheet   = getSheet_(SHEET_USERS);
    const data    = sheet.getDataRange().getValues();
    const headers = data[0];
    const emailCol = headers.indexOf('Email');
    const roleCol  = headers.indexOf('Role');
    for (let i = 1; i < data.length; i++) {
      if ((data[i][emailCol] || '').toString().toLowerCase() === email) {
        return data[i][roleCol] || null;
      }
    }
    return null;
  } catch (e) {
    Logger.log('getCurrentUserRole_ error: ' + e.message);
    return null;
  }
}

/**
 * Checks that the current user holds one of the allowed roles.
 * @param {string[]} allowedRoles - e.g. ['Admin', 'HR']
 * @returns {{ authorized: boolean, role?: string, error?: string }}
 */
function requireRole_(allowedRoles) {
  const role = getCurrentUserRole_();
  if (!role) {
    return { authorized: false,
      error: 'Access denied: your account (' +
             (Session.getActiveUser().getEmail() || 'unknown') +
             ') is not registered in the HR system.' };
  }
  if (!allowedRoles.includes(role)) {
    return { authorized: false,
      error: 'Access denied: your role (' + role + ') does not have permission for this action.' };
  }
  return { authorized: true, role };
}

// ─────────────────────────────────────────────
// CANDIDATES
// ─────────────────────────────────────────────
```

---

### Block B — Guard `api_createCandidate` (Admin, HR only)

**FIND** (exact match):
```js
function api_createCandidate(candidateData) {
  try {
    const sheet = getSheet_(SHEET_CANDIDATES);
```

**REPLACE WITH:**
```js
function api_createCandidate(candidateData) {
  const auth = requireRole_(['Admin', 'HR']);
  if (!auth.authorized) return { success: false, error: auth.error };
  try {
    const sheet = getSheet_(SHEET_CANDIDATES);
```

---

### Block C — Guard `api_updateCandidateDetails` (Admin, HR, Coordinator)

**FIND** (exact match):
```js
function api_updateCandidateDetails(candidateId, updates) {
  try {
    const sheet = getSheet_(SHEET_CANDIDATES);
```

**REPLACE WITH:**
```js
function api_updateCandidateDetails(candidateId, updates) {
  const auth = requireRole_(['Admin', 'HR', 'Coordinator']);
  if (!auth.authorized) return { success: false, error: auth.error };
  try {
    const sheet = getSheet_(SHEET_CANDIDATES);
```

---

### Block D — Guard `api_updateCandidateStatus` (Admin, HR, Coordinator)

**FIND** (exact match — first two lines of the function after Prompt 1):
```js
function api_updateCandidateStatus(candidateId, newStatus) {
  const ALLOWED_STATUSES = new Set([
```

**REPLACE WITH:**
```js
function api_updateCandidateStatus(candidateId, newStatus) {
  const auth = requireRole_(['Admin', 'HR', 'Coordinator']);
  if (!auth.authorized) return { success: false, error: auth.error };
  const ALLOWED_STATUSES = new Set([
```

---

### Block E — Guard `api_getAuditLog` (Admin, HR only — sensitive data)

**FIND** (exact match):
```js
function api_getAuditLog(candidateId) {
  try {
    const sheet = getSheet_(SHEET_LOGS);
```

**REPLACE WITH:**
```js
function api_getAuditLog(candidateId) {
  const auth = requireRole_(['Admin', 'HR']);
  if (!auth.authorized) return { success: false, error: auth.error };
  try {
    const sheet = getSheet_(SHEET_LOGS);
```

---

## CHANGE 2 — `DriveManager.js`: Add role guards (2 blocks)

### Block A — Guard `api_createCandidateFolder` (Admin, HR only)

**FIND** (exact match):
```js
function api_createCandidateFolder(candidateId, fullName) {
  try {
    const root = getRootFolder_();
```

**REPLACE WITH:**
```js
function api_createCandidateFolder(candidateId, fullName) {
  const auth = requireRole_(['Admin', 'HR']);
  if (!auth.authorized) return { success: false, error: auth.error };
  try {
    const root = getRootFolder_();
```

---

### Block B — Guard `api_uploadFileToDrive` (Admin, HR, Coordinator)

**FIND** (exact match — first two lines of the function after Prompt 1):
```js
function api_uploadFileToDrive(candidateId, folderId, docType, fileName, base64Data, mimeType) {
  // ── Server-side validation (never trust the client) ──────────────────
```

**REPLACE WITH:**
```js
function api_uploadFileToDrive(candidateId, folderId, docType, fileName, base64Data, mimeType) {
  const auth = requireRole_(['Admin', 'HR', 'Coordinator']);
  if (!auth.authorized) return { success: false, error: auth.error };
  // ── Server-side validation (never trust the client) ──────────────────
```

---

## CHANGE 3 — `appsscript.json`: Restrict web app access to org domain

**FIND** (exact match — entire file):
```json
{
  "timeZone": "Africa/Cairo",
  "dependencies": {},
  "exceptionLogging": "STACKDRIVER",
  "runtimeVersion": "V8",
  "webapp": {
    "executeAs": "USER_DEPLOYING",
    "access": "ANYONE"
  }
}
```

**REPLACE WITH:**
```json
{
  "timeZone": "Africa/Cairo",
  "dependencies": {},
  "exceptionLogging": "STACKDRIVER",
  "runtimeVersion": "V8",
  "webapp": {
    "executeAs": "USER_DEPLOYING",
    "access": "DOMAIN"
  }
}
```

> **⚠️ Note:** `"DOMAIN"` restricts the web app to users inside your
> Google Workspace organization. If your org does NOT use Google Workspace,
> keep `"ANYONE"` here — the role checks in code are still the primary
> security layer. `"DOMAIN"` is defense-in-depth, not a replacement.

---

## CHANGE 4 — `Tests.js`: Seed admin user + add auth rejection test (2 blocks)

### Block A — Seed `tbl_Users` with the mock admin user in `_seedAllSheets`

> **Why this is critical:** after Change 1, every guarded function checks
> `tbl_Users` for the current user's role. The mock user email is
> `test.user@yourcompany.com`. Without a matching row in the seed, every
> existing test that calls a guarded function will fail with "Access denied".

**FIND** (exact match — inside `_seedAllSheets()`):
```js
  MockFactory.seedSheet(SHEET_USERS, USER_HEADERS, []);
```

**REPLACE WITH:**
```js
  MockFactory.seedSheet(SHEET_USERS, USER_HEADERS, [
    ['user-001', 'test.user@yourcompany.com', 'Admin', 'Test Admin']
  ]);
```

---

### Block B — Add auth rejection test to `suite_Database_Candidates`

**FIND** (exact match — the last test in `suite_Database_Candidates`, including the closing brace):
```js
  TestRunner.run('api_updateCandidateStatus updates the UpdatedAt timestamp', () => {
    _seedAllSheets();
    const before = MockFactory._sheets[SHEET_CANDIDATES]._data[1][11]; // UpdatedAt column (index 11)
    api_updateCandidateStatus('cand-001', 'Mobilized');
    const after  = MockFactory._sheets[SHEET_CANDIDATES]._data[1][11];
    // Timestamps should be different (unless tests run at exactly the same millisecond)
    // At minimum, the field should have a value after the update
    Assert.notNull(after, 'UpdatedAt should be set after status update');
  });
}
```

**REPLACE WITH:**
```js
  TestRunner.run('api_updateCandidateStatus updates the UpdatedAt timestamp', () => {
    _seedAllSheets();
    const before = MockFactory._sheets[SHEET_CANDIDATES]._data[1][11]; // UpdatedAt column (index 11)
    api_updateCandidateStatus('cand-001', 'Mobilized');
    const after  = MockFactory._sheets[SHEET_CANDIDATES]._data[1][11];
    // Timestamps should be different (unless tests run at exactly the same millisecond)
    // At minimum, the field should have a value after the update
    Assert.notNull(after, 'UpdatedAt should be set after status update');
  });

  TestRunner.run('api_createCandidate is rejected for unregistered user', () => {
    // Seed with empty tbl_Users — no user has a role
    MockFactory.reset();
    MockFactory.seedSheet(SHEET_CANDIDATES, CANDIDATE_HEADERS, []);
    MockFactory.seedSheet(SHEET_DOCUMENTS,  DOCUMENT_HEADERS,  []);
    MockFactory.seedSheet(SHEET_LOGS,       LOG_HEADERS,       []);
    MockFactory.seedSheet(SHEET_USERS,      USER_HEADERS,      []); // empty — no registered users

    const result = api_createCandidate({
      fullName: 'Ghost User', position: 'Tester', department: 'QA',
      email: 'ghost@test.com', phone: '+0', nationality: 'Unknown',
      salary: '0', coordinatorEmail: 'coord@company.com'
    });

    Assert.isFalse(result.success, 'unregistered user should be denied');
    Assert.notNull(result.error,   'error message should explain the denial');
  });

  TestRunner.run('api_updateCandidateStatus is rejected for Viewer role', () => {
    MockFactory.reset();
    MockFactory.seedSheet(SHEET_CANDIDATES, CANDIDATE_HEADERS, [
      ['cand-001', 'Ahmed Ali', 'Engineer', 'Projects', 'ahmed@test.com',
       '+201012345678', 'Egyptian', '350', 'coord@company.com',
       'Documents Requested', '2026-01-01T00:00:00.000Z', '2026-01-01T00:00:00.000Z', '']
    ]);
    MockFactory.seedSheet(SHEET_DOCUMENTS, DOCUMENT_HEADERS, []);
    MockFactory.seedSheet(SHEET_LOGS,      LOG_HEADERS,      []);
    // Seed the mock user as Viewer — not allowed to change status
    MockFactory.seedSheet(SHEET_USERS, USER_HEADERS, [
      ['user-002', 'test.user@yourcompany.com', 'Viewer', 'Read Only User']
    ]);

    const result = api_updateCandidateStatus('cand-001', 'Mobilized');
    Assert.isFalse(result.success, 'Viewer role should be denied status change');
    Assert.notNull(result.error,   'error message should explain the denial');
  });
}
```

---

## MANDATORY OUTPUT FORMAT

Output exactly **4 code blocks** in this order — nothing else:

1. ` ```js ` — All 5 Database.js blocks (A through E) in sequence (Change 1)
2. ` ```js ` — Both DriveManager.js blocks (A and B) in sequence (Change 2)
3. ` ```json ` — Updated `appsscript.json` (Change 3)
4. ` ```js ` — Both Tests.js blocks (A and B) in sequence (Change 4)

---

## ROLE PERMISSION MATRIX

| Function | Admin | HR | Coordinator | Viewer |
|---|:---:|:---:|:---:|:---:|
| `api_getAllCandidates` | ✅ | ✅ | ✅ | ✅ |
| `api_getAllDocuments` | ✅ | ✅ | ✅ | ✅ |
| `api_getDocumentsByCandidate` | ✅ | ✅ | ✅ | ✅ |
| `api_getDashboardData` | ✅ | ✅ | ✅ | ✅ |
| `api_updateCandidateStatus` | ✅ | ✅ | ✅ | ❌ |
| `api_updateCandidateDetails` | ✅ | ✅ | ✅ | ❌ |
| `api_uploadFileToDrive` | ✅ | ✅ | ✅ | ❌ |
| `api_createCandidate` | ✅ | ✅ | ❌ | ❌ |
| `api_createCandidateFolder` | ✅ | ✅ | ❌ | ❌ |
| `api_getAuditLog` | ✅ | ✅ | ❌ | ❌ |

---

## RISK TABLE

| # | File | Risk |
|---|------|------|
| 1 | `Database.js` | 🟡 All guarded functions now require a row in `tbl_Users` — populate the sheet before going live |
| 2 | `DriveManager.js` | 🟡 Same as above — same `tbl_Users` dependency |
| 3 | `appsscript.json` | 🟠 `"DOMAIN"` blocks non-Workspace Google accounts — read the note before deploying |
| 4 | `Tests.js` | 🟢 Test-only — the admin seed in Block A is the critical fix that keeps all existing tests passing |

---

## ⚠️ GO-LIVE CHECKLIST (before deploying)

1. Open the live Google Sheet → `tbl_Users` tab
2. Add a row for every HR team member with their Google account email and role
3. Verify `SPREADSHEET_ID` and `BACKUP_FOLDER_ID` are set in Script Properties (from Prompt 1)
4. Re-deploy the web app in GAS → **New deployment** (changes to `appsscript.json`
   require a new deployment to take effect — editing an existing deployment does NOT update the access setting)