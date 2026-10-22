# Notes for working in this repo

- The main README carries a **Quick Scriptable install guide**. Its single source is `scriptable/QUICK_INSTALL.md`.
  Whenever a change affects how the Scriptable version is installed, updated or first used, edit that file, then run
  `python3 scripts/sync_readme.py` and commit the README. CI fails if the README copy is out of date.
- Scriptable checks: `cd scriptable && npm ci && npm run typecheck && npm test`.
- The Scriptable installer downloads from `main`, so changes only reach a phone after they are merged.
