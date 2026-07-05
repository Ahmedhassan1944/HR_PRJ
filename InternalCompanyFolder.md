# PROMPT — Feature: Internal Company Folder (Local Server Path)

## ⚠️ PREREQUISITES
- `Authorization.md` MUST already be applied (this prompt reuses `requireRole_`).
- `ExtendedCaching.md` MUST already be applied (this prompt reuses the
  `dashboard_data` cache-invalidation pattern already present in
  `api_updateCandidateDetails`).

## ⚠️ CRITICAL RULES
- This project is **Google Apps Script** — do NOT introduce any external
  framework, npm package, ActiveX, Electron, or browser extension.
- Follow the existing project architecture exactly:
  - Backend logic lives in `Database.js` (`api_*` functions using
    `getSheet_(SHEET_CANDIDATES)` + `headers.indexOf(...)`, never fixed
    column numbers for updates).
  - Frontend logic lives in `Script.html`, inside the `Views` object,
    using the existing `table-card` / `form-group` / `Modal.open()` /
    `Toast.success|warning|error()` patterns already used throughout.
- Do NOT touch `Styles.html`, `CalendarManager.js`, `DriveManager.js`,
  `BackupService.js`, `Index.html`, or `Tests.js`.
- Do NOT modify any unrelated functionality. Maintain full backward
  compatibility — older candidates with no `LocalServerPath` must keep
  working with zero errors.
- Output every changed function as a **complete FIND/REPLACE block** —
  nothing partial, nothing abbreviated with "...".

---

## CONTEXT

### Goal
Add an optional **"🖥 Internal Company Folder"** card to the Candidate
Details page, showing a local/network file-server path for that
candidate's physical folder (e.g. `\\FILESERVER\Candidates\CAND-00025`),
with **Open Folder** and **Copy Path** actions. This is best-effort only
— it does not bypass any browser or Windows security, it only stores and
attempts to open a path string.

### Database change required (do this manually first, in the Google Sheet)
Add a new column to `tbl_Candidates`, **as the very last column, after
`Notes`**:

```
Column name: LocalServerPath
```

Example values: `\\FILESERVER\Candidates\CAND-00025`,
`\\192.168.1.10\HR\Candidates\Ahmed Hassan`, or left blank.

Max length: 500 characters. Empty values are always allowed — treat
missing/empty `LocalServerPath` as "no folder assigned" everywhere, never
as an error.

### Files touched by this prompt
- `Database.js` — `api_createCandidate`, `api_updateCandidateDetails`
  (note: `api_getAllCandidates` needs **no change** — it already returns
  every column dynamically via `headers.forEach`, so `LocalServerPath`
  will flow through to the frontend automatically once the column
  exists).
- `Script.html` — `Views.candidateDetail`, new `Views._openLocalFolder`,
  new `Views._copyLocalPath`, `Views._openEditProfileModal`,
  `Views._submitEditProfile`.

---

## CHANGE 1 — `Database.js`: persist `LocalServerPath`

### Block A — `api_createCandidate`: accept and store `localServerPath`

**FIND** (exact match):
```js
function api_createCandidate(candidateData) {
  const auth = requireRole_(['Admin', 'HR']);
  if (!auth.authorized) return { success: false, error: auth.error };
  try {
    const sheet = getSheet_(SHEET_CANDIDATES);
    const id = generateUUID_();
    const now = new Date().toISOString();

    sheet.appendRow([
      id,                                   // CandidateID
      candidateData.fullName,               // FullName
      candidateData.position,               // Position
      candidateData.department,             // Department
      candidateData.email,                  // Email
      candidateData.phone,                  // Phone
      candidateData.nationality,            // Nationality
      candidateData.salary,                 // OfferSalary
      candidateData.coordinatorEmail,       // AssignedCoordinatorEmail
      'Documents Requested',                // CurrentStatus
      now,                                  // CreatedAt
      now,                                  // UpdatedAt
      ''                                    // DriveFolderID (filled by DriveManager)
    ]);

    api_writeLog_(id, 'SYSTEM', 'Candidate Created: ' + candidateData.fullName);
    // [CACHE POLICY] Write operation — invalidate dashboard cache immediately
    CacheService.getScriptCache().remove('dashboard_data');
    return { success: true, candidateId: id };
  } catch (e) {
    Logger.log(e);
    return { success: false, error: e.message };
  }
}
```

