# 🌙 PROMPT — Add Dark Mode Toggle (DOM Injection — Zero HTML Template Editing)

## ⚠️ CRITICAL RULES — READ BEFORE ANYTHING
- Make ALL 4 changes described below. Do not skip any.
- Do **NOT** edit any HTML inside backtick template literals (`` ` `` strings).
- Do **NOT** modify `renderSidebar`'s inner HTML template.
- Output **4 separate code blocks**, one per change. Nothing else — no explanation, no "Done", no summary.

---

## CONTEXT

This is `Script.html` from a Google Apps Script project.

The `App` object currently ends with `toggleSidebar()` as its **last method** (no comma after it):
```js
    toggleSidebar(forceState) {
      const isCollapsed = forceState !== undefined ? forceState : !this.state.sidebarCollapsed;
      this.setState({ sidebarCollapsed: isCollapsed });
      localStorage.setItem('hr_sidebar_collapsed', isCollapsed);
      const appEl = document.getElementById('app');
      if (appEl) {
        if (isCollapsed) appEl.classList.add('app--collapsed');
        else appEl.classList.remove('app--collapsed');
      }
    }
  };
```

The `renderSidebar()` function ends with a template literal assignment, then closes:
```js
    &copy; 2026
    </div>`;
  };

  // ─────────────────────────────────────────────
  // VIEW DISPATCHER
```

---

## CHANGE 1 — `Script.html`: Add `toggleDarkMode` and `_injectDarkBtn` to the `App` object

The button is injected via **pure DOM manipulation** — no HTML template is touched.

**FIND** (exact match — the closing of `toggleSidebar` and end of `App`):
```js
      if (appEl) {
        if (isCollapsed) appEl.classList.add('app--collapsed');
        else appEl.classList.remove('app--collapsed');
      }
    }
  };
```

**REPLACE WITH:**
```js
      if (appEl) {
        if (isCollapsed) appEl.classList.add('app--collapsed');
        else appEl.classList.remove('app--collapsed');
      }
    },

    toggleDarkMode() {
      const isDark = document.body.classList.toggle('dark-mode');
      localStorage.setItem('hr_dark_mode', isDark);
      const btn = document.getElementById('dark-mode-btn');
      if (btn) btn.textContent = isDark ? '☀️' : '🌙';
    },

    _injectDarkBtn() {
      if (document.getElementById('dark-mode-btn')) return; // already injected
      const footer = document.querySelector('.sidebar__footer');
      if (!footer) return;
      const btn     = document.createElement('button');
      btn.id        = 'dark-mode-btn';
      btn.className = 'dark-mode-btn';
      btn.title     = 'Toggle Dark / Light Mode';
      btn.setAttribute('aria-label', 'Toggle Dark Mode');
      btn.textContent = document.body.classList.contains('dark-mode') ? '☀️' : '🌙';
      btn.onclick     = () => App.toggleDarkMode();
      footer.insertBefore(btn, footer.firstChild);
    }
  };
```

> ⚠️ `toggleSidebar` now ends with `,` — `_injectDarkBtn` is the new last method (no comma).

---

## CHANGE 2 — `Script.html`: Initialize Dark Mode from localStorage + call `_injectDarkBtn` after sidebar renders

**FIND** (the 3 lines that bridge `renderSidebar` to the VIEW DISPATCHER section):
```js
    &copy; 2026
    </div>`;
  };

  // ─────────────────────────────────────────────
  // VIEW DISPATCHER
```

**REPLACE WITH:**
```js
    &copy; 2026
    </div>`;
  App._injectDarkBtn();
  };

  // ─────────────────────────────────────────────
  // VIEW DISPATCHER
```

> This single added line runs after every sidebar render and injects the button via DOM — no template literal is modified.

---

## CHANGE 3 — `Script.html`: Restore Dark Mode preference on page load

**FIND** (immediately after the `App` object `};` and before GAS BRIDGE):
```js
  };

  // ─────────────────────────────────────────────
  // GAS BRIDGE
```

