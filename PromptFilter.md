# PROMPT — Candidates Filter: Exclude Status Section + Filter State Persistence

## ⚠️ CRITICAL RULES
- Edit `Script.html` ONLY. Do NOT touch `Code.js`, `Database.js`, `DriveManager.js`, `Styles.html`, or `Tests.js`.
- Apply ALL 5 changes in order.
- Output exactly **5 code blocks**, one per change.

---

## CONTEXT — How the current filter system works

The `#advanced-filter-panel` currently has 4 sections:

| Section | Input type | `App.state` key | Filter logic |
|---|---|---|---|
| 📋 Status | checkboxes `.status-check` | `statusFilters[]` | **include**: show ONLY these statuses |
| 📎 Missing Documents | checkboxes `.doc-check` | `docFilters[]` | show candidates missing these docs |
| 🏢 Department | `<select #dept-filter>` | (read directly from DOM) | exact match |
| 📊 Min. Completion % | `<input #completion-min>` | (read directly from DOM) | >= threshold |

Filter logic lives in `Views._filterCandidates()`.
State is stored in `App.state` (`statusFilters`, `docFilters`).
Filter state is **not** persisted — it resets on every navigation.

---

## WHAT TO BUILD

### Feature 1 — Fifth filter section: "Exclude Status"
Add a new `🚫 Exclude Status` section below the existing `📋 Status` section.
It works as the **inverse** of the Status section:
- When a status is checked here, candidates **with** that status are **hidden** from the table.
- When nothing is checked, nothing is excluded (all candidates shown by default).
- The same 12 statuses appear as checkboxes: `New Candidate`, `Pending Passport`, `Pending Photo`, `Pending Academic Certificate`, `Pending Medical`, `Booked a medical examination`, `Documents Under Preparing`, `Documents Complete`, `Visa Pending`, `Visa Completed`, `Mobilized`, `Closed`.

### Feature 2 — Persist all filter state to localStorage
Every time any filter changes, save the full filter state to `localStorage`.
When the Candidates page loads, restore filters from `localStorage` and re-apply them automatically.

**localStorage key**: `hr_candidate_filters`
**Saved fields** (JSON):
```json
{
  "statusFilters": [],
  "excludeStatusFilters": [],
  "docFilters": [],
  "deptFilter": "",
  "completionMin": 0
}
```

---

## CHANGE 1 — Add `excludeStatusFilters` to `App.state`

**FIND** (exact match):
```js
      statusFilters: [],     // [] = all; otherwise array of status strings
      docFilters: [],        // array of doc-type strings meaning "missing these"
```

**REPLACE WITH:**
```js
      statusFilters: [],        // [] = all; otherwise array of status strings to INCLUDE
      excludeStatusFilters: [], // [] = none excluded; otherwise statuses to HIDE
      docFilters: [],           // array of doc-type strings meaning "missing these"
```

---

## CHANGE 2 — Add the "Exclude Status" section to the filter panel HTML

**FIND** (exact match — after the closing `</div>` of the Status section):
```html
            <div class="filter-section">
              <div class="filter-section__label">📎 Missing Documents</div>
```

