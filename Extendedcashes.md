# TASK: Extend caching to Candidates / Documents / Events (fix 3-4s load on every page)

## Context — why pages feel slow
`Performance_Enhancement.md` already added long-lived caching + event-based
invalidation, but **only for the Dashboard** (`api_getDashboardData`).
Every other page still re-reads the full Google Sheet from scratch on
every single visit:

- Candidates page → `api_getAllCandidates` (full sheet read every time)
- Calendar page → `api_getAllUpcomingEvents` (full sheet read every time)
- Candidate detail page → `api_getEventsByCandidate` + `api_getDocumentsByCandidate`
  (full sheet read every time)

That's the 3-4 second delay: Google Sheets reads inside Apps Script are the
slowest part of every request, and none of these are cached yet.

## About "cache forever"
Google Apps Script's `CacheService` has a **hard maximum TTL of 21600
seconds (6 hours)** — it is not technically possible to cache literally
forever. This prompt uses the maximum allowed TTL (6 hours) as a safety-net
expiration, combined with the same **event-based invalidation** pattern
already used for the dashboard: the moment any relevant data is created,
updated, or deleted, the matching cache key is deleted immediately — so in
practice, data is always fresh the instant it changes, and cached
otherwise. This is the same architecture as `Performance_Enhancement.md`,
just extended to the other pages.

---

## CHANGE 1 — `Database.js`: cache `api_getAllCandidates`, `api_getDocumentsByCandidate`, `api_getAllDocuments`

### Block A — Cache `api_getAllCandidates`

**FIND** (exact match):
```js
function api_getAllCandidates() {
  try {
    const sheet = getSheet_(SHEET_CANDIDATES);
    const [headers, ...rows] = sheet.getDataRange().getValues();
    const candidates = rows.map(row => {
      const obj = {};
      headers.forEach((h, i) => obj[h] = row[i]);
      return obj;
    });
    return { success: true, data: candidates };
  } catch (e) {
    Logger.log(e);
    return { success: false, error: e.message };
  }
}
```

**REPLACE WITH:**
```js
function api_getAllCandidates() {
  try {
    // [CACHE POLICY] Read-through cache — see ExtendedCaching.md policy notes.
    const _cache = CacheService.getScriptCache();
    const _cached = _cache.get('all_candidates');
    if (_cached) return JSON.parse(_cached);

    const sheet = getSheet_(SHEET_CANDIDATES);
    const [headers, ...rows] = sheet.getDataRange().getValues();
    const candidates = rows.map(row => {
      const obj = {};
      headers.forEach((h, i) => obj[h] = row[i]);
      return obj;
    });
    const result = { success: true, data: candidates };
    try { _cache.put('all_candidates', JSON.stringify(result), 21600); } catch (_) {}
    return result;
  } catch (e) {
    Logger.log(e);
    return { success: false, error: e.message };
  }
}
```

### Block B — Invalidate `all_candidates` on create

**FIND** (exact match):
```js
    api_writeLog_(id, 'SYSTEM', 'Candidate Created: ' + candidateData.fullName);
    // [CACHE POLICY] Write operation — invalidate dashboard cache immediately
    CacheService.getScriptCache().remove('dashboard_data');
    return { success: true, candidateId: id };
```

**REPLACE WITH:**
```js
    api_writeLog_(id, 'SYSTEM', 'Candidate Created: ' + candidateData.fullName);
    // [CACHE POLICY] Write operation — invalidate affected caches immediately
    CacheService.getScriptCache().remove('dashboard_data');
    CacheService.getScriptCache().remove('all_candidates');
    return { success: true, candidateId: id };
```

### Block C — Invalidate `all_candidates` on profile update

**FIND** (exact match):
```js
        api_writeLog_(candidateId, Session.getActiveUser().getEmail(), 'Profile Updated');
        // [CACHE POLICY] Write operation — invalidate dashboard cache immediately
        CacheService.getScriptCache().remove('dashboard_data');
        return { success: true };
```

**REPLACE WITH:**
```js
        api_writeLog_(candidateId, Session.getActiveUser().getEmail(), 'Profile Updated');
        // [CACHE POLICY] Write operation — invalidate affected caches immediately
        CacheService.getScriptCache().remove('dashboard_data');
        CacheService.getScriptCache().remove('all_candidates');
        return { success: true };
```

### Block D — Invalidate `all_candidates` on status change

**FIND** (exact match):
```js
        api_writeLog_(candidateId, Session.getActiveUser().getEmail(), 'Status Changed: ' + newStatus);
        // [CACHE POLICY] Write operation — invalidate dashboard cache immediately
        CacheService.getScriptCache().remove('dashboard_data');
        return { success: true };
```