**REPLACE WITH:**
```js
function api_createCandidate(candidateData) {
  const auth = requireRole_(['Admin', 'HR']);
  if (!auth.authorized) return { success: false, error: auth.error };
  try {
    const sheet = getSheet_(SHEET_CANDIDATES);
    const id = generateUUID_();
    const now = new Date().toISOString();

    // LocalServerPath is optional; enforce the 500-char max defensively.
    const localServerPath = (candidateData.localServerPath || '').toString().slice(0, 500);

    sheet.appendRow([
      id,                                   // CandidateID
      candidateData.fullName,               // FullName
      candidateData.position,               // Position
      candidateData.department,             // Department
      candidateData.email,                  // Email
      candidateData.phone,                  // Phone
      candidateData.nationality,            // Nationality
      candidateData.salary,                 // OfferSalary
      candidateData.coordinatorEmail,       // AssignedCoordinatorEmail
      'Documents Requested',                // CurrentStatus
      now,                                  // CreatedAt
      now,                                  // UpdatedAt
      '',                                   // DriveFolderID (filled by DriveManager)
      '',                                   // Notes
      localServerPath                       // LocalServerPath (optional, last column)
    ]);

    api_writeLog_(id, 'SYSTEM', 'Candidate Created: ' + candidateData.fullName);
    // [CACHE POLICY] Write operation — invalidate dashboard cache immediately
    CacheService.getScriptCache().remove('dashboard_data');
    return { success: true, candidateId: id };
  } catch (e) {
    Logger.log(e);
    return { success: false, error: e.message };
  }
}
```

> ⚠️ If `tbl_Candidates` already has a `Notes` value being appended
> somewhere else in your real `appendRow` call (some deployments fill it
> in later via `api_updateCandidateDetails` instead), keep whatever your
> current `Notes` handling is — only ADD the new trailing
> `localServerPath` element in the same relative position as the new
> `LocalServerPath` column you created in the sheet.

### Block B — `api_updateCandidateDetails`: read/write `LocalServerPath`

**FIND** (exact match):
```js
function api_updateCandidateDetails(candidateId, updates) {
  const auth = requireRole_(['Admin', 'HR', 'Coordinator']);
  if (!auth.authorized) return { success: false, error: auth.error };
  try {
    const sheet = getSheet_(SHEET_CANDIDATES);
    const data = sheet.getDataRange().getValues();
    const headers = data[0];
    const idCol = headers.indexOf('CandidateID');
    const phoneCol = headers.indexOf('Phone');
    const notesCol = headers.indexOf('Notes'); // Column N
    const updatedCol = headers.indexOf('UpdatedAt');

    for (let i = 1; i < data.length; i++) {
      if (data[i][idCol] === candidateId) {
        if (updates.phone !== undefined && phoneCol >= 0) {
          sheet.getRange(i + 1, phoneCol + 1).setValue(updates.phone);
        }
        if (updates.notes !== undefined) {
          if (notesCol === -1) {
            // Notes column missing — skip silently and log; do not mutate schema at runtime
            Logger.log('WARNING: Notes column not found in tbl_Candidates. Add it manually.');
          } else {
            sheet.getRange(i + 1, notesCol + 1).setValue(updates.notes);
          }
        }
        sheet.getRange(i + 1, updatedCol + 1).setValue(new Date().toISOString());
        api_writeLog_(candidateId, Session.getActiveUser().getEmail(), 'Profile Updated');
        // [CACHE POLICY] Write operation — invalidate dashboard cache immediately
        CacheService.getScriptCache().remove('dashboard_data');
        return { success: true };
      }
    }
    return { success: false, error: 'Candidate not found.' };
  } catch (e) {
    Logger.log(e);
    return { success: false, error: e.message };
  }
}
```

