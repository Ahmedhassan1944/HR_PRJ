# TASK: Implement "Follow-up Calendar" Module (Google Calendar Integration)

## ⚠️ PREREQUISITES
- Authorization.md (role-based access control) is already applied: `requireRole_()`
  exists in Database.js and is used by every write `api_*` function.
- The Dashboard cache-invalidation policy documented at the top of Code.js is
  MANDATORY for this feature too (see CHANGE 5 below).

## ⚠️ CRITICAL RULES
- Reuse the EXACT existing architecture. Do NOT invent a new patterns for
  auth, caching, modals, toasts, or view routing — copy the conventions
  already used in Database.js / DriveManager.js / Script.html.
- Do NOT recreate a calendar system inside Google Sheets. Google Calendar
  (via `CalendarApp`, the built-in GAS service) is the source of truth for
  event date/time/reminders. Google Sheets only stores a thin metadata
  record that links an event to a candidate.
- Do NOT touch: `Index.html`, `BackupService.js`, `appsscript.json`
  (CalendarApp is a built-in GAS service — no manifest/advanced-service
  change is needed), `Tests.js`, `TestUtils.js`, `ProductionTest.js`
  (extend these only in CHANGE 7, as a separate, clearly-labeled step).
- All new backend functions MUST follow the naming convention `api_verbNoun`
  (e.g. `api_createCalendarEvent`) and the private-helper convention
  `xxx_` (trailing underscore, e.g. `getCalendar_()`).
- Every function must return `{ success: true, data|... }` or
  `{ success: false, error: string }` — exactly like every existing
  `api_*` function. Never throw uncaught errors to the frontend.

---

## CONTEXT — Existing Architecture (must be reused, not reinvented)

**Backend (Google Apps Script, V8 runtime):**
- `Code.js` — `doGet`, `include()`, and `api_getDashboardData()` (dashboard KPI
  aggregator with an event-based cache: key `'dashboard_data'`, TTL 60s
  fallback, invalidated via `CacheService.getScriptCache().remove('dashboard_data')`
  at the end of every write operation).
- `Database.js` — `getSpreadsheet_()`, `getSheet_(name)`, `generateUUID_()`,
  `getCurrentUserRole_()`, `requireRole_(allowedRoles)`. Sheet name constants
  follow the pattern `SHEET_XXX = 'tbl_Xxx'`. Existing sheets: `tbl_Candidates`,
  `tbl_Documents`, `tbl_Users`, `tbl_SystemLogs`.
- `DriveManager.js` — Pattern to mirror for the new `CalendarManager.js`:
  a dedicated module file, a private "get-or-create" resource helper cached
  in `PropertiesService`, and public `api_*` functions with role checks as
  the very first line.
- `api_writeLog_(candidateId, actor, event)` — the ONLY way to write audit
  log rows. Every meaningful mutation calls it.
- Roles: `Admin`, `HR`, `Coordinator`, `Viewer` (exact strings, case-sensitive).

**Frontend (single-file SPA in Script.html, vanilla JS, no framework):**
- `App.state` — central state object; mutate via `App.setState({...})`.
- `GAS.call(fnName, ...args)` — bridge to `google.script.run`; when not
  running inside GAS (`GAS.isLive === false`) it falls back to
  `GAS._mockData(fnName, ...args)` for local/offline preview. **You MUST
  extend `_mockData` with realistic mock responses for every new
  `api_*` function you add**, following the exact shape/fields of the
  real backend response.
- `Router.navigate(view, params)` → sets `currentView`, re-renders sidebar
  and view via `renderView()`'s if/else dispatcher.
- `sidebar_items` array drives the sidebar nav (icon, label, optional badge).
- `Views` object — one method per view (`dashboard`, `candidates`,
  `candidateDetail`, `newCandidate`, `auditLog`). Private helpers prefixed
  `_` (e.g. `Views._openStatusModal`).
- `Modal.open(html)` / `Modal.close()` — shared modal helper.
- `Toast.success/error/warning(msg)` — shared toast helper.
- `fmt.date()`, `fmt.dateTime()`, `escHtml()`, `statusBadge()` — shared
  formatting/escaping helpers. REUSE them; do not duplicate.
- Dashboard KPI cards are rendered via `Views._kpiCard(title, value, icon,
  color, subtitle, filter)` where `filter` is `{ type, value }` — clicking
  a card calls `Views._onKpiCardClick` which filters the Candidates table.
  Follow the SAME click-to-filter pattern for the new "Upcoming Today /
  Upcoming Tomorrow / This Week / Overdue / High Priority" cards, except
  they should navigate to/filter the new Calendar view instead.