**REPLACE WITH:**
```js
        api_writeLog_(candidateId, Session.getActiveUser().getEmail(), 'Status Changed: ' + newStatus);
        // [CACHE POLICY] Write operation — invalidate affected caches immediately
        CacheService.getScriptCache().remove('dashboard_data');
        CacheService.getScriptCache().remove('all_candidates');
        return { success: true };
```

### Block E — Cache `api_getDocumentsByCandidate`

**FIND** (exact match):
```js
function api_getDocumentsByCandidate(candidateId) {
  try {
    const sheet = getSheet_(SHEET_DOCUMENTS);
    const [headers, ...rows] = sheet.getDataRange().getValues();
    const documents = rows
      .filter(row => row[headers.indexOf('CandidateID')] === candidateId)
      .map(row => {
        const obj = {};
        headers.forEach((h, i) => obj[h] = row[i]);
        return obj;
      });
    return { success: true, data: documents };
  } catch (e) {
    Logger.log(e);
    return { success: false, error: e.message };
  }
}
```

**REPLACE WITH:**
```js
function api_getDocumentsByCandidate(candidateId) {
  try {
    // [CACHE POLICY] Read-through cache — see ExtendedCaching.md policy notes.
    const _cache = CacheService.getScriptCache();
    const _cacheKey = 'docs_' + candidateId;
    const _cached = _cache.get(_cacheKey);
    if (_cached) return JSON.parse(_cached);

    const sheet = getSheet_(SHEET_DOCUMENTS);
    const [headers, ...rows] = sheet.getDataRange().getValues();
    const documents = rows
      .filter(row => row[headers.indexOf('CandidateID')] === candidateId)
      .map(row => {
        const obj = {};
        headers.forEach((h, i) => obj[h] = row[i]);
        return obj;
      });
    const result = { success: true, data: documents };
    try { _cache.put(_cacheKey, JSON.stringify(result), 21600); } catch (_) {}
    return result;
  } catch (e) {
    Logger.log(e);
    return { success: false, error: e.message };
  }
}
```

### Block F — Cache `api_getAllDocuments`

**FIND** (exact match):
```js
function api_getAllDocuments() {
  try {
    const sheet = getSheet_(SHEET_DOCUMENTS);
    const [headers, ...rows] = sheet.getDataRange().getValues();
    const documents = rows.map(row => {
      const obj = {};
      headers.forEach((h, i) => obj[h] = row[i]);
      return obj;
    });
    return { success: true, data: documents };
  } catch (e) {
    Logger.log(e);
    return { success: false, error: e.message };
  }
}
```

**REPLACE WITH:**
```js
function api_getAllDocuments() {
  try {
    // [CACHE POLICY] Read-through cache — see ExtendedCaching.md policy notes.
    const _cache = CacheService.getScriptCache();
    const _cached = _cache.get('all_documents');
    if (_cached) return JSON.parse(_cached);

    const sheet = getSheet_(SHEET_DOCUMENTS);
    const [headers, ...rows] = sheet.getDataRange().getValues();
    const documents = rows.map(row => {
      const obj = {};
      headers.forEach((h, i) => obj[h] = row[i]);
      return obj;
    });
    const result = { success: true, data: documents };
    try { _cache.put('all_documents', JSON.stringify(result), 21600); } catch (_) {}
    return result;
  } catch (e) {
    Logger.log(e);
    return { success: false, error: e.message };
  }
}
```

---

## CHANGE 2 — `DriveManager.js`: invalidate document caches on upload

**FIND** (exact match — inside `api_uploadFileToDrive`, just before the return):
```js
    api_writeLog_(candidateId, Session.getActiveUser().getEmail(), 'Document Uploaded: ' + docType);
    // [CACHE POLICY] Write operation — invalidate dashboard cache immediately
    CacheService.getScriptCache().remove('dashboard_data');
    return { success: true, fileUrl: fileUrl, documentId: docId };
```

**REPLACE WITH:**
```js
    api_writeLog_(candidateId, Session.getActiveUser().getEmail(), 'Document Uploaded: ' + docType);
    // [CACHE POLICY] Write operation — invalidate affected caches immediately
    CacheService.getScriptCache().remove('dashboard_data');
    CacheService.getScriptCache().remove('all_documents');
    CacheService.getScriptCache().remove('docs_' + candidateId);
    return { success: true, fileUrl: fileUrl, documentId: docId };
```

---

## CHANGE 3 — `CalendarManager.js`: cache event reads + invalidate on every write

### Block A — Cache `api_getEventsByCandidate`

