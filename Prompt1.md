# PROMPT — Fix Test Suite (Tests.js + ProductionTest.js)

## ⚠️ PREREQUISITE
Prompt 1 (Quick Wins) MUST be applied before this prompt.
The changes here depend on the status whitelist and MIME validation added there.

## ⚠️ CRITICAL RULES
- Apply ALL 7 changes below in order.
- Output **7 separate code blocks**, one per change, nothing else.
- Do NOT touch `Database.js`, `DriveManager.js`, `BackupService.js`, `Code.js`, or any HTML file.
- Only `Tests.js` and `ProductionTest.js` are modified.

---

## CONTEXT

Two issues introduced by Prompt 1 now break the test suite:
1. The status whitelist rejects `'Documents Received'` (not a real status).
2. The MIME type whitelist rejects `'text/plain'` in the production test.

Three pre-existing issues also need fixing:
3. `api_uploadDocumentToDrive` does not exist — the real function is `api_uploadFileToDrive`.
4. `api_reviewDocument` does not exist yet (it will be built in Prompt 3) — skip those tests.
5. Dashboard KPI assertions use hardcoded numbers that never matched the seeded data.

---

## CHANGE 1 — `Tests.js`: Fix wrong function name `api_uploadDocumentToDrive`

**FIND** (exact match — inside `suite_Code()`):
```js
  TestRunner.run('api_uploadDocumentToDrive returns success with a file URL', () => {
    const result = api_uploadDocumentToDrive('cand-001', 'Passport', 'passport.pdf', 'base64string==');
    Assert.isTrue(result.success, 'success should be true');
    Assert.notNull(result.fileUrl, 'fileUrl should not be null');
    Assert.isTrue(result.fileUrl.startsWith('https://'), 'fileUrl should start with https://');
  });
```

**REPLACE WITH:**
```js
  TestRunner.run('api_uploadFileToDrive returns success with a file URL', () => {
    _seedAllSheets();
    // Create a folder first to get a valid folderId
    const folderResult = api_createCandidateFolder('cand-001', 'Ahmed Ali');
    Assert.isTrue(folderResult.success, 'folder creation must succeed before upload');

    const result = api_uploadFileToDrive(
      'cand-001',
      folderResult.folderId,
      'Passport',
      'passport.pdf',
      'bW9ja2Jhc2U2NGRhdGE=', // valid mock base64
      'application/pdf'
    );
    Assert.isTrue(result.success, 'success should be true');
    Assert.notNull(result.fileUrl, 'fileUrl should not be null');
    Assert.isTrue(result.fileUrl.startsWith('https://'), 'fileUrl should start with https://');
  });
```

---

## CHANGE 2 — `Tests.js`: Fix KPI assertions to match actual seeded data

**FIND** (exact match — inside `suite_Code()`):
```js
  TestRunner.run('api_getDashboardData returns correct KPI values', () => {
    const result = api_getDashboardData();
    Assert.equals(result.data.activeCount, 24, 'activeCount should be 24');
    Assert.equals(result.data.missingDocs, 12, 'missingDocs should be 12');
    Assert.equals(result.data.pendingValidation, 5, 'pendingValidation should be 5');
  });
```

**REPLACE WITH:**
```js
  TestRunner.run('api_getDashboardData returns correct KPI values for seeded data', () => {
    // Seed 1 candidate with status 'Documents Requested' (see _seedAllSheets)
    // activeCount  = 1 (all non-Closed)
    // missingDocs  = 1 ('Documents Requested' is in MISSING_DOC_STATUSES)
    const result = api_getDashboardData();
    Assert.equals(result.data.activeCount, 1, 'activeCount should be 1 for the single seeded candidate');
    Assert.equals(result.data.missingDocs,  1, 'missingDocs should be 1 for the seeded candidate');
    Assert.isTrue(typeof result.data.visaPending === 'number',   'visaPending should be a number');
    Assert.isTrue(typeof result.data.visaCompleted === 'number', 'visaCompleted should be a number');
    Assert.isTrue(typeof result.data.mobilized === 'number',     'mobilized should be a number');
  });
```

