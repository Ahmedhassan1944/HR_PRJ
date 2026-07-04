# TASK: Redesign the Calendar page as a real Month Grid (like a classic wall calendar)

## Goal

Keep ALL current Calendar functionality exactly as it is today (loading events,
quick filters, event cards, "Mark Completed", "Schedule Event", links to
Google Calendar — none of that changes). The only thing to change is the
**layout/visual design** of the Calendar page: replace the current
"list only" layout with a **traditional month grid** (Sun→Sat columns, one
row per week, day-of-month numbers, small dots showing which days have
events, previous/next month navigation) — similar to a normal wall/desk
calendar. Clicking a day shows that day's events in a panel next to the
grid, reusing the existing event-card list you already have.

This is a **frontend-only** change (`Script.html` + `Styles.html`). No
backend / `.js` file changes are needed for this task.

---

## STEP 1 — `Styles.html`: add the month-grid CSS

Find this existing block near the end of the file:

```css
.calendar-grid {
  display: grid;
  grid-template-columns: 1fr;
  gap: var(--sp-4);
}
@media (min-width: 1024px) {
  .calendar-grid { grid-template-columns: 2fr 1fr; }
}

.calendar-list {
  display: flex;
  flex-direction: column;
}
```

Keep it as-is, and ADD this new block right after it (before `.calendar-filters`):

```css
/* ── Month Grid Calendar ─────────────────────────────────────── */
.month-calendar {
  background: var(--bg-surface);
  border: 1px solid var(--border);
  border-radius: var(--radius-lg);
  overflow: hidden;
  box-shadow: var(--shadow-sm);
  height: fit-content;
}

.month-calendar__header {
  display: flex;
  align-items: center;
  gap: var(--sp-2);
  padding: var(--sp-3) var(--sp-4);
  border-bottom: 1px solid var(--border);
}

.month-calendar__label {
  flex: 1;
  text-align: center;
  font-size: 1.1rem;
  font-weight: 700;
  color: var(--text-primary);
}

.month-calendar__today-btn { margin-left: var(--sp-2); }

.month-calendar__weekdays {
  display: grid;
  grid-template-columns: repeat(7, 1fr);
  background: var(--bg-sidebar);
}

.month-calendar__weekday {
  text-align: center;
  padding: var(--sp-2) 4px;
  font-size: .72rem;
  font-weight: 700;
  letter-spacing: .04em;
  color: var(--text-inverse);
  text-transform: uppercase;
}

.month-calendar__days {
  display: grid;
  grid-template-columns: repeat(7, 1fr);
}

.month-calendar__day {
  min-height: 84px;
  border-right: 1px solid var(--border);
  border-bottom: 1px solid var(--border);
  padding: 6px;
  cursor: pointer;
  transition: background var(--ease);
  display: flex;
  flex-direction: column;
  gap: 4px;
}
.month-calendar__day:nth-child(7n) { border-right: none; }
.month-calendar__day:hover { background: var(--bg-hover); }

.month-calendar__day-num {
  font-size: .82rem;
  font-weight: 600;
  color: var(--text-primary);
}

.month-calendar__day--muted { background: var(--bg-body); cursor: default; }
.month-calendar__day--muted:hover { background: var(--bg-body); }
.month-calendar__day--muted .month-calendar__day-num { color: var(--text-muted); }

.month-calendar__day--today .month-calendar__day-num {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 22px; height: 22px;
  border-radius: 50%;
  background: var(--primary);
  color: #fff;
}

.month-calendar__day--has-events { background: var(--primary-light); }
.month-calendar__day--has-events:hover { background: var(--primary-light); filter: brightness(.97); }

.month-calendar__day--selected {
  background: var(--primary) !important;
}
.month-calendar__day--selected .month-calendar__day-num { color: #fff; }
.month-calendar__day--selected.month-calendar__day--today .month-calendar__day-num {
  background: #fff; color: var(--primary);
}

.month-calendar__dots {
  display: flex;
  flex-wrap: wrap;
  gap: 3px;
  align-items: center;
}

.month-calendar__dot {
  width: 7px; height: 7px;
  border-radius: 50%;
  flex-shrink: 0;
}
.month-calendar__dot--low    { background: var(--success); }
.month-calendar__dot--medium { background: var(--warning); }
.month-calendar__dot--high   { background: var(--danger); }

.month-calendar__more {
  font-size: .65rem;
  font-weight: 700;
  color: var(--text-secondary);
}
.month-calendar__day--selected .month-calendar__more { color: #fff; }

.calendar-agenda__title {
  font-size: .9rem;
  font-weight: 700;
  color: var(--text-primary);
  margin: var(--sp-3) 0 var(--sp-2);
}

@media (max-width: 640px) {
  .month-calendar__day { min-height: 56px; }
}
```