**REPLACE WITH:**
```js
  };

  // ── Dark Mode: restore saved preference on page load ──
  if (localStorage.getItem('hr_dark_mode') === 'true') {
    document.body.classList.add('dark-mode');
  }

  // ─────────────────────────────────────────────
  // GAS BRIDGE
```

---

## CHANGE 4 — `Styles.html`: Add Dark Mode CSS

**FIND** the closing tag at the very end of `Styles.html`:
```css
</style>
```

**INSERT** the following block **immediately before** `</style>` (do not remove `</style>`):

```css
/* ══════════════════════════════════════════════
   DARK MODE
   ══════════════════════════════════════════════ */
body.dark-mode {
  --bg-body:        #141414;
  --bg-surface:     #1f1f1f;
  --bg-sidebar:     #0d0d0d;
  --bg-hover:       #2a2a2a;
  --text-primary:   #f3f2f1;
  --text-secondary: #c8c6c4;
  --text-muted:     #8a8886;
  --text-inverse:   #ffffff;
  --border:         #2d2d2d;
  --primary-light:  #00325a;
  --success-bg:     #0a2e0a;
  --warning-bg:     #2e1f00;
  --danger-bg:      #2e0a0c;
  --info-bg:        #001e38;
  --shadow-sm:      0 1px 3px rgba(0,0,0,.5),  0 1px 2px rgba(0,0,0,.4);
  --shadow:         0 4px 6px rgba(0,0,0,.4),  0 2px 4px rgba(0,0,0,.3);
  --shadow-lg:      0 10px 30px rgba(0,0,0,.5), 0 4px 10px rgba(0,0,0,.35);
  --shadow-card:    0 2px 8px rgba(0,0,0,.5);
  color-scheme: dark;
}

body.dark-mode .kpi-card        { filter: brightness(.88); }
body.dark-mode .modal__overlay  { background: rgba(0,0,0,.7); }
body.dark-mode .badge--closed   { background: #2a2a2a; color: var(--text-muted); }
body.dark-mode .filter-panel    { background: #1a1a1a; }

body.dark-mode input,
body.dark-mode select,
body.dark-mode textarea {
  background: #2a2a2a !important;
  color: var(--text-primary) !important;
  border-color: var(--border) !important;
}
body.dark-mode input::placeholder { color: var(--text-muted); }

body.dark-mode .dash-export-menu,
body.dark-mode #dash-export-menu {
  background: #1f1f1f;
  border-color: var(--border);
}
body.dark-mode .dash-export-item:hover { background: #2a2a2a; }

/* Dark mode toggle button */
.dark-mode-btn {
  display: block;
  width: 100%;
  padding: 8px 0;
  margin-bottom: 10px;
  background: rgba(255,255,255,.07);
  border: 1px solid rgba(255,255,255,.12);
  border-radius: var(--radius);
  color: var(--text-inverse);
  font-size: 1.25rem;
  cursor: pointer;
  text-align: center;
  transition: background .15s;
}
.dark-mode-btn:hover { background: rgba(255,255,255,.14); }
```

---

## MANDATORY OUTPUT FORMAT

Output exactly **4 code blocks** in this order — nothing else:

1. ` ```js ` — The modified closing of the `App` object (Change 1)
2. ` ```js ` — The `renderSidebar` closing + VIEW DISPATCHER (Change 2)
3. ` ```js ` — The Dark Mode init block (Change 3)
4. ` ```css ` — The Dark Mode CSS (Change 4)

---

## RISK TABLE

| # | File | Method | Risk |
|---|------|---------|------|
| 1 | `Script.html` | Add 2 methods to `App` — regular JS only | 🟢 Safe |
| 2 | `Script.html` | Add 1 line after template literal closes | 🟢 Safe |
| 3 | `Script.html` | Add 3 lines after `App` object | 🟢 Safe |
| 4 | `Styles.html` | Add CSS before `</style>` | 🟢 Safe |

**Zero HTML template literal modifications.**