---

## CHANGE 3 — `Tests.js`: Fix invalid status `'Documents Received'` in status-update test

**FIND** (exact match — inside `suite_Database_Candidates()`):
```js
  TestRunner.run('api_updateCandidateStatus updates status for existing candidate', () => {
    _seedAllSheets();
    const result = api_updateCandidateStatus('cand-001', 'Documents Received');
    Assert.isTrue(result.success, 'success should be true');

    const allResult = api_getAllCandidates();
    Assert.equals(allResult.data[0].CurrentStatus, 'Documents Received', 'status should be updated');
  });
```

**REPLACE WITH:**
```js
  TestRunner.run('api_updateCandidateStatus updates status for existing candidate', () => {
    _seedAllSheets();
    // Use a status that is in the server-side whitelist
    const result = api_updateCandidateStatus('cand-001', 'Documents Under Preparing');
    Assert.isTrue(result.success, 'success should be true');

    const allResult = api_getAllCandidates();
    Assert.equals(allResult.data[0].CurrentStatus, 'Documents Under Preparing', 'status should be updated');
  });
```

---

## CHANGE 4 — `Tests.js`: Skip `api_reviewDocument` tests (function not built yet)

**FIND** (exact match — the entire `api_reviewDocument` approves test block):
```js
  TestRunner.run('api_reviewDocument approves document and records actor', () => {
    _seedAllSheets();
    const result = api_reviewDocument('doc-001', 'Approved', '');
    Assert.isTrue(result.success, 'success should be true');

    // Verify status was updated in the sheet
    const docRows = MockFactory._sheets[SHEET_DOCUMENTS]._data.slice(1);
    const docRow  = docRows.find(r => r[0] === 'doc-001');
    Assert.notNull(docRow, 'document row should exist');
    Assert.equals(docRow[6], 'Approved', 'ApprovalStatus column should be Approved');
    Assert.equals(docRow[7], 'test.user@yourcompany.com', 'ApprovedBy should be set to current user');
  });

  TestRunner.run('api_reviewDocument rejects document and sets remarks', () => {
    _seedAllSheets();
    const result = api_reviewDocument('doc-001', 'Rejected', 'Photo is blurry, please re-upload.');
    Assert.isTrue(result.success, 'success should be true');

    const docRows = MockFactory._sheets[SHEET_DOCUMENTS]._data.slice(1);
    const docRow  = docRows.find(r => r[0] === 'doc-001');
    Assert.equals(docRow[6], 'Rejected', 'ApprovalStatus should be Rejected');
    Assert.equals(docRow[9], 'Photo is blurry, please re-upload.', 'Remarks should be set');
  });

  TestRunner.run('api_reviewDocument returns error for unknown documentId', () => {
    _seedAllSheets();
    const result = api_reviewDocument('no-such-doc', 'Approved', '');
    Assert.isFalse(result.success, 'success should be false for unknown doc ID');
    Assert.notNull(result.error, 'error should be present');
  });

  TestRunner.run('api_reviewDocument writes audit log entry', () => {
    _seedAllSheets();
    const logsBefore = MockFactory._sheets[SHEET_LOGS]._data.length;
    api_reviewDocument('doc-001', 'Approved', '');
    const logsAfter  = MockFactory._sheets[SHEET_LOGS]._data.length;
    Assert.isTrue(logsAfter > logsBefore, 'audit log should grow after document review');
  });
```

**REPLACE WITH:**
```js
  // ── api_reviewDocument tests ──────────────────────────────────────────────
  // TODO (Prompt 3): These tests are disabled until api_reviewDocument is built
  //                  in Database.js. Re-enable them after applying Prompt 3.
  // ─────────────────────────────────────────────────────────────────────────

  TestRunner.run('[PENDING Prompt 3] api_reviewDocument — tests skipped until backend function is built', () => {
    // Intentionally left empty — will be filled in when Prompt 3 is applied.
    Assert.isTrue(true, 'placeholder always passes');
  });
```

---

## CHANGE 5 — `Tests.js`: Fix `suite_Database_AuditLog` — invalid status + missing function

