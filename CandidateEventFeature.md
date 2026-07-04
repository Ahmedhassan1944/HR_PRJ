# TASK: 3 improvements — event priority dots on Candidates/Dashboard, fix Time picker bug, show phone number on events

## PART 1 — Why the Time picker "has problems" (root cause found)

In `Styles.html`, the `.modal` popup uses a CSS `transform` for its slide-in
animation:

```css
.modal {
  ...
  transform: translateY(20px);
  transition: transform var(--ease);
}
.modal-overlay.open .modal { transform: translateY(0); }
```

Any element with a CSS `transform` becomes a new "containing block" for
things rendered relative to it — this is a well-known browser quirk where
**native `<input type="time">` / `<input type="date">` popup pickers can
appear clipped, mispositioned, or stop responding to clicks** when they're
inside an ancestor that has `transform` set. This exactly matches "I select
the time and I get problems." It's not a bug in your code's logic, it's this
one CSS property.

### Fix — replace `transform` with `margin-top` for the same slide-in effect

Find in `Styles.html`:

```css
  .modal {
    background: var(--bg-surface);
    border-radius: var(--radius-xl);
    box-shadow: var(--shadow-lg);
    width: 100%; max-width: 640px;
    max-height: 90vh; overflow-y: auto;
    transform: translateY(20px);
    transition: transform var(--ease);
  }

  .modal-overlay.open .modal { transform: translateY(0); }
```

Replace with:

```css
  .modal {
    background: var(--bg-surface);
    border-radius: var(--radius-xl);
    box-shadow: var(--shadow-lg);
    width: 100%; max-width: 640px;
    max-height: 90vh; overflow-y: auto;
    margin-top: 20px;
    transition: margin-top var(--ease);
  }

  .modal-overlay.open .modal { margin-top: 0; }
```

This keeps the same slide-in-on-open animation but no longer creates a
transformed containing block, so the native time/date pickers behave
normally everywhere they're used (Add Event modal, Edit Profile modal, etc.)

---

## PART 2 — Show priority dots (🔴🟡🟢) for each candidate on the Candidates page AND Dashboard table

Both the Dashboard's candidates table and the full Candidates page render
rows through the same shared function, `Views._candidateTableHtml(rows)` —
so we only need to change it once and it applies to both pages.

### Step 2.1 — `Script.html`: add a helper to build a CandidateID → priority map

Add this new function inside the `Views` object, right before
`_candidateTableHtml(rows) {`:

```js
    _buildEventDotsMap(events) {
      const rank = { High: 3, Medium: 2, Low: 1 };
      const map = {};
      (events || []).forEach(e => {
        if (e.Status !== 'Active') return;
        const cur = map[e.CandidateID];
        if (!cur || rank[e.Priority] > rank[cur]) {
          map[e.CandidateID] = e.Priority;
        }
      });
      return map;
    },

    _eventDotHtml(candidateId) {
      const p = (Views._candidateEventDots || {})[candidateId];
      if (!p) return '';
      const color = p === 'High' ? 'var(--danger)' : p === 'Medium' ? 'var(--warning)' : 'var(--success)';
      const label = `${p} priority upcoming event`;
      return `<span class="cand-event-dot" style="background:${color}" title="${label}" aria-label="${label}"></span>`;
    },

```

### Step 2.2 — `Script.html`: use the dot next to the candidate's name

Find (inside `_candidateTableHtml`):

```js
              <div>
                <div class="td-primary">${escHtml(c.FullName)}</div>
                <div class="td-secondary">${escHtml(c.Phone || '—')}</div>
```

Replace with:

```js
              <div>
                <div class="td-primary">${escHtml(c.FullName)} ${Views._eventDotHtml(c.CandidateID)}</div>
                <div class="td-secondary">${escHtml(c.Phone || '—')}</div>
```

### Step 2.3 — `Script.html`: populate the map on the Dashboard

Find:

```js
      try {
        const [kpiRes, candsRes] = await Promise.all([
          GAS.call('api_getDashboardData'),
          GAS.call('api_getAllCandidates')
        ]);
```

Replace with:

```js
      try {
        const [kpiRes, candsRes, eventsRes] = await Promise.all([
          GAS.call('api_getDashboardData'),
          GAS.call('api_getAllCandidates'),
          GAS.call('api_getAllUpcomingEvents')
        ]);

        if (eventsRes.success) {
          Views._candidateEventDots = Views._buildEventDotsMap(eventsRes.data);
        }
```

### Step 2.4 — `Script.html`: populate the map on the Candidates page

Find:

```js
    async _loadCandidates() {
      try {
        const res = await GAS.call('api_getAllCandidates');
        if (!res.success) throw new Error(res.error);
        App.setState({ candidates: res.data, filteredCandidates: res.data });
        // Render immediately (completeness cells will show "Loading…" state)
        Views._renderCandidatesTable(res.data);
        // Fire off batch completeness fetch in background
        Views._loadAllCompleteness(res.data);
```

Replace with:

```js
    async _loadCandidates() {
      try {
        const res = await GAS.call('api_getAllCandidates');
        if (!res.success) throw new Error(res.error);
        App.setState({ candidates: res.data, filteredCandidates: res.data });

        // Fetch upcoming events in the background to populate priority dots
        GAS.call('api_getAllUpcomingEvents').then(evRes => {
          if (evRes.success) {
            Views._candidateEventDots = Views._buildEventDotsMap(evRes.data);
            Views._renderCandidatesTable(App.state.filteredCandidates);
          }
        }).catch(() => {});

        // Render immediately (completeness cells will show "Loading…" state)
        Views._renderCandidatesTable(res.data);
        // Fire off batch completeness fetch in background
        Views._loadAllCompleteness(res.data);
```

### Step 2.5 — `Styles.html`: add the dot's CSS

Add this near the other `.month-calendar__dot` rules (Calendar Module Styles section):

```css
.cand-event-dot {
  display: inline-block;
  width: 8px;
  height: 8px;
  border-radius: 50%;
  margin-left: 4px;
  vertical-align: middle;
}
```

Now a candidate with an upcoming active event shows a small colored dot
right next to their name — red = High priority, yellow = Medium, green =
Low — on both the Dashboard's candidate table and the full Candidates
page. Hovering the dot shows a tooltip with the priority.

---

## PART 3 — Show the candidate's phone number on each event card (tap-to-call)

### Step 3.1 — `CalendarManager.js`: add a helper to look up phone numbers

Add this near the top of the file, after `normalizeEventDateString_`:

```js
/**
 * Returns a map of CandidateID -> Phone, for enriching event objects
 * with a contact number without duplicating data in tbl_Events.
 */
function getCandidatePhoneMap_() {
  const sheet = getSheet_(SHEET_CANDIDATES);
  const [headers, ...rows] = sheet.getDataRange().getValues();
  const idCol = headers.indexOf('CandidateID');
  const phoneCol = headers.indexOf('Phone');
  const map = {};
  rows.forEach(row => { map[row[idCol]] = row[phoneCol]; });
  return map;
}
```

### Step 3.2 — `CalendarManager.js`: attach the phone number in both event-fetching functions

In `api_getEventsByCandidate`, find:

```js
    const events = rows
      .filter(row => row[headers.indexOf('CandidateID')] === candidateId)
      .map(row => {
        const obj = {};
        headers.forEach((h, i) => obj[h] = row[i]);
        obj.EventDate = normalizeEventDateString_(obj.EventDate);
        return obj;
      })
      .sort((a, b) => new Date(a.EventDate) - new Date(b.EventDate));
```

Replace with:

```js
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
```

In `api_getAllUpcomingEvents`, find:

```js
    const events = rows
      .filter(row => row[headers.indexOf('Status')] === 'Active')
      .map(row => {
        const obj = {};
        headers.forEach((h, i) => obj[h] = row[i]);
        obj.EventDate = normalizeEventDateString_(obj.EventDate);
        return obj;
      });
```

Replace with:

```js
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
```

### Step 3.3 — `Script.html`: display the phone number as a tap/click-to-call link on the event card

Find (inside `_renderEventList`):

```js
          <div class="event-card__meta">
            <div class="event-card__meta-item">
              <span>📅</span> ${dateStr} ${e.EventTime ? 'at ' + e.EventTime : '(All Day)'}
            </div>
            ${e.GoogleCalendarLink ? `
            <div class="event-card__meta-item">
              <span>🔗</span> <a href="${e.GoogleCalendarLink}" target="_blank" rel="noopener">Open in GCal ↗</a>
            </div>` : ''}
          </div>
```

Replace with:

```js
          <div class="event-card__meta">
            <div class="event-card__meta-item">
              <span>📅</span> ${dateStr} ${e.EventTime ? 'at ' + e.EventTime : '(All Day)'}
            </div>
            ${e.CandidatePhone ? `
            <div class="event-card__meta-item">
              <span>📞</span> <a href="tel:${escHtml(e.CandidatePhone)}">${escHtml(e.CandidatePhone)}</a>
            </div>` : ''}
            ${e.GoogleCalendarLink ? `
            <div class="event-card__meta-item">
              <span>🔗</span> <a href="${e.GoogleCalendarLink}" target="_blank" rel="noopener">Open in GCal ↗</a>
            </div>` : ''}
          </div>
```

Now every event card (Calendar page, candidate detail's Follow-up Events
section) shows the candidate's phone number as a tappable `tel:` link — on
a phone this opens the dialer directly; on desktop it opens whatever app
is registered for `tel:` links (e.g. Google Voice, Skype).

---

## VERIFICATION

1. Redeploy as a **new version**, hard-refresh.
2. **Time picker**: open "Add Event" on any candidate, click the Time
   field, confirm the picker opens normally and the value saves/loads
   correctly. Try it a few times including changing it after opening.
3. **Priority dots**: create events with different priorities for a couple
   of candidates, then check the Dashboard's candidate table and the full
   Candidates page — confirm the colored dot appears next to the right
   candidates and matches their highest-priority active event. Candidates
   with no active events show no dot.
4. **Phone on events**: open the Calendar page and a candidate's
   Follow-up Events section — confirm each event card shows the phone
   number with a 📞 icon, and clicking it attempts to dial/call.
