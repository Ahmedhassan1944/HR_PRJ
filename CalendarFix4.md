# TASK: Fix "evt.EventDate.split is not a function" (Dashboard cards + Calendar)

## Root cause

`EventDate` is written to the `tbl_Events` sheet as a plain string like
`"2026-07-10"`. Google Sheets automatically detects text that looks like a
date and silently converts the cell to a real `Date` value. So when the
code reads it back with `sheet.getDataRange().getValues()`, `EventDate` is
a JavaScript `Date` object, not a string — and any code that does
`evt.EventDate.split('-')` throws:

```
TypeError: evt.EventDate.split is not a function
```

This breaks `api_getDashboardData` entirely (because the calendar-counters
loop throws inside it), which is why **all four dashboard cards** show the
same failure — they all come from one shared API call. The same
`.split('-')` assumption also exists in the event-update flow, which is
part of why the standalone Calendar/candidate-events problems have been
lingering.

## Fix — add one shared helper, then use it in 3 places

### 1. Add this helper function in `CalendarManager.js` (near the top, after `APP_CALENDAR_NAME`)

```js
/**
 * Normalizes a sheet EventDate value (which may be a real Date object
 * if Sheets auto-converted it, or a plain string) into a consistent
 * 'YYYY-MM-DD' string.
 */
function normalizeEventDateString_(value) {
  if (!value) return '';
  if (value instanceof Date) {
    const y = value.getFullYear();
    const m = String(value.getMonth() + 1).padStart(2, '0');
    const d = String(value.getDate()).padStart(2, '0');
    return `${y}-${m}-${d}`;
  }
  return String(value);
}
```

### 2. Use it in `api_getEventsByCandidate` and `api_getAllUpcomingEvents` in `CalendarManager.js`

In both functions, find this block (appears in each):

```js
      .map(row => {
        const obj = {};
        headers.forEach((h, i) => obj[h] = row[i]);
        return obj;
      })
```

Replace with:

```js
      .map(row => {
        const obj = {};
        headers.forEach((h, i) => obj[h] = row[i]);
        obj.EventDate = normalizeEventDateString_(obj.EventDate);
        return obj;
      })
```

This guarantees every event object sent to the client (and used inside
`api_getDashboardData`) always has `EventDate` as a clean `'YYYY-MM-DD'`
string — fixing the dashboard cards, the Calendar page, and the "edit
event" date field (which needs a string to prefill an `<input
type="date">` correctly).

### 3. Fix `Code.js` — the dashboard calendar-counters loop

Find:

```js
    activeEvents.forEach(evt => {
      if (!evt.EventDate) return;
      const [y, m, d] = evt.EventDate.split('-').map(Number);
      const evDate = new Date(y, m - 1, d);
```

This code is now safe as-is once step 2 is applied (EventDate will always
be a string by the time it reaches here) — **no change needed here**, but
double check after applying step 2 that this line still works. If you
want extra safety regardless of source, you may also wrap it:

```js
    activeEvents.forEach(evt => {
      const dateStr = normalizeEventDateString_(evt.EventDate);
      if (!dateStr) return;
      const [y, m, d] = dateStr.split('-').map(Number);
      const evDate = new Date(y, m - 1, d);
```

(This requires `normalizeEventDateString_` to be accessible from `Code.js`
— since all `.js` files in an Apps Script project share one global scope,
this works automatically as long as step 1 is applied in
`CalendarManager.js`.)

### 4. Fix `api_updateCalendarEvent` in `CalendarManager.js` (the lingering edit/reschedule bug)

Find:

```js
        let newDate = updates.eventDate || rowData[headers.indexOf('EventDate')];
        let newTime = updates.eventTime !== undefined ? updates.eventTime : rowData[headers.indexOf('EventTime')];
        
        const [year, month, day] = newDate.split('-').map(Number);
```

Replace with:

```js
        let newDate = normalizeEventDateString_(updates.eventDate || rowData[headers.indexOf('EventDate')]);
        let newTime = updates.eventTime !== undefined ? updates.eventTime : rowData[headers.indexOf('EventTime')];
        
        const [year, month, day] = newDate.split('-').map(Number);
```

This was silently broken any time someone tried to update an event
without changing its date (it would try to `.split()` the raw `Date`
object read from the sheet).

---

## VERIFICATION

1. Redeploy as a **new version** and hard-refresh the web app.
2. Open the Dashboard — all four cards (Pipeline Overview, Candidates
   WITH/MISSING Document, Follow-up Calendar) should load numbers, not
   "Failed to load" errors.
3. Open the Calendar page (sidebar) — event list should load normally.
4. Open a candidate with existing follow-up events — the "Follow-up
   Events" section should load without error.
5. Edit an existing event and save it WITHOUT changing its date — confirm
   it saves successfully (this was previously broken by the same bug).
6. Create a new event, confirm it still appears correctly with the right
   date on the Calendar page and dashboard.