**FIND** (exact match — inside `suite_Database_AuditLog()`):
```js
  TestRunner.run('api_getAuditLog accumulates entries over multiple actions', () => {
    _seedAllSheets();
    // Perform two actions that each write a log entry
    api_updateCandidateStatus('cand-001', 'Documents Received');
    api_reviewDocument('doc-001', 'Approved', '');

    const result = api_getAuditLog('cand-001');
    Assert.isTrue(result.data.length >= 3, 'should have at least 3 log entries (1 seed + 2 actions)');
  });
```

**REPLACE WITH:**
```js
  TestRunner.run('api_getAuditLog accumulates entries over multiple actions', () => {
    _seedAllSheets();
    // Perform two status changes that each write a log entry (api_reviewDocument pending Prompt 3)
    api_updateCandidateStatus('cand-001', 'Documents Under Preparing');
    api_updateCandidateStatus('cand-001', 'Pending Passport');

    const result = api_getAuditLog('cand-001');
    Assert.isTrue(result.data.length >= 3, 'should have at least 3 log entries (1 seed + 2 status changes)');
  });
```

---

## CHANGE 6 — `ProductionTest.js`: Fix rejected MIME type `'text/plain'` in Step 3

**FIND** (exact match — inside `runProductionTest()`):
```js
  const uploadResult = api_uploadFileToDrive(
    candidateId,
    folderResult.folderId,
    'TestDocument',
    'integration_test.txt',
    sampleBase64,
    'text/plain'
  );
```

**REPLACE WITH:**
```js
  const uploadResult = api_uploadFileToDrive(
    candidateId,
    folderResult.folderId,
    'TestDocument',
    'integration_test.pdf',  // renamed to .pdf to match allowed MIME type
    sampleBase64,
    'application/pdf'         // 'text/plain' is blocked by server-side validation (Prompt 1)
  );
```

---

## CHANGE 7 — `ProductionTest.js`: Enhance `cleanupProductionTest` to delete Drive + Documents

**FIND** (entire `cleanupProductionTest` function — exact match):
```js
function cleanupProductionTest(candidateId) {
  if (!candidateId) {
    Logger.log('⚠️  Provide a candidateId to clean up. Example: cleanupProductionTest("mock-uuid-abc123")');
    return;
  }

  const sheet = getSheet_(SHEET_CANDIDATES);
  const data  = sheet.getDataRange().getValues();
  const idCol = data[0].indexOf('CandidateID');

  for (let i = 1; i < data.length; i++) {
    if (data[i][idCol] === candidateId) {
      sheet.deleteRow(i + 1);
      Logger.log('✅ Test candidate row deleted: ' + candidateId);
      return;
    }
  }
  Logger.log('⚠️  Candidate not found: ' + candidateId);
}
```