**REPLACE WITH:**
```js
function api_updateCandidateDetails(candidateId, updates) {
  const auth = requireRole_(['Admin', 'HR', 'Coordinator']);
  if (!auth.authorized) return { success: false, error: auth.error };
  try {
    const sheet = getSheet_(SHEET_CANDIDATES);
    const data = sheet.getDataRange().getValues();
    const headers = data[0];
    const idCol = headers.indexOf('CandidateID');
    const phoneCol = headers.indexOf('Phone');
    const notesCol = headers.indexOf('Notes'); // Column N
    const localPathCol = headers.indexOf('LocalServerPath');
    const updatedCol = headers.indexOf('UpdatedAt');

    for (let i = 1; i < data.length; i++) {
      if (data[i][idCol] === candidateId) {
        if (updates.phone !== undefined && phoneCol >= 0) {
          sheet.getRange(i + 1, phoneCol + 1).setValue(updates.phone);
        }
        if (updates.notes !== undefined) {
          if (notesCol === -1) {
            // Notes column missing — skip silently and log; do not mutate schema at runtime
            Logger.log('WARNING: Notes column not found in tbl_Candidates. Add it manually.');
          } else {
            sheet.getRange(i + 1, notesCol + 1).setValue(updates.notes);
          }
        }
        if (updates.localServerPath !== undefined) {
          if (localPathCol === -1) {
            // LocalServerPath column missing — skip silently and log; do not mutate schema at runtime
            Logger.log('WARNING: LocalServerPath column not found in tbl_Candidates. Add it manually.');
          } else {
            // Enforce the 500-char max defensively; empty string is always allowed.
            const path = (updates.localServerPath || '').toString().slice(0, 500);
            sheet.getRange(i + 1, localPathCol + 1).setValue(path);
          }
        }
        sheet.getRange(i + 1, updatedCol + 1).setValue(new Date().toISOString());
        api_writeLog_(candidateId, Session.getActiveUser().getEmail(), 'Profile Updated');
        // [CACHE POLICY] Write operation — invalidate dashboard cache immediately
        CacheService.getScriptCache().remove('dashboard_data');
        return { success: true };
      }
    }
    return { success: false, error: 'Candidate not found.' };
  } catch (e) {
    Logger.log(e);
    return { success: false, error: e.message };
  }
}
```

---

## CHANGE 2 — `Script.html`: Candidate Detail — new card + handlers

### Block A — Insert the "🖥 Internal Company Folder" card

**FIND** (exact match):
```js
      <!-- Document Completeness Panel -->
      <div class="doc-completeness" id="doc-completeness" style="margin-bottom:var(--sp-3)">
        <div class="loading-overlay"><div class="spinner spinner--dark"></div>Calculating completeness…</div>
      </div>
```

**REPLACE WITH:**
```js
      <!-- Internal Company Folder Card -->
      <div class="table-card" style="margin-bottom:var(--sp-3)">
        <div class="table-toolbar">
          <span class="table-toolbar__title">🖥 Internal Company Folder</span>
        </div>
        <div style="padding:var(--sp-3)">
          <div class="form-group">
            <label class="form-label" for="local-server-path">Server Path</label>
            <input type="text" class="form-input" id="local-server-path"
                   value="${escHtml(c.LocalServerPath || '')}"
                   placeholder="No internal folder assigned."
                   readonly ${!c.LocalServerPath ? 'disabled' : ''} />
          </div>
          <div style="display:flex;gap:var(--sp-2)">
            <button class="btn btn--outline btn--sm" ${!c.LocalServerPath ? 'disabled' : ''}
                    onclick="Views._openLocalFolder('${escHtml(c.CandidateID)}')">
              📂 Open Folder
            </button>
            <button class="btn btn--outline btn--sm" ${!c.LocalServerPath ? 'disabled' : ''}
                    onclick="Views._copyLocalPath('${escHtml(c.CandidateID)}')">
              📋 Copy Path
            </button>
          </div>
        </div>
      </div>

      <!-- Document Completeness Panel -->
      <div class="doc-completeness" id="doc-completeness" style="margin-bottom:var(--sp-3)">
        <div class="loading-overlay"><div class="spinner spinner--dark"></div>Calculating completeness…</div>
      </div>
```

