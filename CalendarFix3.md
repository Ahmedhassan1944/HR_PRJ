# TASK: Fix "res is null" error on Calendar page and candidate Events section

## ⚠️ FIRST — TRY THIS BEFORE CHANGING ANY CODE (very likely fixes it immediately)

`api_getAllUpcomingEvents` and `api_getEventsByCandidate` are BRAND NEW
server functions added by the Calendar feature. The `google.script.run`
bridge that the browser uses to call server functions is built from the
HTML page at the moment it loads — if the tab was already open (or the
browser served a cached copy of the page) from BEFORE the latest
deployment, the bridge does not know about these newly-added functions
yet, and calls to them can resolve with `null` instead of real data or a
proper error.

**Do a full hard reload of the web app URL (Ctrl+Shift+R / Cmd+Shift+R),
or close the tab and open the web app URL fresh, then retest the Calendar
page and "Add Event" flow.** If this alone fixes it, no code change is
needed for this part — just remember to hard-refresh after every future
redeployment.

---

## CODE FIX (do this regardless — makes future failures show a clear message instead of crashing)

### Problem
When `google.script.run`'s success handler is ever called with `null` or
`undefined` (stale bridge, network hiccup, or any other edge case), the
frontend code does `res.success` directly, which throws
`TypeError: can't access property "success", res is null` — a cryptic
crash instead of a helpful message.

### Fix — make `GAS.call()` itself guard against this, in `Script.html`

Find the `GAS.call` method:

```js
call(fnName, ...args) {
  return new Promise((resolve, reject) => {
    if (!this.isLive) {
      resolve(this._mockData(fnName, ...args));
      return;
    }
    let call = google.script.run
      .withSuccessHandler(resolve)
      .withFailureHandler(reject);
    call[fnName](...args);
  });
},
```

Replace it with a version that rejects (instead of resolving) when the
server returns nothing usable:

```js
call(fnName, ...args) {
  return new Promise((resolve, reject) => {
    if (!this.isLive) {
      resolve(this._mockData(fnName, ...args));
      return;
    }
    let call = google.script.run
      .withSuccessHandler((result) => {
        if (result === null || result === undefined) {
          reject(new Error(
            `No response from server for "${fnName}". This can happen right ` +
            `after a new deployment — try reloading the page.`
          ));
          return;
        }
        resolve(result);
      })
      .withFailureHandler(reject);
    call[fnName](...args);
  });
},
```

This makes EVERY `GAS.call(...)` site in the app automatically get a clear,
readable error message instead of a raw `TypeError` whenever this
condition happens again in the future — no other file needs to change.

---

## VERIFICATION

1. Hard-refresh the web app first and retest without any code change —
   confirm whether the Calendar page and "📅 Add Event" → event list both
   load correctly now.
2. Apply the `GAS.call` guard above regardless, redeploy as a **new
   version**, hard-refresh again, and confirm:
   - Calendar page (sidebar) loads the event list (or "No upcoming events
     found." if empty) — no crash.
   - Candidate detail page's "📅 Follow-up Events" section loads (or shows
     "No events scheduled for this candidate.") — no crash.
   - If you intentionally break something to test, the error now reads
     as a clear sentence (e.g. "No response from server for ...") instead
     of `can't access property "success", res is null`.