**REPLACE WITH:**
```js
/**
 * Full cleanup after runProductionTest().
 * Deletes: Candidate row, all Document rows, all Log rows, and the Drive folder.
 * Pass the candidateId printed in the SUMMARY section of the test log.
 *
 * Example: cleanupProductionTest("mock-uuid-abc123")
 */
function cleanupProductionTest(candidateId) {
  if (!candidateId) {
    Logger.log('⚠️  Provide a candidateId to clean up. Example: cleanupProductionTest("mock-uuid-abc123")');
    return;
  }

  Logger.log('🧹 Starting cleanup for candidateId: ' + candidateId);
  let errors = [];

  // ── 1. Delete Drive folder ────────────────────────────────────────────────
  try {
    const candSheet  = getSheet_(SHEET_CANDIDATES);
    const candData   = candSheet.getDataRange().getValues();
    const candIdCol  = candData[0].indexOf('CandidateID');
    const folderCol  = candData[0].indexOf('DriveFolderID');

    const candRow = candData.find((row, i) => i > 0 && row[candIdCol] === candidateId);
    if (candRow && candRow[folderCol]) {
      const folderId = candRow[folderCol];
      try {
        DriveApp.getFolderById(folderId).setTrashed(true);
        Logger.log('✅ Drive folder trashed: ' + folderId);
      } catch (e) {
        errors.push('Drive folder: ' + e.message);
        Logger.log('⚠️  Could not trash Drive folder: ' + e.message);
      }
    } else {
      Logger.log('ℹ️  No Drive folder found for this candidate (already deleted or never created).');
    }
  } catch (e) {
    errors.push('Drive lookup: ' + e.message);
  }

  // ── 2. Delete Candidate row ───────────────────────────────────────────────
  try {
    const sheet = getSheet_(SHEET_CANDIDATES);
    const data  = sheet.getDataRange().getValues();
    const idCol = data[0].indexOf('CandidateID');
    let deleted = false;
    for (let i = data.length - 1; i >= 1; i--) {
      if (data[i][idCol] === candidateId) {
        sheet.deleteRow(i + 1);
        Logger.log('✅ Candidate row deleted.');
        deleted = true;
        break;
      }
    }
    if (!deleted) Logger.log('ℹ️  Candidate row not found (already deleted?).');
  } catch (e) {
    errors.push('Candidate delete: ' + e.message);
  }

  // ── 3. Delete all Document rows for this candidate ────────────────────────
  try {
    const sheet = getSheet_(SHEET_DOCUMENTS);
    const data  = sheet.getDataRange().getValues();
    const idCol = data[0].indexOf('CandidateID');
    let count   = 0;
    // Iterate bottom-up to avoid row-index drift after deletion
    for (let i = data.length - 1; i >= 1; i--) {
      if (data[i][idCol] === candidateId) {
        sheet.deleteRow(i + 1);
        count++;
      }
    }
    Logger.log('✅ Deleted ' + count + ' document record(s).');
  } catch (e) {
    errors.push('Documents delete: ' + e.message);
  }

  // ── 4. Delete all Audit Log rows for this candidate ───────────────────────
  try {
    const sheet = getSheet_(SHEET_LOGS);
    const data  = sheet.getDataRange().getValues();
    const idCol = data[0].indexOf('CandidateID');
    let count   = 0;
    for (let i = data.length - 1; i >= 1; i--) {
      if (data[i][idCol] === candidateId) {
        sheet.deleteRow(i + 1);
        count++;
      }
    }
    Logger.log('✅ Deleted ' + count + ' audit log entry/entries.');
  } catch (e) {
    errors.push('Log delete: ' + e.message);
  }

  // ── Summary ───────────────────────────────────────────────────────────────
  if (errors.length === 0) {
    Logger.log('\n✅ Cleanup complete — all test data removed.');
  } else {
    Logger.log('\n⚠️  Cleanup finished with ' + errors.length + ' error(s):');
    errors.forEach(err => Logger.log('   • ' + err));
  }
}
```

---

## MANDATORY OUTPUT FORMAT

Output exactly **7 code blocks** in this order — nothing else:

1. ` ```js ` — `api_uploadFileToDrive` test fix (Change 1)
2. ` ```js ` — KPI assertions fix (Change 2)
3. ` ```js ` — Invalid status `'Documents Received'` fix (Change 3)
4. ` ```js ` — Skip `api_reviewDocument` tests (Change 4)
5. ` ```js ` — `suite_Database_AuditLog` fix (Change 5)
6. ` ```js ` — MIME type fix in ProductionTest (Change 6)
7. ` ```js ` — Full `cleanupProductionTest` replacement (Change 7)

---

## RISK TABLE

| # | File | Risk |
|---|------|------|
| 1 | `Tests.js` | 🟢 Test-only — zero production impact |
| 2 | `Tests.js` | 🟢 Test-only — zero production impact |
| 3 | `Tests.js` | 🟢 Test-only — zero production impact |
| 4 | `Tests.js` | 🟢 Tests skipped with placeholder, won't crash `runAllTests()` |
| 5 | `Tests.js` | 🟢 Test-only — zero production impact |
| 6 | `ProductionTest.js` | 🟢 Only affects manual integration test runs |
| 7 | `ProductionTest.js` | 🟡 Cleanup now deletes more data — only run with a test `candidateId` |

**Zero changes to production code. Only test files are modified.**