### Block B — Add `_openLocalFolder` and `_copyLocalPath` handlers

**FIND** (exact match):
```js
    _infoChip(label, value) {
      return `
      <div style="background:var(--bg-surface);border:1px solid var(--border);border-radius:var(--radius);padding:var(--sp-3)">
        <div style="font-size:.72rem;font-weight:700;text-transform:uppercase;letter-spacing:.04em;color:var(--text-muted);margin-bottom:4px">${label}</div>
        <div style="font-size:.9rem;font-weight:600">${value || '—'}</div>
      </div>`;
    },
```

**REPLACE WITH:**
```js
    _infoChip(label, value) {
      return `
      <div style="background:var(--bg-surface);border:1px solid var(--border);border-radius:var(--radius);padding:var(--sp-3)">
        <div style="font-size:.72rem;font-weight:700;text-transform:uppercase;letter-spacing:.04em;color:var(--text-muted);margin-bottom:4px">${label}</div>
        <div style="font-size:.9rem;font-weight:600">${value || '—'}</div>
      </div>`;
    },

    // ── INTERNAL COMPANY FOLDER (best-effort local/network path) ──────
    _openLocalFolder(candidateId) {
      const c = App.state.candidates.find(cand => cand.CandidateID === candidateId)
             || App.state.selectedCandidate;
      const path = c?.LocalServerPath;
      if (!path) { Toast.warning('No server path assigned.'); return; }
      try {
        window.open(path, '_blank');
      } catch (e) {
        // Best-effort only — browser/OS may block file:// or UNC paths silently.
        // Do NOT surface a JS error to the user for this.
      }
    },

    _copyLocalPath(candidateId) {
      const c = App.state.candidates.find(cand => cand.CandidateID === candidateId)
             || App.state.selectedCandidate;
      const path = c?.LocalServerPath;
      if (!path) return;

      const done = () => Toast.success('Server path copied.');
      const fail = () => Toast.error('Could not copy path.');

      if (navigator.clipboard && navigator.clipboard.writeText) {
        navigator.clipboard.writeText(path).then(done).catch(fail);
      } else {
        // Fallback for older browsers without the Clipboard API
        try {
          const temp = document.createElement('textarea');
          temp.value = path;
          temp.style.position = 'fixed';
          temp.style.opacity = '0';
          document.body.appendChild(temp);
          temp.select();
          document.execCommand('copy');
          document.body.removeChild(temp);
          done();
        } catch (e) {
          fail();
        }
      }
    },
```

### Block C — Add the field to the Edit Profile modal

**FIND** (exact match):
```js
          <div class="form-group col-span-2">
            <label class="form-label" for="edit-notes">Notes</label>
            <textarea class="form-textarea" id="edit-notes" rows="4" placeholder="Add additional instructions or remarks...">${escHtml(c.Notes || '')}</textarea>
          </div>
        </div>
      </div>
      <div class="modal__footer">
        <button class="btn btn--outline" onclick="Modal.close()">Cancel</button>
        <button class="btn btn--primary" id="edit-save-btn" onclick="Views._submitEditProfile('${candidateId}')">Save Changes</button>
      </div>`);
    },
```

**REPLACE WITH:**
```js
          <div class="form-group col-span-2">
            <label class="form-label" for="edit-notes">Notes</label>
            <textarea class="form-textarea" id="edit-notes" rows="4" placeholder="Add additional instructions or remarks...">${escHtml(c.Notes || '')}</textarea>
          </div>
          <div class="form-group col-span-2">
            <label class="form-label" for="edit-local-path">Local Server Path <span style="color:var(--text-muted);font-weight:400">(optional)</span></label>
            <input type="text" class="form-input" id="edit-local-path" maxlength="500"
                   placeholder="\\\\FILESERVER\\Candidates\\..."
                   value="${escHtml(c.LocalServerPath || '')}" />
          </div>
        </div>
      </div>
      <div class="modal__footer">
        <button class="btn btn--outline" onclick="Modal.close()">Cancel</button>
        <button class="btn btn--primary" id="edit-save-btn" onclick="Views._submitEditProfile('${candidateId}')">Save Changes</button>
      </div>`);
    },
```