**FIND** (exact match):
```js
function api_getEventsByCandidate(candidateId) {
  try {
    const sheet = getEventsSheet_();
    const [headers, ...rows] = sheet.getDataRange().getValues();
    const phoneMap = getCandidatePhoneMap_();
    const events = rows
      .filter(row => row[headers.indexOf('CandidateID')] === candidateId)
      .map(row => {
        const obj = {};
        headers.forEach((h, i) => obj[h] = row[i]);
        obj.EventDate = normalizeEventDateString_(obj.EventDate);
        obj.CandidatePhone = phoneMap[obj.CandidateID] || '';
        return obj;
      })
      .sort((a, b) => new Date(a.EventDate) - new Date(b.EventDate));
      
    return { success: true, data: events };
  } catch (e) {
    Logger.log(e);
    return { success: false, error: e.message };
  }
}
```

**REPLACE WITH:**
```js
function api_getEventsByCandidate(candidateId) {
  try {
    // [CACHE POLICY] Read-through cache — see ExtendedCaching.md policy notes.
    const _cache = CacheService.getScriptCache();
    const _cacheKey = 'events_' + candidateId;
    const _cached = _cache.get(_cacheKey);
    if (_cached) return JSON.parse(_cached);

    const sheet = getEventsSheet_();
    const [headers, ...rows] = sheet.getDataRange().getValues();
    const phoneMap = getCandidatePhoneMap_();
    const events = rows
      .filter(row => row[headers.indexOf('CandidateID')] === candidateId)
      .map(row => {
        const obj = {};
        headers.forEach((h, i) => obj[h] = row[i]);
        obj.EventDate = normalizeEventDateString_(obj.EventDate);
        obj.CandidatePhone = phoneMap[obj.CandidateID] || '';
        return obj;
      })
      .sort((a, b) => new Date(a.EventDate) - new Date(b.EventDate));

    const result = { success: true, data: events };
    try { _cache.put(_cacheKey, JSON.stringify(result), 21600); } catch (_) {}
    return result;
  } catch (e) {
    Logger.log(e);
    return { success: false, error: e.message };
  }
}
```

### Block B — Cache `api_getAllUpcomingEvents`

**FIND** (exact match):
```js
function api_getAllUpcomingEvents() {
  try {
    const sheet = getEventsSheet_();
    const [headers, ...rows] = sheet.getDataRange().getValues();
    const phoneMap = getCandidatePhoneMap_();
    const events = rows
      .filter(row => row[headers.indexOf('Status')] === 'Active')
      .map(row => {
        const obj = {};
        headers.forEach((h, i) => obj[h] = row[i]);
        obj.EventDate = normalizeEventDateString_(obj.EventDate);
        obj.CandidatePhone = phoneMap[obj.CandidateID] || '';
        return obj;
      });
      
    return { success: true, data: events };
  } catch (e) {
    Logger.log(e);
    return { success: false, error: e.message };
  }
}
```

**REPLACE WITH:**
```js
function api_getAllUpcomingEvents() {
  try {
    // [CACHE POLICY] Read-through cache — see ExtendedCaching.md policy notes.
    const _cache = CacheService.getScriptCache();
    const _cached = _cache.get('all_upcoming_events');
    if (_cached) return JSON.parse(_cached);

    const sheet = getEventsSheet_();
    const [headers, ...rows] = sheet.getDataRange().getValues();
    const phoneMap = getCandidatePhoneMap_();
    const events = rows
      .filter(row => row[headers.indexOf('Status')] === 'Active')
      .map(row => {
        const obj = {};
        headers.forEach((h, i) => obj[h] = row[i]);
        obj.EventDate = normalizeEventDateString_(obj.EventDate);
        obj.CandidatePhone = phoneMap[obj.CandidateID] || '';
        return obj;
      });

    const result = { success: true, data: events };
    try { _cache.put('all_upcoming_events', JSON.stringify(result), 21600); } catch (_) {}
    return result;
  } catch (e) {
    Logger.log(e);
    return { success: false, error: e.message };
  }
}
```

### Block C — Invalidate event caches on create

**FIND** (exact match):
```js
    api_writeLog_(candidateId, currentUser, 'Calendar Event Created: ' + eventData.title);
    CacheService.getScriptCache().remove('dashboard_data');

    return { success: true, eventId, calendarEventId: calEvent.getId(), calendarLink: eventLink };
```

**REPLACE WITH:**
```js
    api_writeLog_(candidateId, currentUser, 'Calendar Event Created: ' + eventData.title);
    // [CACHE POLICY] Write operation — invalidate affected caches immediately
    CacheService.getScriptCache().remove('dashboard_data');
    CacheService.getScriptCache().remove('all_upcoming_events');
    CacheService.getScriptCache().remove('events_' + candidateId);

    return { success: true, eventId, calendarEventId: calEvent.getId(), calendarLink: eventLink };
```