---

## STEP 2 — `Script.html`: change the Calendar page markup

Find this block inside the `calendar(container)` function:

```html
      <div class="calendar-grid">
        <div class="calendar-list" id="calendar-event-list">
          <div class="loading-overlay"><div class="spinner spinner--dark"></div>Loading upcoming events…</div>
        </div>
        <div class="calendar-sidebar">
           <div class="kpi-card kpi-card--blue">
             <div class="kpi-card__label">Active Events</div>
             <div class="kpi-card__value" id="cal-kpi-active">--</div>
             <div class="kpi-card__icon" aria-hidden="true">📅</div>
           </div>
        </div>
      </div>`;
```

Replace it with:

```html
      <div class="calendar-grid">
        <div class="month-calendar" id="month-calendar"></div>
        <div class="calendar-sidebar">
           <div class="kpi-card kpi-card--blue">
             <div class="kpi-card__label">Active Events</div>
             <div class="kpi-card__value" id="cal-kpi-active">--</div>
             <div class="kpi-card__icon" aria-hidden="true">📅</div>
           </div>
           <div class="calendar-agenda__title" id="calendar-agenda-title">Upcoming Events</div>
           <div class="calendar-list" id="calendar-event-list">
             <div class="loading-overlay"><div class="spinner spinner--dark"></div>Loading upcoming events…</div>
           </div>
        </div>
      </div>`;
```

---

## STEP 3 — `Script.html`: initialize/reset the grid when the page loads

Find the start of the `calendar(container)` function's try block:

```js
      try {
        const res = await GAS.call('api_getAllUpcomingEvents');
        if (res.success) {
          App.setState({ calendarEvents: res.data });
          Views._upcomingCount = res.data.length;
          renderSidebar(); // update badge
          
          document.getElementById('cal-kpi-active').textContent = res.data.length;
          
          const initialFilter = App.state.filter || 'All';
          const btn = document.querySelector(`button[data-cal-filter="${initialFilter}"]`);
          Views._applyCalendarFilter(initialFilter, btn);
        } else {
          throw new Error(res.error);
        }
      } catch (err) {
        Toast.error('Failed to load events.');
        document.getElementById('calendar-event-list').innerHTML = `<div class="table-empty"><div class="table-empty__icon">⚠️</div>Failed to load events: ${escHtml(err.message)}</div>`;
      }
    },
```

Replace it with:

```js
      Views._calendarCursor = new Date();
      Views._calendarSelectedDate = null;

      try {
        const res = await GAS.call('api_getAllUpcomingEvents');
        if (res.success) {
          App.setState({ calendarEvents: res.data });
          Views._upcomingCount = res.data.length;
          renderSidebar(); // update badge
          
          document.getElementById('cal-kpi-active').textContent = res.data.length;
          
          Views._renderMonthCalendar();
          
          const initialFilter = App.state.filter || 'All';
          const btn = document.querySelector(`button[data-cal-filter="${initialFilter}"]`);
          Views._applyCalendarFilter(initialFilter, btn);
        } else {
          throw new Error(res.error);
        }
      } catch (err) {
        Toast.error('Failed to load events.');
        document.getElementById('calendar-event-list').innerHTML = `<div class="table-empty"><div class="table-empty__icon">⚠️</div>Failed to load events: ${escHtml(err.message)}</div>`;
      }
    },
```

---

## STEP 4 — `Script.html`: make quick filters deselect the grid day

Find the start of `_applyCalendarFilter`:

```js
    _applyCalendarFilter(filterName, btnEl) {
      if (btnEl) {
        document.querySelectorAll('.quick-filter-btn').forEach(b => b.classList.remove('quick-filter-btn--active'));
        btnEl.classList.add('quick-filter-btn--active');
      } else {
        document.querySelectorAll('.quick-filter-btn').forEach(b => {
          if (b.dataset.calFilter === filterName) b.classList.add('quick-filter-btn--active');
          else b.classList.remove('quick-filter-btn--active');
        });
      }
```

Replace it with:

```js
    _applyCalendarFilter(filterName, btnEl) {
      Views._calendarSelectedDate = null;
      if (document.getElementById('month-calendar')) Views._renderMonthCalendar();
      const agendaTitleEl = document.getElementById('calendar-agenda-title');
      if (agendaTitleEl) agendaTitleEl.textContent = 'Upcoming Events';

      if (btnEl) {
        document.querySelectorAll('.quick-filter-btn').forEach(b => b.classList.remove('quick-filter-btn--active'));
        btnEl.classList.add('quick-filter-btn--active');
      } else {
        document.querySelectorAll('.quick-filter-btn').forEach(b => {
          if (b.dataset.calFilter === filterName) b.classList.add('quick-filter-btn--active');
          else b.classList.remove('quick-filter-btn--active');
        });
      }
```

---

## STEP 5 — `Script.html`: add the new grid-rendering functions

Find `_renderEventList(events, containerId, ...)` (it comes right after
`_applyCalendarFilter`). Add the following NEW functions right BEFORE
`_renderEventList`, inside the `Views` object:

