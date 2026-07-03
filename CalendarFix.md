# TASK: Fix the broken "Follow-up Calendar" feature (commit `50d112aa`)

## ⚠️ WHAT HAPPENED
After the Calendar feature was implemented, the entire app went **blank /
stopped loading**. This is NOT a Google authorization/policy problem — it is
a **JavaScript syntax corruption** introduced in `Script.html` while writing
the new Calendar view code. This is a single-page app: ONE syntax error
anywhere in the inline `<script>` block prevents the ENTIRE script from
parsing, so nothing renders at all (blank white page). That matches exactly
what was observed.

## ⚠️ CRITICAL RULE FOR THIS FIX
Do NOT rewrite, redesign, or "improve" any of the Calendar feature's logic
or UI. The feature design is correct and should be preserved exactly as-is.
This is a surgical fix of a text-corruption bug only.

---

## ROOT CAUSE

While generating `Script.html`, every NEW JavaScript template literal
backtick (`` ` ``) inside the Calendar-related code was accidentally written
as the two-character sequence `\`` (backslash + backtick), and every
interpolation `${...}` was written as `\${...}` (backslash + dollar sign).

This is almost certainly a markdown/escaping artifact that leaked from the
generation process into the actual source file. Outside of a string, `` \` ``
is not valid JavaScript — it breaks the parser and the whole script fails
silently in the browser (blank page, no console-visible page content).

## WHERE TO LOOK

Search `Script.html` for the literal two-character sequences `` \` `` and
`` \$ `` in the region containing these Calendar functions on the `Views`
object (added by the Calendar feature):

- `Views.calendar(container)`
- `Views._applyCalendarFilter(filterName, btnEl)`
- `Views._renderEventList(events, containerId, noDataMsg)`
- `Views._openEventModal(candidateId)`

These four functions are the ONLY places in the file where this corruption
exists. Every other file (`Code.js`, `Database.js`, `CalendarManager.js`,
`Styles.html`) is syntactically fine — do not touch them for this fix.

## THE FIX

In each of the four functions above:
1. Replace every literal `` \` `` with a plain backtick `` ` ``.
2. Replace every literal `` \$ `` (when immediately followed by `{`) with a
   plain `$` — i.e. `` \${expr} `` → `` ${expr} `` so the interpolation
   actually runs instead of being printed as literal text.

Concretely, these are the exact corrupted lines to fix (search-and-replace
each one, preserving all surrounding code and indentation exactly):

1. In `calendar(container)`:
   - FIND: `` const btn = document.querySelector(\`button[data-cal-filter="\${initialFilter}"]\`); ``
   - REPLACE: `` const btn = document.querySelector(`button[data-cal-filter="${initialFilter}"]`); ``

2. In `_renderEventList(...)`:
   - FIND: `` el.innerHTML = \`<div class="table-empty"><div class="table-empty__icon">📅</div>\${noDataMsg}</div>\`; ``
   - REPLACE: `` el.innerHTML = `<div class="table-empty"><div class="table-empty__icon">📅</div>${noDataMsg}</div>`; ``

   - FIND the whole `return \`...\`;` block that builds the event card
     (from `` return \` `` through the closing `` </div>\`; ``) and replace
     EVERY `` \` `` with `` ` `` and every `` \${ `` with `` ${ `` inside it,
     including the nested ternary template literals for
     `GoogleCalendarLink` and the `Mark Completed` button. Do not change any
     other characters — this block's HTML/logic is correct, only the
     backslash artifacts need removing.

3. In `_openEventModal(candidateId)`:
   - FIND: `Modal.open(\`` → REPLACE: `` Modal.open(` ``
   - FIND: `` onsubmit="Views._submitEvent(event, '\${candidateId}')" `` →
     REPLACE: `` onsubmit="Views._submitEvent(event, '${candidateId}')" ``
   - FIND the closing `` \`); `` right after the modal footer's closing
     `</div>` → REPLACE with `` `); ``

## VERIFICATION (MANDATORY BEFORE FINISHING)

1. After fixing, re-read the four functions above end-to-end and confirm
   there is NO remaining `` \` `` or `` \$ `` anywhere in `Script.html`.
   Run a search for both sequences across the whole file — the count must
   be zero.
2. Open the app preview and confirm the page renders (not blank), the
   sidebar shows the "📅 Calendar" item, and the Dashboard shows the 5 new
   Calendar KPI cards (Upcoming Today / Tomorrow / This Week / Overdue /
   High Priority) without a blank screen or console errors.
3. Open the browser DevTools console and confirm there are zero JavaScript
   errors on initial load of every view (Dashboard, Candidates, Candidate
   Detail, Calendar, Audit Log).
4. Click "📅 Add Event" on a candidate detail page and confirm the modal
   opens correctly (this exercises the exact code that was broken).

---

## SECONDARY FIX (small correctness bug, unrelated to the crash)

In `CalendarManager.js`, `api_updateCalendarEvent`, this line silently drops
the "Candidate: X / Status: Y" header that `api_createCalendarEvent` puts in
every event's description:

```js
if (updates.description) {
   calEvent.setDescription(updates.description);
}
```

Fix it to preserve the same header format used at creation time, by
re-reading the candidate's current name/status (same lookup pattern used in
`api_createCalendarEvent`) and rebuilding the description as:

```js
if (updates.description !== undefined) {
  const candidateName = rowData[headers.indexOf('CandidateName')];
  // Re-fetch current status the same way api_createCalendarEvent does,
  // then rebuild the same "Candidate: X\nStatus: Y\n\n<description>" format
  // before calling calEvent.setDescription(...).
}
```

---

## OPTIONAL HARDENING (only if you have spare time — not required to fix the crash)

`getAppCalendar_()` in `CalendarManager.js` calls
`CalendarApp.createCalendar(...)` to create a brand-new dedicated calendar.
Creating calendars requires the full `calendar` OAuth scope, which some
Google Workspace domains restrict for internal/unreviewed apps via Admin
Console → Security → API Controls. If that ever surfaces as a real
authorization error for this domain, the safer long-term fix is to stop
creating a new calendar at runtime and instead:
- Default to `CalendarApp.getDefaultCalendar()` (the deploying user's own
  calendar), OR
- Let an admin manually create the "HR Mobilization — Follow-ups" calendar
  once and paste its ID into a Script Property (`APP_CALENDAR_ID`), which
  `getAppCalendar_()` already checks first.

This is NOT the cause of the blank-page bug — do not implement this unless
the syntax fix above doesn't fully resolve the issue.