### Block D — Invalidate event caches on update

**FIND** (exact match):
```js
    api_writeLog_(rowData[headers.indexOf('CandidateID')], Session.getActiveUser().getEmail(), 'Calendar Event Updated: ' + titleToLog);
    CacheService.getScriptCache().remove('dashboard_data');

    return { success: true, warning: warning };
```

**REPLACE WITH:**
```js
    api_writeLog_(rowData[headers.indexOf('CandidateID')], Session.getActiveUser().getEmail(), 'Calendar Event Updated: ' + titleToLog);
    // [CACHE POLICY] Write operation — invalidate affected caches immediately
    CacheService.getScriptCache().remove('dashboard_data');
    CacheService.getScriptCache().remove('all_upcoming_events');
    CacheService.getScriptCache().remove('events_' + rowData[headers.indexOf('CandidateID')]);

    return { success: true, warning: warning };
```

### Block E — Invalidate event caches on delete/cancel

**FIND** (exact match):
```js
    api_writeLog_(rowData[headers.indexOf('CandidateID')], Session.getActiveUser().getEmail(), 'Calendar Event Cancelled: ' + rowData[headers.indexOf('Title')]);
    CacheService.getScriptCache().remove('dashboard_data');

    return { success: true };
  } catch (e) {
    Logger.log(e);
    return { success: false, error: e.message };
  }
}

/**
 * Marks an event as completed.
 */
```

**REPLACE WITH:**
```js
    api_writeLog_(rowData[headers.indexOf('CandidateID')], Session.getActiveUser().getEmail(), 'Calendar Event Cancelled: ' + rowData[headers.indexOf('Title')]);
    // [CACHE POLICY] Write operation — invalidate affected caches immediately
    CacheService.getScriptCache().remove('dashboard_data');
    CacheService.getScriptCache().remove('all_upcoming_events');
    CacheService.getScriptCache().remove('events_' + rowData[headers.indexOf('CandidateID')]);

    return { success: true };
  } catch (e) {
    Logger.log(e);
    return { success: false, error: e.message };
  }
}

/**
 * Marks an event as completed.
 */
```

### Block F — Invalidate event caches on mark-completed

**FIND** (exact match):
```js
    api_writeLog_(rowData[headers.indexOf('CandidateID')], Session.getActiveUser().getEmail(), 'Calendar Event Completed: ' + rowData[headers.indexOf('Title')]);
    CacheService.getScriptCache().remove('dashboard_data');

    return { success: true };
  } catch (e) {
    Logger.log(e);
    return { success: false, error: e.message };
  }
}
```

**REPLACE WITH:**
```js
    api_writeLog_(rowData[headers.indexOf('CandidateID')], Session.getActiveUser().getEmail(), 'Calendar Event Completed: ' + rowData[headers.indexOf('Title')]);
    // [CACHE POLICY] Write operation — invalidate affected caches immediately
    CacheService.getScriptCache().remove('dashboard_data');
    CacheService.getScriptCache().remove('all_upcoming_events');
    CacheService.getScriptCache().remove('events_' + rowData[headers.indexOf('CandidateID')]);

    return { success: true };
  } catch (e) {
    Logger.log(e);
    return { success: false, error: e.message };
  }
}
```

---

## MANDATORY OUTPUT FORMAT

Output exactly **3 code blocks**, nothing else:
1. ` ```js ` — All `Database.js` blocks (A–F) in sequence (Change 1)
2. ` ```js ` — The `DriveManager.js` block (Change 2)
3. ` ```js ` — All `CalendarManager.js` blocks (A–F) in sequence (Change 3)

Do not touch `Styles.html`, `Index.html`, `Script.html`, `Tests.js`, or
`TestUtils.js` in this task.

---

## EXPECTED IMPACT

| Page | Before | After |
|---|---|---|
| Candidates page (repeat visit) | Full sheet read every time | Served from cache — 0 Sheets reads until data changes |
| Calendar page (repeat visit) | Full sheet read every time | Served from cache — 0 Sheets reads until data changes |
| Candidate detail (repeat visit) | 2 full sheet reads every time | Served from cache — 0 Sheets reads until data changes |
| Any create/update/delete/status-change/upload | — | Instantly invalidates only the caches it affects — next load is always fresh |

## VERIFICATION
1. Redeploy as a new version, hard-refresh.
2. Visit Candidates page twice in a row — the second visit should feel
   noticeably faster.
3. Add/edit a candidate, then revisit Candidates page — confirm the
   change shows immediately (cache correctly invalidated, not stale).
4. Repeat the same check for the Calendar page (create/edit/complete an
   event) and a candidate's document list (upload a document).