- Styling: `Styles.html` uses CSS custom properties (`var(--sp-3)`,
  `var(--primary)`, `var(--success)`, `var(--warning)`, `var(--radius)`,
  etc.) and existing component classes (`.table-card`, `.table-toolbar`,
  `.badge`, `.doc-row`, `.timeline`, `.form-group`, `.btn`, `.btn--primary`,
  `.btn--outline`, `.btn--sm`). Reuse these classes; add new ones only for
  genuinely new UI (event cards, priority badges, calendar/agenda layout)
  and place them in a clearly-commented new section at the end of
  Styles.html, matching the existing formatting style.

---

## FEATURE DESCRIPTION

Add a new "Follow-up Calendar" module that lets HR staff create, view, and
manage date-based reminders tied to individual candidates (passport
collection, medical appointments, visa appointments, flight dates,
contract signing, etc.), backed by real Google Calendar events — NOT a
custom in-app calendar/reminder engine.

### Business goal
With 20–100 active candidates, HR cannot manually track every future
follow-up. The system must generate real Google Calendar events (so users
get native Google email/mobile/browser notifications) while keeping every
event traceable back to its candidate inside the HR app.

---

## DATA MODEL — New Sheet: `tbl_Events`

Add a new sheet/tab named `tbl_Events` with these columns (in order):

| Column                | Type    | Notes                                                        |
|-----------------------|---------|---------------------------------------------------------------|
| EventID               | string  | UUID via `generateUUID_()`                                    |
| CandidateID           | string  | FK → `tbl_Candidates.CandidateID`                              |
| CandidateName         | string  | Denormalized snapshot for fast list rendering                 |
| Title                 | string  | e.g. "Passport Pickup"                                         |
| Description           | string  | Free text                                                      |
| EventDate             | string  | ISO date `YYYY-MM-DD`                                          |
| EventTime             | string  | `HH:mm` 24h, or empty string for all-day events                |
| Priority              | string  | `Low` \| `Medium` \| `High`                                    |
| ReminderMinutesBefore | number  | Minutes before event to fire the Calendar reminder             |
| Status                | string  | `Active` \| `Completed` \| `Cancelled`                          |
| GoogleCalendarEventId | string  | ID returned by `CalendarApp`, used for update/delete            |
| GoogleCalendarLink    | string  | `event.getHtmlLink()` if available, else empty                 |
| CreatedBy             | string  | `Session.getActiveUser().getEmail()`                            |
| CreatedAt             | string  | ISO timestamp                                                  |
| UpdatedAt             | string  | ISO timestamp                                                  |

Add `SHEET_EVENTS = 'tbl_Events'` constant to `Database.js` next to the
other `SHEET_*` constants.

---

## BACKEND REQUIREMENTS — New file `CalendarManager.js`

Mirror the structure of `DriveManager.js` exactly.

1. **`getAppCalendar_()`** (private)
   - Get-or-create a dedicated Google Calendar named
     `"HR Mobilization — Follow-ups"` for the app (do NOT use the user's
     default calendar, so events are visually and organizationally
     separated from personal events).
   - Cache the calendar ID in `PropertiesService.getScriptProperties()`
     under key `APP_CALENDAR_ID`, exactly like `ROOT_FOLDER_ID` is cached
     in `DriveManager.js` (search-then-create-then-persist pattern, with
     stale-ID fallback via try/catch).

2. **`api_createCalendarEvent(candidateId, eventData)`**
   - `requireRole_(['Admin', 'HR', 'Coordinator'])` as the first line.
   - Validate required fields server-side (never trust client): `title`,
     `eventDate` (valid ISO date), `priority` (must be one of
     `Low|Medium|High`). Return `{ success:false, error }` on any
     validation failure — do not throw.
   - Look up the candidate by ID (reuse `getSheet_(SHEET_CANDIDATES)`
     lookup pattern already used in `api_updateCandidateStatus`) to get
     `CandidateName` and confirm the candidate exists; if not found,
     return `{ success:false, error:'Candidate not found.' }`.
   - Build the Calendar event via `CalendarApp`:
     - If `eventTime` provided → `calendar.createEvent(title, startDate, endDate)`
       with a sensible default duration (30 minutes) unless a longer
       duration is meaningful for the event type.
     - If `eventTime` omitted → `calendar.createAllDayEvent(title, date)`.
     - Set the event description to include: candidate name, candidate
       status, and the free-text description field, so opening the event
       directly in Google Calendar gives full context without opening the
       app.
     - Add a reminder via `event.addPopupReminder(reminderMinutesBefore)`
       and `event.addEmailReminder(reminderMinutesBefore)` so both
       browser/mobile popup and email notifications are covered.
   - Append a new row to `tbl_Events` with the returned
     `event.getId()` and `event.getHtmlLink()` (wrap `getHtmlLink()` in
     try/catch — it can be unavailable depending on calendar sharing/ACL;
     fall back to empty string, never fail the whole operation over it).
   - Call `api_writeLog_(candidateId, actor, 'Calendar Event Created: ' + title)`.
   - **[CACHE POLICY]** Call `CacheService.getScriptCache().remove('dashboard_data')`
     before returning (new dashboard cards depend on event data — see
     CHANGE 5).
   - Return `{ success:true, eventId, calendarEventId, calendarLink }`.

