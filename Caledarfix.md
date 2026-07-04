# TASK: Fix Calendar "Today" / "Tomorrow" filters showing no events

## Root cause
In `Script.html`, `_applyCalendarFilter()` compares dates like this:

```js
const today = new Date();
today.setHours(0,0,0,0);
...
filtered = all.filter(e => {
  const d = new Date(e.EventDate);
  return d.getTime() === today.getTime();
});
```

`e.EventDate` is a plain string like `"2026-07-05"`. When you do
`new Date("2026-07-05")`, JavaScript treats date-only strings as **UTC
midnight**. But `today`/`tomorrow` are built with `new Date()` +
`setHours(0,0,0,0)`, which is **local midnight**.

In any timezone ahead of UTC (e.g. Oman is UTC+4), these two values are
several hours apart, so `.getTime()` is never exactly equal — the "Today"
and "Tomorrow" filters compare timestamps that can never match, even
though the events genuinely exist on that date. This is why the list came
back empty.

## Fix — `Script.html`

Find `_applyCalendarFilter(filterName, btnEl) {` and replace the whole
date-filtering block with a version that compares plain `YYYY-MM-DD`
strings instead of `Date` objects (avoids all timezone parsing issues):

Find:

```js
      const all = App.state.calendarEvents || [];
      const today = new Date();
      today.setHours(0,0,0,0);
      const tomorrow = new Date(today);
      tomorrow.setDate(tomorrow.getDate() + 1);
      const nextWeek = new Date(today);
      nextWeek.setDate(nextWeek.getDate() + 7);

      let filtered = all;
      
      if (filterName === 'Today') {
        filtered = all.filter(e => {
          const d = new Date(e.EventDate);
          return d.getTime() === today.getTime();
        });
      } else if (filterName === 'Tomorrow') {
         filtered = all.filter(e => {
          const d = new Date(e.EventDate);
          return d.getTime() === tomorrow.getTime();
        });
      } else if (filterName === 'ThisWeek') {
         filtered = all.filter(e => {
          const d = new Date(e.EventDate);
          return d >= today && d <= nextWeek;
        });
      } else if (filterName === 'Overdue') {
         filtered = all.filter(e => {
          const d = new Date(e.EventDate);
          return d < today;
        });
      } else if (filterName === 'HighPriority') {
         filtered = all.filter(e => e.Priority === 'High');
      }
      
      // Sort chronologically
      filtered.sort((a,b) => new Date(a.EventDate) - new Date(b.EventDate));
```

Replace with:

```js
      const all = App.state.calendarEvents || [];

      // Build local YYYY-MM-DD strings — avoids UTC-vs-local timezone
      // mismatches that happen when comparing Date objects parsed from
      // date-only strings (e.g. "2026-07-05" parses as UTC midnight).
      const toKey = (d) => {
        const y = d.getFullYear();
        const m = String(d.getMonth() + 1).padStart(2, '0');
        const day = String(d.getDate()).padStart(2, '0');
        return `${y}-${m}-${day}`;
      };

      const now = new Date();
      const todayKey = toKey(now);
      const tomorrowDate = new Date(now);
      tomorrowDate.setDate(tomorrowDate.getDate() + 1);
      const tomorrowKey = toKey(tomorrowDate);
      const nextWeekDate = new Date(now);
      nextWeekDate.setDate(nextWeekDate.getDate() + 7);
      const nextWeekKey = toKey(nextWeekDate);

      let filtered = all;

      if (filterName === 'Today') {
        filtered = all.filter(e => e.EventDate === todayKey);
      } else if (filterName === 'Tomorrow') {
        filtered = all.filter(e => e.EventDate === tomorrowKey);
      } else if (filterName === 'ThisWeek') {
        filtered = all.filter(e => e.EventDate >= todayKey && e.EventDate <= nextWeekKey);
      } else if (filterName === 'Overdue') {
        filtered = all.filter(e => e.EventDate < todayKey);
      } else if (filterName === 'HighPriority') {
        filtered = all.filter(e => e.Priority === 'High');
      }

      // Sort chronologically (string comparison works fine for YYYY-MM-DD)
      filtered.sort((a, b) => a.EventDate.localeCompare(b.EventDate));
```

Because `EventDate` is always a normalized `"YYYY-MM-DD"` string (see
`normalizeEventDateString_` in `CalendarManager.js`), plain string
comparison (`===`, `<`, `>=`) sorts and matches correctly with zero
timezone ambiguity — no more `Date` parsing involved for the filtering
logic at all.

## Note — same class of bug may exist elsewhere
The month-grid calendar (`_renderMonthCalendar`) and the KPI card counts
(`eventsTomorrow`, computed on the backend) should be checked too if you
notice similar "off by one day" or "missing today's events" symptoms
later — but this fix resolves the specific "Tomorrow filter shows
nothing" issue you're hitting right now.

## Verification
1. Redeploy as a new version, hard-refresh.
2. Go to Calendar, click "Today" — confirm today's events show.
3. Click "Tomorrow" — confirm tomorrow's events show.
4. Click "This Week" and "Overdue" — confirm results still look correct.