### Block D — Save the new field from `_submitEditProfile`

**FIND** (exact match):
```js
    async _submitEditProfile(candidateId) {
      const phone = document.getElementById('edit-phone')?.value?.trim();
      const notes = document.getElementById('edit-notes')?.value?.trim();

      if (!phone) { Toast.warning('Phone number is required.'); return; }

      const btn = document.getElementById('edit-save-btn');
      btn.disabled = true;
      btn.innerHTML = 'Saving...';

      try {
        const res = await GAS.call('api_updateCandidateDetails', candidateId, { phone, notes });
        if (!res.success) throw new Error(res.error);

        // Update local state
        const cand = App.state.candidates.find(c => c.CandidateID === candidateId);
        if (cand) {
          cand.Phone = phone;
          cand.Notes = notes;
        }
        if (App.state.selectedCandidate?.CandidateID === candidateId) {
          App.state.selectedCandidate.Phone = phone;
          App.state.selectedCandidate.Notes = notes;
        }

        Modal.close();
        Toast.success('Profile updated successfully!');
        Router.navigate('candidate-detail'); // Re-render detail view to show new values
      } catch (err) {
        Toast.error('Failed to update: ' + err.message);
        btn.disabled = false;
        btn.innerHTML = 'Save Changes';
      }
    },
```

**REPLACE WITH:**
```js
    async _submitEditProfile(candidateId) {
      const phone = document.getElementById('edit-phone')?.value?.trim();
      const notes = document.getElementById('edit-notes')?.value?.trim();
      const localServerPath = document.getElementById('edit-local-path')?.value?.trim().slice(0, 500);

      if (!phone) { Toast.warning('Phone number is required.'); return; }

      const btn = document.getElementById('edit-save-btn');
      btn.disabled = true;
      btn.innerHTML = 'Saving...';

      try {
        const res = await GAS.call('api_updateCandidateDetails', candidateId, { phone, notes, localServerPath });
        if (!res.success) throw new Error(res.error);

        // Update local state
        const cand = App.state.candidates.find(c => c.CandidateID === candidateId);
        if (cand) {
          cand.Phone = phone;
          cand.Notes = notes;
          cand.LocalServerPath = localServerPath;
        }
        if (App.state.selectedCandidate?.CandidateID === candidateId) {
          App.state.selectedCandidate.Phone = phone;
          App.state.selectedCandidate.Notes = notes;
          App.state.selectedCandidate.LocalServerPath = localServerPath;
        }

        Modal.close();
        Toast.success('Profile updated successfully!');
        Router.navigate('candidate-detail'); // Re-render detail view to show new values
      } catch (err) {
        Toast.error('Failed to update: ' + err.message);
        btn.disabled = false;
        btn.innerHTML = 'Save Changes';
      }
    },
```

---

## TEST CASES

1. **Empty path** — open a candidate with no `LocalServerPath`: card
   shows a disabled, placeholder-text input and both buttons disabled.
2. **Copy** — candidate with a path set, click "Copy Path" → clipboard
   contains the exact path, toast reads "Server path copied."
3. **Open Folder** — click "Open Folder" → browser attempts
   `window.open(path, '_blank')`; if blocked by the browser, no JS error
   is thrown and no toast is shown (best-effort, silent).
4. **Edit & persist** — Edit Profile → set a new "Local Server Path" →
   Save → reload/re-open the candidate → value persists exactly, and the
   card + Edit modal both reflect it.
5. **Backward compatibility** — existing candidates created before this
   change (no value in the new column) load and behave exactly as
   before; no console errors, no broken layout.
6. **Role check** — a `Viewer` account can see the card and path
   (read-only) but `api_updateCandidateDetails` still blocks Viewers from
   saving changes via the existing `requireRole_` guard — unchanged
   behavior, just confirms the new field didn't bypass authorization.
