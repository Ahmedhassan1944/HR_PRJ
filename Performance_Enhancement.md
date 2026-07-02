# PROMPT — Performance: Spreadsheet Caching + Dashboard Cache + Drive Root Folder Cache

## ⚠️ PREREQUISITE
Prompt 1 (Quick Wins) MUST be applied before this prompt.

## ⚠️ CRITICAL RULES
- Apply ALL 4 changes in order.
- Each change contains FIND/REPLACE blocks labeled A, B, C…
- Output **4 code blocks**, one per change, nothing else.
- Do NOT touch `Styles.html`, `Index.html`, `Tests.js`, or `TestUtils.js`.

---

## WHY THESE CHANGES

Every API call today re-opens the spreadsheet from scratch and re-reads
entire tables into memory. This gets measurably slower with every new
candidate added. These changes fix the root causes:

1. **Spreadsheet object cache** — `SpreadsheetApp.openById()` is one of the
   most expensive Sheets API calls; it runs on every single `api_*` call
   right now. Caching the object for the lifetime of one execution removes
   redundant opens when multiple sub-functions are called within a single
   request (e.g., `api_getDashboardData` triggers it twice today).

2. **CacheService for the dashboard** — `api_getDashboardData` is the
   highest-traffic function (loaded on every page visit). It does two full
   table reads every time, even if nothing changed 10 seconds ago. A 60-
   second cache removes those reads for the common repeat-visit case.
   Cache is invalidated automatically whenever real data changes.

3. **Drive root folder ID cache** — `getRootFolder_()` does a Drive-wide
   search by folder name on every candidate folder creation. Drive name
   searches are noticeably slower than direct `getFolderById()` lookups.
   Storing the ID in `PropertiesService` (persists across executions) makes
   every subsequent folder creation a fast direct lookup.

4. **Global Cache Invalidation Policy** — formalizes the event-based
   invalidation architecture so every current and future write operation
   correctly removes the dashboard cache key.

---

## CHANGE 1 — `Database.js`: Spreadsheet cache + dashboard cache invalidation (4 blocks)

### Block A — Replace `getSheet_()` with a cached version

**FIND** (exact match):
```js
/**
 * Helper: Returns a specific sheet by name.
 */
function getSheet_(sheetName) {
  const ss = SpreadsheetApp.openById(SPREADSHEET_ID);
  const sheet = ss.getSheetByName(sheetName);
  if (!sheet) throw new Error('Sheet not found: ' + sheetName);
  return sheet;
}
```

**REPLACE WITH:**
```js
/**
 * Internal: Returns the opened Spreadsheet, cached for this execution.
 * SpreadsheetApp.openById() is expensive — calling it once per execution
 * and reusing the object cuts API overhead for every multi-step operation.
 * The cache is a module-level variable: it resets to null on every fresh
 * GAS execution (i.e., every new api_* call from the frontend), so there
 * is no risk of serving stale data across requests.
 */
let _ssCache = null;
function getSpreadsheet_() {
  if (!_ssCache) _ssCache = SpreadsheetApp.openById(SPREADSHEET_ID);
  return _ssCache;
}

/**
 * Helper: Returns a specific sheet by name.
 * Uses the cached Spreadsheet object — never opens by ID more than once
 * per execution regardless of how many sheets are accessed.
 */
function getSheet_(sheetName) {
  const sheet = getSpreadsheet_().getSheetByName(sheetName);
  if (!sheet) throw new Error('Sheet not found: ' + sheetName);
  return sheet;
}
```

---

### Block B — Invalidate dashboard cache when a candidate is created

**FIND** (exact match — inside `api_createCandidate`, just before the return):
```js
    api_writeLog_(id, 'SYSTEM', 'Candidate Created: ' + candidateData.fullName);
    return { success: true, candidateId: id };
```

**REPLACE WITH:**
```js
    api_writeLog_(id, 'SYSTEM', 'Candidate Created: ' + candidateData.fullName);
    // [CACHE POLICY] Write operation — invalidate dashboard cache immediately
    CacheService.getScriptCache().remove('dashboard_data');
    return { success: true, candidateId: id };
```