3. **`api_getEventsByCandidate(candidateId)`**
   - Read-only, no role check (matches `api_getDocumentsByCandidate`).
   - Return `{ success:true, data: [...] }` — all `tbl_Events` rows for
     that candidate, sorted by `EventDate` ascending.

4. **`api_getAllUpcomingEvents()`**
   - Read-only, no role check (matches `api_getAllDocuments`).
   - Returns ALL rows from `tbl_Events` where `Status === 'Active'`
     (used by both the new Calendar view and the new dashboard cards).
   - `{ success:true, data: [...] }`.

5. **`api_updateCalendarEvent(eventId, updates)`**
   - `requireRole_(['Admin', 'HR', 'Coordinator'])`.
   - `updates` may include: `title`, `description`, `eventDate`,
     `eventTime`, `priority`, `reminderMinutesBefore`.
   - Update the underlying Google Calendar event via
     `CalendarApp.getEventById(GoogleCalendarEventId)` (guard: if the
     Calendar event was deleted directly in Google Calendar, catch the
     error, log it, and still update the Sheet row so the app doesn't
     hard-fail — but return a `warning` field in the response so the UI
     can surface it).
   - Update the matching `tbl_Events` row (`UpdatedAt` = now).
   - `api_writeLog_(...)` → `'Calendar Event Updated: ' + title`.
   - **[CACHE POLICY]** invalidate `dashboard_data`.

6. **`api_deleteCalendarEvent(eventId)`**
   - `requireRole_(['Admin', 'HR'])` (stricter than update — deletion is
     destructive, matches the general pattern of restricting deletes to
     senior roles).
   - Delete the Google Calendar event (`event.deleteEvent()`), guarded by
     try/catch (already-deleted events should not fail the operation).
   - Remove the row from `tbl_Events` (or set `Status = 'Cancelled'` —
     **prefer soft-delete**: set `Status = 'Cancelled'` instead of
     removing the row, so the Audit Log / history stays intact, matching
     the project's existing "soft-rename instead of delete" pattern used
     for re-uploaded documents in `DriveManager.js`).
   - `api_writeLog_(...)` → `'Calendar Event Cancelled: ' + title`.
   - **[CACHE POLICY]** invalidate `dashboard_data`.

7. **`api_markEventCompleted(eventId)`**
   - `requireRole_(['Admin', 'HR', 'Coordinator'])`.
   - Set `Status = 'Completed'`, `UpdatedAt` = now. Do NOT delete the
     Google Calendar event (keep it as a historical record — Calendar
     itself will just show it as a past event).
   - `api_writeLog_(...)` → `'Calendar Event Completed: ' + title`.
   - **[CACHE POLICY]** invalidate `dashboard_data`.

---

## CHANGE 5 — Dashboard KPI Extension (`Code.js`)

Extend `api_getDashboardData()` (same function, same cache key/policy —
do not create a second cache key) to also compute, from
`api_getAllUpcomingEvents()`:

- `eventsToday` — Active events where `EventDate === today`.
- `eventsTomorrow` — Active events where `EventDate === tomorrow`.
- `eventsThisWeek` — Active events within the next 7 days (inclusive of
  today).
- `eventsOverdue` — Active events where `EventDate < today`.
- `eventsHighPriority` — Active events where `Priority === 'High'` and
  `EventDate >= today`.

Add these to the returned `data` object. This keeps ONE dashboard
aggregator and ONE cache key, consistent with the existing
"single source of truth" comment block already at the top of `Code.js`.

---

## FRONTEND REQUIREMENTS (`Script.html`)

1. **Sidebar** — add to `sidebar_items`:
   ```js
   { view: 'calendar', icon: '📅', label: 'Calendar',
     badge: () => Views._upcomingCount ?? '' }