**REPLACE WITH:**
```html
            <div class="filter-section">
              <div class="filter-section__label">🚫 Exclude Status</div>
              <div class="filter-check-group">
                <label class="filter-check-item"><input type="checkbox" class="excl-status-check" value="New Candidate"                id="ex-New_Candidate"                onchange="Views._onExcludeStatusCheckChange()"><span>New Candidate</span></label>
                <label class="filter-check-item"><input type="checkbox" class="excl-status-check" value="Pending Passport"             id="ex-Pending_Passport"             onchange="Views._onExcludeStatusCheckChange()"><span>Pending Passport</span></label>
                <label class="filter-check-item"><input type="checkbox" class="excl-status-check" value="Pending Photo"                id="ex-Pending_Photo"                onchange="Views._onExcludeStatusCheckChange()"><span>Pending Photo</span></label>
                <label class="filter-check-item"><input type="checkbox" class="excl-status-check" value="Pending Academic Certificate" id="ex-Pending_Academic_Certificate"  onchange="Views._onExcludeStatusCheckChange()"><span>Pending Academic Certificate</span></label>
                <label class="filter-check-item"><input type="checkbox" class="excl-status-check" value="Pending Medical"              id="ex-Pending_Medical"              onchange="Views._onExcludeStatusCheckChange()"><span>Pending Medical</span></label>
                <label class="filter-check-item"><input type="checkbox" class="excl-status-check" value="Booked a medical examination" id="ex-Booked_medical"                onchange="Views._onExcludeStatusCheckChange()"><span>Booked a medical examination</span></label>
                <label class="filter-check-item"><input type="checkbox" class="excl-status-check" value="Documents Under Preparing"    id="ex-Docs_Under_Preparing"          onchange="Views._onExcludeStatusCheckChange()"><span>Documents Under Preparing</span></label>
                <label class="filter-check-item"><input type="checkbox" class="excl-status-check" value="Documents Complete"          id="ex-Documents_Complete"           onchange="Views._onExcludeStatusCheckChange()"><span>Documents Complete</span></label>
                <label class="filter-check-item"><input type="checkbox" class="excl-status-check" value="Visa Pending"                id="ex-Visa_Pending"                 onchange="Views._onExcludeStatusCheckChange()"><span>Visa Pending</span></label>
                <label class="filter-check-item"><input type="checkbox" class="excl-status-check" value="Visa Completed"              id="ex-Visa_Completed"               onchange="Views._onExcludeStatusCheckChange()"><span>Visa Completed</span></label>
                <label class="filter-check-item"><input type="checkbox" class="excl-status-check" value="Mobilized"                   id="ex-Mobilized"                    onchange="Views._onExcludeStatusCheckChange()"><span>Mobilized</span></label>
                <label class="filter-check-item"><input type="checkbox" class="excl-status-check" value="Closed"                      id="ex-Closed"                       onchange="Views._onExcludeStatusCheckChange()"><span>Closed</span></label>
              </div>
            </div>

            <div class="filter-section">
              <div class="filter-section__label">📎 Missing Documents</div>
```

---

## CHANGE 3 — Update filter logic, add new handler, add localStorage persistence, update clear + restore

Apply all blocks below in `Script.html`.

### Block A — Update `_filterCandidates()` to apply `excludeStatusFilters`

**FIND** (exact match):
```js
        // Multi-select status (empty array = all)
        const matchS = statusFilters.length === 0 || statusFilters.includes(c.CurrentStatus);
```

**REPLACE WITH:**
```js
        // Multi-select status INCLUDE (empty array = all)
        const matchS = statusFilters.length === 0 || statusFilters.includes(c.CurrentStatus);
        // Multi-select status EXCLUDE (empty array = hide nothing)
        const { excludeStatusFilters } = App.state;
        const matchExcl = excludeStatusFilters.length === 0 || !excludeStatusFilters.includes(c.CurrentStatus);
```

---

**FIND** (exact match — still inside the `.filter()` callback):
```js
        return matchQ && matchS && matchD && matchDoc && matchCompletion;
```

**REPLACE WITH:**
```js
        return matchQ && matchS && matchExcl && matchD && matchDoc && matchCompletion;
```

---

### Block B — Add `_onExcludeStatusCheckChange()` handler (insert after `_onStatusCheckChange`)

**FIND** (exact match):
```js
    // ── Advanced panel: document checkboxes changed ──
    _onDocCheckChange() {
```

