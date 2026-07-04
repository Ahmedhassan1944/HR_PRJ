# TASK: Fix 3 remaining Calendar-feature bugs (after `bba49640` syntax fix)

The blank-page crash is fixed. Three NEW issues appeared once the UI could
actually render. Fix all three. Do NOT touch anything else in the app.

---

## BUG A (root cause of #1 Dashboard stuck loading AND #3 Calendar page stuck loading)

### Root cause
`CalendarManager.js` assumes a sheet named `tbl_Events` already exists in
the spreadsheet:

```js
function getSheet_(sheetName) {
  const sheet = getSpreadsheet_().getSheetByName(sheetName);
  if (!sheet) throw new Error('Sheet not found: ' + sheetName);
  return sheet;
}
```

**Nothing ever creates `tbl_Events`.** So every call to
`getSheet_(SHEET_EVENTS)` throws `Sheet not found: tbl_Events`. This
happens inside:
- `api_getAllUpcomingEvents()` → called by `api_getDashboardData()` →
  throws → caught → returns `{ success: false, error: ... }` → the
  Dashboard's `if (kpiRes.success)` block is skipped → the skeleton
  loading placeholders in `#kpi-grid-status` / `#kpi-grid-has` /
  `#kpi-grid-missing` / `#kpi-grid-calendar` are NEVER replaced → looks
  like infinite loading, and the OTHER (non-calendar) KPI sections don't
  load either, even though their own data is fine, because the whole
  `api_getDashboardData()` call fails as one unit.
- `Views.calendar(container)` → same call → fails → caught → only
  `Toast.error('Failed to load events.')` fires, but the
  `#calendar-event-list` div still shows its original
  "Loading upcoming events…" spinner forever, since nothing replaces it
  on the error path.

### Fix
1. In `CalendarManager.js`, add a private helper right after
   `getAppCalendar_()` that gets-or-creates the `tbl_Events` sheet with
   its header row, mirroring how other sheets are structured in this
   project:

```js
function getEventsSheet_() {
  const ss = getSpreadsheet_();
  let sheet = ss.getSheetByName(SHEET_EVENTS);
  if (!sheet) {
    sheet = ss.insertSheet(SHEET_EVENTS);
    sheet.appendRow([
      'EventID', 'CandidateID', 'CandidateName', 'Title', 'Description',
      'EventDate', 'EventTime', 'Priority', 'ReminderMinutesBefore',
      'Status', 'GoogleCalendarEventId', 'GoogleCalendarLink',
      'CreatedBy', 'CreatedAt', 'UpdatedAt'
    ]);
    sheet.setFrozenRows(1);
  }
  return sheet;
}
```

2. Replace every occurrence of `getSheet_(SHEET_EVENTS)` in
   `CalendarManager.js` with `getEventsSheet_()` (there are 6 call sites —
   in `api_createCalendarEvent`, `api_getEventsByCandidate`,
   `api_getAllUpcomingEvents`, `api_updateCalendarEvent`, and 2 more).
   Do not change any other logic in those functions.

3. **Defensive frontend fix (belt-and-suspenders, in `Script.html`)** so a
   future backend failure never looks like an infinite hang again:
   - In `Views._refreshDashboard()`, inside the `try` block, if
     `!kpiRes.success`, render a visible error state into
     `kpi-grid-status`, `kpi-grid-has`, `kpi-grid-missing`, and
     `kpi-grid-calendar` (e.g. a single-column error card saying
     "Failed to load: " + kpiRes.error) instead of silently leaving the
     skeleton placeholders untouched.
   - In `Views.calendar(container)`, in the `catch` block (and in the
     `else { throw new Error(res.error) }` path), also set
     `document.getElementById('calendar-event-list').innerHTML` to an
     error message (e.g. using the existing `.table-empty` class) instead
     of leaving the loading spinner in place.

---

## BUG B (Schedule Event → permission error)

### Error
```
❌ The script does not have permission to perform that action.
Required permissions: (https://www.googleapis.com/auth/calendar ||
https://www.googleapis.com/auth/calendar.readonly || ...)
```

### Root cause
`appsscript.json` has no explicit `oauthScopes`. Apps Script normally
auto-detects required scopes from the code, but auto-detection only
re-runs when a NEW authorization/deployment cycle is triggered — it did
not pick up the newly-added `CalendarApp` calls from the existing
authorization grant, so the script is still running under the OLD
(pre-Calendar) permission set.

### Fix
1. Add explicit `oauthScopes` to `appsscript.json` so the manifest is
   unambiguous and forces Apps Script to request the calendar scope on
   next authorization:

```json
{
  "timeZone": "Africa/Cairo",
  "dependencies": {},
  "exceptionLogging": "STACKDRIVER",
  "runtimeVersion": "V8",
  "oauthScopes": [
    "https://www.googleapis.com/auth/spreadsheets",
    "https://www.googleapis.com/auth/drive",
    "https://www.googleapis.com/auth/calendar",
    "https://www.googleapis.com/auth/script.external_request",
    "https://www.googleapis.com/auth/userinfo.email"
  ],
  "webapp": {
    "executeAs": "USER_DEPLOYING",
    "access": "DOMAIN"
  }
}
```

   (Keep `https://www.googleapis.com/auth/script.external_request` only
   if the project actually makes external HTTP calls elsewhere — check
   `UrlFetchApp` usage in the codebase first; if none exists, omit that
   scope.)

2. **This code change alone is not enough** — OAuth grants are tied to
   the user who authorizes the project, not to the manifest file. After
   this change is pushed, the project owner (the account deploying the
   web app) MUST do the following manually in the Apps Script editor
   (this is a one-time manual step, not something Antigravity can do via
   code):
   - Open the project in script.google.com.
   - Run any function once from the editor (e.g. select `getAppCalendar_`
     or any function in `CalendarManager.js` and click Run) — this
     triggers Google's consent screen listing the new Calendar
     permission; click **Allow**.
   - Go to Deploy → Manage deployments → edit the existing Web App
     deployment → select **New version** → Deploy. (Saving the script
     alone does NOT push code/scope changes to a live Web App — a Web
     App only updates when a new deployment version is created.)
   - If this Google Workspace domain restricts sensitive/restricted API
     scopes for internal apps (Admin Console → Security → API Controls),
     the domain admin may need to allowlist this script's Calendar scope
     — if the permission error persists after the steps above, that is
     the next thing to check (not a code problem).

---

## VERIFICATION

1. Push the `tbl_Events` auto-creation fix, reload the app, confirm the
   Dashboard's Pipeline/Has/Missing/Calendar KPI sections all populate
   with real numbers (not stuck on skeletons).
2. Open the Calendar page from the sidebar, confirm the event list loads
   (even if empty — it should show "No upcoming events found.", not an
   infinite spinner).
3. After completing the manual re-authorization + redeploy steps in Bug
   B, open a candidate, click "📅 Add Event", fill the form, click
   "Schedule Event", and confirm it succeeds with a success toast and the
   event appears both in the candidate's Events section and in the
   "HR Mobilization — Follow-ups" Google Calendar.
