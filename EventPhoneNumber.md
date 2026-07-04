# TASK: Make the phone number on event cards plain text (not a clickable link)

## Why
The previous fix made the phone number a `tel:` hyperlink. The user just
wants to double-click the number to select and copy it — a `tel:` link
intercepts the click and tries to open a dialer/calling app instead of
letting the browser do a normal text selection.

## Fix — `Script.html`

Find (inside `_renderEventList`, added in the previous task):

```js
            ${e.CandidatePhone ? `
            <div class="event-card__meta-item">
              <span>📞</span> <a href="tel:${escHtml(e.CandidatePhone)}">${escHtml(e.CandidatePhone)}</a>
            </div>` : ''}
```

Replace with:

```js
            ${e.CandidatePhone ? `
            <div class="event-card__meta-item">
              <span>📞</span> <span class="event-card__phone" title="Double-click to select, then copy">${escHtml(e.CandidatePhone)}</span>
            </div>` : ''}
```

## Add supporting CSS — `Styles.html`

Add near the other `.event-card` rules:

```css
.event-card__phone {
  user-select: all;
  -webkit-user-select: all;
  cursor: text;
}
```

`user-select: all` makes a single double-click (or even a single click in
some browsers) select the *entire* phone number in one go, instead of just
one word/segment of it, making copy-paste effortless. It's plain text now
— no link, no app switching, nothing happens on click except selecting the
text.

## Verification
1. Redeploy as a new version, hard-refresh.
2. Open an event card with a phone number, double-click the number.
3. Confirm: the whole number gets selected (not just part of it), no app
   opens, and Ctrl+C / right-click → Copy works normally.