**REPLACE WITH:**
```js
    // ── Advanced panel: exclude-status checkboxes changed ──
    _onExcludeStatusCheckChange() {
      const checked = [...document.querySelectorAll('.excl-status-check:checked')].map(el => el.value);
      App.setState({ excludeStatusFilters: checked });
      Views._saveFilterState();
      Views._updateClearButton();
      Views._filterCandidates();
    },

    // ── Advanced panel: document checkboxes changed ──
    _onDocCheckChange() {
```

---

### Block C — Add `_saveFilterState()` and `_restoreFilterState()` helpers (insert before `_toggleAdvancedFilters`)

**FIND** (exact match):
```js
    _toggleAdvancedFilters() {
```

**REPLACE WITH:**
```js
    // ── Persist all filter state to localStorage ──
    _saveFilterState() {
      const deptEl  = document.getElementById('dept-filter');
      const rangeEl = document.getElementById('completion-min');
      const payload = {
        statusFilters:        App.state.statusFilters,
        excludeStatusFilters: App.state.excludeStatusFilters,
        docFilters:           App.state.docFilters,
        deptFilter:           deptEl  ? deptEl.value  : '',
        completionMin:        rangeEl ? parseInt(rangeEl.value, 10) : 0,
      };
      try { localStorage.setItem('hr_candidate_filters', JSON.stringify(payload)); } catch (_) {}
    },

    // ── Restore filter state from localStorage and re-apply ──
    _restoreFilterState() {
      let saved;
      try { saved = JSON.parse(localStorage.getItem('hr_candidate_filters') || 'null'); } catch (_) {}
      if (!saved) return;

      // Restore state object
      App.setState({
        statusFilters:        Array.isArray(saved.statusFilters)        ? saved.statusFilters        : [],
        excludeStatusFilters: Array.isArray(saved.excludeStatusFilters) ? saved.excludeStatusFilters : [],
        docFilters:           Array.isArray(saved.docFilters)           ? saved.docFilters           : [],
      });

      // Restore Status checkboxes + quick-filter buttons
      document.querySelectorAll('.status-check').forEach(cb => {
        cb.checked = App.state.statusFilters.includes(cb.value);
      });
      ['Visa Pending','Visa Completed','Mobilized','Documents Complete'].forEach(st => {
        const btn = document.getElementById(`qf-status-${st.replace(/\s/g,'_')}`);
        if (btn) {
          const on = App.state.statusFilters.includes(st);
          btn.classList.toggle('quick-filter-btn--active', on);
          btn.setAttribute('aria-pressed', String(on));
        }
      });

      // Restore Exclude Status checkboxes
      document.querySelectorAll('.excl-status-check').forEach(cb => {
        cb.checked = App.state.excludeStatusFilters.includes(cb.value);
      });

      // Restore Doc checkboxes + quick-filter buttons
      document.querySelectorAll('.doc-check').forEach(cb => {
        cb.checked = App.state.docFilters.includes(cb.value);
      });
      ['Passport','Photo','Academic Certificate','Medical Examination','Medical Analysis','Visa','CV'].forEach(doc => {
        const btn = document.getElementById(`qf-doc-${doc.replace(/\s/g,'_')}`);
        if (btn) {
          const on = App.state.docFilters.includes(doc);
          btn.classList.toggle('quick-filter-btn--active', on);
          btn.setAttribute('aria-pressed', String(on));
        }
      });

      // Restore Department dropdown
      const deptEl = document.getElementById('dept-filter');
      if (deptEl && saved.deptFilter) deptEl.value = saved.deptFilter;

      // Restore Completion % range
      const rangeEl  = document.getElementById('completion-min');
      const rangeVal = document.getElementById('completion-min-val');
      if (rangeEl && saved.completionMin != null) {
        rangeEl.value = saved.completionMin;
        if (rangeVal) rangeVal.textContent = saved.completionMin + '%';
      }

      Views._updateClearButton();
      Views._filterCandidates();
    },

    _toggleAdvancedFilters() {
```

---

### Block D — Hook `_saveFilterState()` into all existing filter change handlers

