EEWPW LIVE DEPLOYMENT – CURRENT ISSUES SUMMARY (2026-05-03)

1. DATA_ROOT / LIVE DIRECTORY SETUP

Problem:
- data/ exists and is writable
- but subdirectories (e.g. data/live) may not be writable or may not exist
- leads to:
    mkdir ... Permission denied

Current workaround:
- manual: chmod -R a+rwx data

Required fix:
- make dirs must create:
    data/live
    data/live/raw
    data/live/archive
    data/live/state
- permissions must be repaired recursively
- users must not need to run chmod manually

Status:
- NOT fixed in deployment (manual workaround used)

---

2. PARSER-CHECK FAILURE (NON-BLOCKING)

Problem:
- make parser-check fails
- message:
    ERROR: eewpw-replay-log --help failed

Root cause:
- eewpw-replay-log --help returns non-zero exit code

Impact:
- parser installation actually succeeds
- but deployment looks broken

Status:
- NOT fixed
- does not block live mode

Future fix:
- fix parser CLI exit code
OR
- relax parser-check logic

---

3. LIVE PARSER SCRIPT (TEST-GROUND)

Current script:
- scripts/run_parser_on_live_logs.sh

Status:
- works correctly
- nohup-compatible
- cleans up child processes
- supports separate Finder / VS logs

Limitations (accepted for now):
- no restart recovery (starts at EOF)
- no log rotation handling
- no supervision (manual or nohup only)

---

4. PARSER ARCHITECTURE LIMITATION (IMPORTANT)

Observed behavior:
- parser does NOT persist offset
- restart → skips previously written data
- backend cannot recover missing data

Impact:
- data loss possible on restart

Status:
- known limitation
- NOT fixed
- acceptable for test phase

---

5. LIVE PIPELINE (CONFIRMED)

Actual data flow:

    log file
    → eewpw-parse-live
    → DATA_ROOT/live/raw/*.jsonl
    → backend live merge
    → DATA_ROOT/live/archive/live_merged_YYYY-MM-DD.json
    → backend indexing
    → frontend via /files

Status:
- working as designed

---

6. SCRIPT DESIGN CLEANUP (DONE)

Previous issue:
- mixed replay + live logic
- hardcoded paths

Current state:
- separate live-only script
- explicit paths
- no replay confusion

Status:
- resolved

---

7. LIVE DEPLOYMENT CONTRACT (MISSING)

Problem:
- parser is not part of deployment lifecycle
- no automatic start/restart
- no integration with system boot

Current approach:
- manual script + nohup

Future work:
- systemd or equivalent supervisor

Status:
- NOT implemented
- not required for test phase

---

PRIORITY

Fix now:
- make dirs must create and fix full live directory tree

Fix soon:
- parser-check false failure

Fix later:
- parser restart/offset persistence
- log rotation handling
- process supervision

---

CURRENT STATE

- live mode works
- parser is operational
- backend sees live data
- system is usable for real log testing

Remaining issues are:
- deployment polish
- parser robustness
- not blocking current test-ground usage