---

### Block C — Invalidate dashboard cache when candidate details are updated

**FIND** (exact match — inside `api_updateCandidateDetails`, just before its success return):
```js
        api_writeLog_(candidateId, Session.getActiveUser().getEmail(), 'Profile Updated');
        return { success: true };
```

**REPLACE WITH:**
```js
        api_writeLog_(candidateId, Session.getActiveUser().getEmail(), 'Profile Updated');
        // [CACHE POLICY] Write operation — invalidate dashboard cache immediately
        CacheService.getScriptCache().remove('dashboard_data');
        return { success: true };
```

---

### Block D — Invalidate dashboard cache when a status is updated

**FIND** (exact match — inside `api_updateCandidateStatus`, inside the loop):
```js
        api_writeLog_(candidateId, Session.getActiveUser().getEmail(), 'Status Changed: ' + newStatus);
        return { success: true };
```

**REPLACE WITH:**
```js
        api_writeLog_(candidateId, Session.getActiveUser().getEmail(), 'Status Changed: ' + newStatus);
        // [CACHE POLICY] Write operation — invalidate dashboard cache immediately
        CacheService.getScriptCache().remove('dashboard_data');
        return { success: true };
```

---

## CHANGE 2 — `Code.js`: Wrap `api_getDashboardData` with CacheService (3 blocks)

### Block A — Add cache read at the top of `api_getDashboardData`

**FIND** (exact match — entire function opening):
```js
function api_getDashboardData() {
  try {
    const candsRes = api_getAllCandidates();
    if (!candsRes.success) throw new Error(candsRes.error);
    const docsRes  = api_getAllDocuments();
    if (!docsRes.success) throw new Error(docsRes.error);
```

**REPLACE WITH:**
```js
function api_getDashboardData() {
  try {
    // ── Cache read ────────────────────────────────────────────────────
    // CacheService stores the computed result for 60 seconds (TTL = fallback).
    // Primary invalidation is EVENT-BASED: every write api_* function calls
    // CacheService.getScriptCache().remove('dashboard_data') before returning.
    // This means the cache is always fresh immediately after any data change.
    // See CHANGE 4 in this prompt for the full Cache Invalidation Policy.
    const _cache      = CacheService.getScriptCache();
    const _cachedJson = _cache.get('dashboard_data');
    if (_cachedJson) {
      return JSON.parse(_cachedJson);
    }
    // ─────────────────────────────────────────────────────────────────

    const candsRes = api_getAllCandidates();
    if (!candsRes.success) throw new Error(candsRes.error);
    const docsRes  = api_getAllDocuments();
    if (!docsRes.success) throw new Error(docsRes.error);
```

---

### Block B — Change `return {` to `const _result = {`

**FIND** (exact match — the return statement that opens the data object):
```js
    return {
      success: true,
      data: {
```

**REPLACE WITH:**
```js
    const _result = {
      success: true,
      data: {
```

---

### Block C — Add cache write + return `_result` at the end

**FIND** (exact match — closing of the data object + catch block):
```js
          msg: 'Live data successfully retrieved from Google Sheets.'
        }
      };
  } catch (e) {
    Logger.log(e);
    return { success: false, error: e.message };
  }
}
```

**REPLACE WITH:**
```js
          msg: 'Live data successfully retrieved from Google Sheets.'
        }
      };

    // ── Cache write ───────────────────────────────────────────────────
    // TTL = 60 seconds (fallback only). The cache is primarily invalidated
    // by event-based removal in every write api_* function — not by TTL.
    // If JSON.stringify exceeds 100KB, put() fails silently (try/catch).
    try { _cache.put('dashboard_data', JSON.stringify(_result), 60); } catch (_) {}
    // ─────────────────────────────────────────────────────────────────

    return _result;
  } catch (e) {
    Logger.log(e);
    return { success: false, error: e.message };
  }
}
```

---

## CHANGE 3 — `DriveManager.js`: Root folder ID cache + dashboard invalidation on upload (2 blocks)