**FIND** (exact match — inside `_onStatusCheckChange`):
```js
      Views._updateClearButton();
      Views._filterCandidates();
    },

    // ── Quick-filter: toggle a doc type as "missing" ──
```

**REPLACE WITH:**
```js
      Views._saveFilterState();
      Views._updateClearButton();
      Views._filterCandidates();
    },

    // ── Quick-filter: toggle a doc type as "missing" ──
```

---

**FIND** (exact match — inside `_toggleDocFilter`, the `Views._updateClearButton();` + `Views._filterCandidates();` block):
```js
      Views._updateClearButton();
      Views._filterCandidates();
    },

    // ── Quick-filter: toggle a status ──
```

**REPLACE WITH:**
```js
      Views._saveFilterState();
      Views._updateClearButton();
      Views._filterCandidates();
    },

    // ── Quick-filter: toggle a status ──
```

---

**FIND** (exact match — inside `_toggleStatusFilter`):
```js
      Views._updateClearButton();
      Views._filterCandidates();
    },

    // ── Advanced panel: status checkboxes changed ──
```

**REPLACE WITH:**
```js
      Views._saveFilterState();
      Views._updateClearButton();
      Views._filterCandidates();
    },

    // ── Advanced panel: status checkboxes changed ──
```

---

**FIND** (exact match — inside `_onDocCheckChange`):
```js
      Views._updateClearButton();
      Views._filterCandidates();
    },

    _onCompletionRange(value) {
```

**REPLACE WITH:**
```js
      Views._saveFilterState();
      Views._updateClearButton();
      Views._filterCandidates();
    },

    _onCompletionRange(value) {
```

---

**FIND** (exact match — inside `_onCompletionRange`):
```js
    _onCompletionRange(value) {
      const el = document.getElementById('completion-min-val');
      if (el) el.textContent = value + '%';
      Views._filterCandidates();
    },
```

**REPLACE WITH:**
```js
    _onCompletionRange(value) {
      const el = document.getElementById('completion-min-val');
      if (el) el.textContent = value + '%';
      Views._saveFilterState();
      Views._filterCandidates();
    },
```

---

**FIND** (exact match — inside `_filterCandidates`, the dept dropdown change, which calls `Views._filterCandidates()` directly from `onchange`):

> The department dropdown uses `onchange="Views._filterCandidates()"` directly in HTML.
> Replace the `onchange` attribute so it calls save then filter.

**FIND** (exact match in HTML):
```html
              <select id="dept-filter" class="form-select" style="max-width:190px" onchange="Views._filterCandidates()">
```

**REPLACE WITH:**
```html
              <select id="dept-filter" class="form-select" style="max-width:190px" onchange="Views._saveFilterState();Views._filterCandidates()">
```

---

### Block E — Update `_clearAllFilters()` to also reset `excludeStatusFilters` and clear localStorage

**FIND** (exact match):
```js
    _clearAllFilters() {
      App.setState({ statusFilters: [], docFilters: [], sortCol: '', sortDir: 'asc' });
      document.querySelectorAll('.status-check, .doc-check').forEach(cb => { cb.checked = false; });
```

**REPLACE WITH:**
```js
    _clearAllFilters() {
      App.setState({ statusFilters: [], excludeStatusFilters: [], docFilters: [], sortCol: '', sortDir: 'asc' });
      document.querySelectorAll('.status-check, .excl-status-check, .doc-check').forEach(cb => { cb.checked = false; });
```

---

**FIND** (exact match — still inside `_clearAllFilters`, just before `Views._updateClearButton()`):
```js
      if (searchInput) searchInput.value = '';
      Views._updateClearButton();
      Views._filterCandidates();
    },
```

**REPLACE WITH:**
```js
      if (searchInput) searchInput.value = '';
      try { localStorage.removeItem('hr_candidate_filters'); } catch (_) {}
      Views._updateClearButton();
      Views._filterCandidates();
    },
```