```js
    _renderMonthCalendar() {
      const el = document.getElementById('month-calendar');
      if (!el) return;

      const cursor = Views._calendarCursor || (Views._calendarCursor = new Date());
      const year = cursor.getFullYear();
      const month = cursor.getMonth();
      const monthLabel = cursor.toLocaleDateString('en-US', { month: 'long', year: 'numeric' });

      const firstDay = new Date(year, month, 1);
      const startOffset = firstDay.getDay();
      const daysInMonth = new Date(year, month + 1, 0).getDate();
      const daysInPrevMonth = new Date(year, month, 0).getDate();

      const today = new Date();
      today.setHours(0, 0, 0, 0);

      const events = App.state.calendarEvents || [];
      const eventsByDay = {};
      events.forEach(e => {
        const key = e.EventDate;
        if (!key) return;
        if (!eventsByDay[key]) eventsByDay[key] = [];
        eventsByDay[key].push(e);
      });

      const weekDays = ['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'];
      let cellsHtml = '';

      for (let i = startOffset - 1; i >= 0; i--) {
        const d = daysInPrevMonth - i;
        cellsHtml += `<div class="month-calendar__day month-calendar__day--muted"><div class="month-calendar__day-num">${d}</div></div>`;
      }

      for (let d = 1; d <= daysInMonth; d++) {
        const dateObj = new Date(year, month, d);
        const dateKey = `${year}-${String(month + 1).padStart(2, '0')}-${String(d).padStart(2, '0')}`;
        const dayEvents = eventsByDay[dateKey] || [];
        const isToday = dateObj.getTime() === today.getTime();
        const isSelected = Views._calendarSelectedDate === dateKey;

        let dotsHtml = '';
        if (dayEvents.length > 0) {
          const shown = dayEvents.slice(0, 3);
          dotsHtml = `<div class="month-calendar__dots">` +
            shown.map(e => `<span class="month-calendar__dot month-calendar__dot--${(e.Priority || 'medium').toLowerCase()}" title="${escHtml(e.Title)}"></span>`).join('') +
            (dayEvents.length > 3 ? `<span class="month-calendar__more">+${dayEvents.length - 3}</span>` : '') +
            `</div>`;
        }

        cellsHtml += `
          <div class="month-calendar__day ${isToday ? 'month-calendar__day--today' : ''} ${dayEvents.length ? 'month-calendar__day--has-events' : ''} ${isSelected ? 'month-calendar__day--selected' : ''}"
               onclick="Views._selectCalendarDay('${dateKey}')">
            <div class="month-calendar__day-num">${d}</div>
            ${dotsHtml}
          </div>`;
      }

      const totalCells = startOffset + daysInMonth;
      const trailing = totalCells % 7 === 0 ? 0 : 7 - (totalCells % 7);
      for (let d = 1; d <= trailing; d++) {
        cellsHtml += `<div class="month-calendar__day month-calendar__day--muted"><div class="month-calendar__day-num">${d}</div></div>`;
      }

      el.innerHTML = `
        <div class="month-calendar__header">
          <button class="btn btn--icon btn--outline" onclick="Views._calNavigate(-1)" aria-label="Previous month">‹</button>
          <div class="month-calendar__label">${monthLabel}</div>
          <button class="btn btn--icon btn--outline" onclick="Views._calNavigate(1)" aria-label="Next month">›</button>
          <button class="btn btn--outline btn--sm month-calendar__today-btn" onclick="Views._calGoToday()">Today</button>
        </div>
        <div class="month-calendar__weekdays">
          ${weekDays.map(w => `<div class="month-calendar__weekday">${w}</div>`).join('')}
        </div>
        <div class="month-calendar__days">
          ${cellsHtml}
        </div>
      `;
    },

    _calNavigate(delta) {
      const c = Views._calendarCursor || new Date();
      Views._calendarCursor = new Date(c.getFullYear(), c.getMonth() + delta, 1);
      Views._renderMonthCalendar();
    },

    _calGoToday() {
      Views._calendarCursor = new Date();
      Views._calendarSelectedDate = null;
      Views._renderMonthCalendar();
      const agendaTitleEl = document.getElementById('calendar-agenda-title');
      if (agendaTitleEl) agendaTitleEl.textContent = 'Upcoming Events';
      const initialFilter = App.state.filter || 'All';
      const btn = document.querySelector(`button[data-cal-filter="${initialFilter}"]`);
      Views._applyCalendarFilter(initialFilter, btn);
    },

    _selectCalendarDay(dateKey) {
      Views._calendarSelectedDate = (Views._calendarSelectedDate === dateKey) ? null : dateKey;
      Views._renderMonthCalendar();

      document.querySelectorAll('.quick-filter-btn').forEach(b => b.classList.remove('quick-filter-btn--active'));

      const agendaTitleEl = document.getElementById('calendar-agenda-title');
      const all = App.state.calendarEvents || [];

      if (Views._calendarSelectedDate) {
        const dayEvents = all
          .filter(e => e.EventDate === dateKey)
          .sort((a, b) => (a.EventTime || '').localeCompare(b.EventTime || ''));
        const [y, m, d] = dateKey.split('-').map(Number);
        const label = new Date(y, m - 1, d).toLocaleDateString('en-GB', { weekday: 'long', day: '2-digit', month: 'long' });
        if (agendaTitleEl) agendaTitleEl.textContent = `Events on ${label}`;
        Views._renderEventList(dayEvents, 'calendar-event-list', 'No events scheduled for this day.');
      } else {
        if (agendaTitleEl) agendaTitleEl.textContent = 'Upcoming Events';
        const initialFilter = App.state.filter || 'All';
        const btn = document.querySelector(`button[data-cal-filter="${initialFilter}"]`);
        Views._applyCalendarFilter(initialFilter, btn);
      }
    },

```

**Important:** `_selectCalendarDay` calls `Views._applyCalendarFilter`, and
`_applyCalendarFilter` (Step 4) resets `Views._calendarSelectedDate` and
re-renders the grid — this is intentional two-way sync between the grid
and the quick filters, do not remove either side.

---

## VERIFICATION

1. Redeploy as a **new version**, hard-refresh the web app.
2. Open the Calendar page — you should now see a real month grid (like a
   wall calendar) with the current month, weekday headers, and today's
   date highlighted.
3. Days that have events show small colored dots (green = Low priority,
   yellow = Medium, red = High).
4. Click ‹ / › to move between months — the grid updates, dots still show
   correctly for the events in that month.
5. Click "Today" to jump back to the current month.
6. Click on any day with a dot — the panel on the side shows that day's
   events as the usual event cards (same "Mark Completed" / GCal link
   buttons as before). Click the same day again to go back to the full
   upcoming list.
7. Click a quick filter (Today / This Week / Overdue / etc.) — it still
   works exactly as before, and deselects any day you had picked in the
   grid.
8. Confirm nothing broke on the candidate detail page's "Follow-up
   Events" section (it does not use the grid, only the event-card list —
   it should be untouched).