### Block A — Replace `getRootFolder_()` with a PropertiesService-cached version

**FIND** (exact match — entire function):
```js
function getRootFolder_() {
  const folders = DriveApp.getFoldersByName(ROOT_FOLDER_NAME);
  if (folders.hasNext()) return folders.next();
  return DriveApp.createFolder(ROOT_FOLDER_NAME);
}
```

**REPLACE WITH:**
```js
/**
 * Gets or creates the root Drive folder, caching its ID in PropertiesService.
 * DriveApp.getFoldersByName() is a Drive-wide name search — noticeably
 * slower than a direct getFolderById() lookup. Storing the ID in
 * PropertiesService (which persists across GAS executions) means the
 * name-search only ever runs once: the very first time the folder is
 * accessed. Every subsequent call is a fast direct lookup.
 */
function getRootFolder_() {
  const props    = PropertiesService.getScriptProperties();
  const cachedId = props.getProperty('ROOT_FOLDER_ID');

  if (cachedId) {
    try {
      return DriveApp.getFolderById(cachedId);
    } catch (_) {
      // Cached ID is stale (folder was deleted/moved) — fall through to search
      props.deleteProperty('ROOT_FOLDER_ID');
    }
  }

  // First-time lookup: search by name, then persist the ID
  const folders = DriveApp.getFoldersByName(ROOT_FOLDER_NAME);
  const folder  = folders.hasNext()
    ? folders.next()
    : DriveApp.createFolder(ROOT_FOLDER_NAME);

  props.setProperty('ROOT_FOLDER_ID', folder.getId());
  return folder;
}
```

---

### Block B — Invalidate dashboard cache when a document is uploaded

**FIND** (exact match — inside `api_uploadFileToDrive`, just before the return):
```js
    api_writeLog_(candidateId, Session.getActiveUser().getEmail(), 'Document Uploaded: ' + docType);
    return { success: true, fileUrl: fileUrl, documentId: docId };
```

**REPLACE WITH:**
```js
    api_writeLog_(candidateId, Session.getActiveUser().getEmail(), 'Document Uploaded: ' + docType);
    // [CACHE POLICY] Write operation — invalidate dashboard cache immediately
    CacheService.getScriptCache().remove('dashboard_data');
    return { success: true, fileUrl: fileUrl, documentId: docId };
```

---

## CHANGE 4 — Global Cache Invalidation Policy (Architecture Rule)

This change documents the cache invalidation architecture in the codebase
and adds the invalidation line to any remaining write functions not covered
in Changes 1–3. Apply the two blocks below.

### THE RULE (read before applying the blocks)

The dashboard cache MUST **never** serve stale business data.
The 60-second TTL is only a **fallback** expiration mechanism.
The **primary** invalidation strategy is **Event-Based**: whenever any
backend function successfully modifies data that can affect Dashboard KPIs,
counters, or summaries, it MUST remove the cache key **immediately** before
returning success.

```
Dashboard Request
      ↓
  Read Cache ──── HIT ──────────────────→ Return Cached Data
      │
     MISS (or TTL expired)
      ↓
  Read Google Sheets
      ↓
  Build Dashboard
      ↓
  Save to Cache (TTL = 60s)
      ↓
  Return Fresh Data

  [Any write operation fires before TTL ends]
      ↓
  CacheService.getScriptCache().remove('dashboard_data')
      ↓
  Next dashboard request → generates fresh data → stores new cache
```

**Rule applies to ALL of these (current and future):**

| Function | Invalidates cache? |
|---|:---:|
| `api_createCandidate` | ✅ (Change 1B) |
| `api_updateCandidateDetails` | ✅ (Change 1C) |
| `api_updateCandidateStatus` | ✅ (Change 1D) |
| `api_uploadFileToDrive` | ✅ (Change 3B) |
| `api_reviewDocument` *(future)* | ✅ must add |
| `api_deleteCandidate` *(future)* | ✅ must add |
| `api_deleteDocument` *(future)* | ✅ must add |
| `api_archiveCandidate` *(future)* | ✅ must add |
| `api_restoreCandidate` *(future)* | ✅ must add |
| All read-only `api_get*` functions | ❌ MUST NOT invalidate |