---

### Block F — Update `_updateClearButton()` to count `excludeStatusFilters` too

**FIND** (exact match):
```js
    _updateClearButton() {
      const hasFilters = App.state.statusFilters.length > 0 || App.state.docFilters.length > 0;
```

**REPLACE WITH:**
```js
    _updateClearButton() {
      const hasFilters = App.state.statusFilters.length > 0
        || App.state.excludeStatusFilters.length > 0
        || App.state.docFilters.length > 0;
```

---

## CHANGE 4 — Call `_restoreFilterState()` when the Candidates page finishes loading

The Candidates page loads data asynchronously. `_restoreFilterState()` must run **after** `App.state.candidates` and `App.state.docCompleteness` are populated — otherwise the filter re-apply finds no data to filter.

Find the point where the candidates page finishes its initial data load and calls `_filterCandidates()` for the first time. It will look like one of these patterns:

```js
App.setState({ candidates: data, filteredCandidates: data });
Views._renderCandidatesTable(data);
```

or

```js
Views._filterCandidates();
```

(the last call to `_filterCandidates()` inside the candidates init/load sequence)

Add `Views._restoreFilterState();` immediately **before** that final `Views._filterCandidates()` call in the load sequence, so that restored filters are applied to the freshly-loaded data.

> If `_filterCandidates()` is the last line of the load callback, replace:
> ```js
>   Views._filterCandidates();
> ```
> With:
> ```js
>   Views._restoreFilterState();
> ```
> (because `_restoreFilterState` always calls `_filterCandidates()` at its end — no double call needed)

---

## CHANGE 5 — Department filter: also save when changed via `_filterCandidates()` direct call

> This is already handled in Change 3 Block D (the `onchange` attribute replacement on `#dept-filter`).
> **No additional code needed.** Confirmed complete.

---

## MANDATORY OUTPUT FORMAT

Output exactly **5 code blocks** in this order:

1. ` ```html ` — Change 1: `App.state` update
2. ` ```html ` — Change 2: Exclude Status HTML section
3. ` ```js `  — Change 3: All 6 sub-blocks (A through F) — filter logic, new handler, save/restore helpers, hook save into all handlers, clear update, clear-button update
4. ` ```js `  — Change 4: `_restoreFilterState()` call at end of candidates load sequence
5. ` ```js `  — Change 5: Confirmation comment (no code needed — already handled)

---

## EXPECTED BEHAVIOUR TABLE

| Action | Before | After |
|---|---|---|
| Open filter panel → check "Visa Completed" in **Exclude Status** | N/A | All candidates with status "Visa Completed" disappear from the table instantly |
| Check "Visa Completed" in both **Status** (include) and **Exclude Status** | N/A | Exclusion wins — candidate is hidden (exclude takes priority in the `&&` chain) |
| Nothing checked in Exclude Status | N/A | All statuses visible — no change from current behaviour |
| Apply any filter → navigate away → come back | Filters reset | All filters (status, exclude, docs, dept, completion %) restored from localStorage automatically |
| Click "✕ Clear" | Resets status + doc filters | Resets ALL filters including excludeStatusFilters AND clears localStorage |
| `_updateClearButton` | Only checks statusFilters + docFilters | Also checks excludeStatusFilters — "✕ Clear" appears whenever any filter is active |

---

## RISK TABLE

| # | Risk | Mitigation |
|---|---|---|
| localStorage unavailable (private browsing) | save/restore silently skipped | all calls wrapped in `try/catch` |
| Stale saved state after data model change | user clicks "✕ Clear" to reset | `localStorage.removeItem` on clear |
| Double `_filterCandidates()` call on restore | Performance waste | `_restoreFilterState` is the only caller — removed the final direct call (Change 4) |
| Exclude + Include same status | Ambiguous intent | Exclude wins by being last in the `&&` chain — predictable |

**Zero changes to backend files.**