---

### Block A — Add the policy comment block to `Code.js` (above `api_getDashboardData`)

**FIND** (exact match — the JSDoc comment that opens `api_getDashboardData`):
```js
/**
 * Fetches and aggregates ALL dashboard KPI data.
```

**REPLACE WITH:**
```js
// ═══════════════════════════════════════════════════════════════════════
// DASHBOARD CACHE — INVALIDATION POLICY (project architecture rule)
// ═══════════════════════════════════════════════════════════════════════
// Cache key : 'dashboard_data'
// TTL       : 60 seconds (FALLBACK ONLY — not the primary mechanism)
// Strategy  : EVENT-BASED invalidation
//
// Any backend function that inserts, updates, deletes, approves, rejects,
// archives, restores, or otherwise modifies data displayed on the Dashboard
// MUST add this line immediately before its success return:
//
//   CacheService.getScriptCache().remove('dashboard_data');
//
// Read-only api_get* functions MUST NOT call remove().
//
// Cache lifecycle:
//   Request → cache HIT  → return cached JSON (0 Sheets calls)
//   Request → cache MISS → read Sheets → compute → cache.put() → return
//   Write op fires       → cache.remove() → next request regenerates
// ═══════════════════════════════════════════════════════════════════════

/**
 * Fetches and aggregates ALL dashboard KPI data.
```

---

### Block B — Add invalidation to `BackupService.js → createDailyBackup` (defensive, not strictly needed today but correct by policy)

> `createDailyBackup` only copies the spreadsheet file — it does NOT modify
> candidate data or document records, so it does NOT affect Dashboard KPIs.
> **Skip this block.** `createDailyBackup` is correctly excluded from the
> invalidation policy. No changes needed in `BackupService.js`.

---

## MANDATORY OUTPUT FORMAT

Output exactly **4 code blocks** in this order — nothing else:

1. ` ```js ` — All 4 Database.js blocks (A, B, C, D) in sequence (Change 1)
2. ` ```js ` — All 3 Code.js blocks (A, B, C) in sequence (Change 2)
3. ` ```js ` — Both DriveManager.js blocks (A, B) in sequence (Change 3)
4. ` ```js ` — Both Code.js blocks from Change 4 (policy comment + skip note) (Change 4)

---

## EXPECTED IMPACT TABLE

| Scenario | Before | After |
|---|---|---|
| Dashboard load (repeat within 60s) | 2 full-table reads + 2 spreadsheet opens | Served from CacheService — **0 Sheets API calls** |
| Dashboard load (first visit / after any write) | 2 full-table reads + 2 spreadsheet opens | 2 full-table reads + **1 spreadsheet open** (cached) |
| Create candidate → folder → upload | ~5 `openById()` calls across sub-functions | **1 `openById()`** (cached for whole execution) |
| Create candidate folder (repeat) | Drive-wide name search every time | **Direct `getFolderById()`** — constant-time lookup |
| Status / details update | Dashboard may show stale KPIs | Cache auto-invalidated → **next load always fresh** |

---

## RISK TABLE

| # | File | Risk |
|---|------|------|
| 1A | `Database.js` | 🟢 `_ssCache` resets to `null` on every fresh GAS execution — no cross-request leakage |
| 1B–1D | `Database.js` | 🟢 `cache.remove()` is a no-op if key doesn't exist — always safe |
| 2 | `Code.js` | 🟡 If dashboard JSON ever exceeds 100KB, `cache.put()` silently fails (wrapped in try/catch — app still works, just uncached) |
| 3A | `DriveManager.js` | 🟢 `try/catch` on cached folder ID handles stale/deleted folder — falls back to name search automatically |
| 3B | `DriveManager.js` | 🟢 Same as 1B–1D |
| 4A | `Code.js` | 🟢 Documentation comment only — zero runtime impact |

**Zero changes to frontend HTML, CSS, or test files.**