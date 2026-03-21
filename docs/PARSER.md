# EEWPW Parser Usage Guide

This document explains how to use the **eewpw-parser** toolkit alongside the EEWPW backend.  
The parser is **not** part of the backend container and is **not installed via docker-compose**.  
Instead, it is installed directly on the **host machine** and writes outputs to the same data
directory that the backend mounts as its DATA_ROOT.

## 1. Installation

Create a small virtual environment inside the deployment repository:

```bash
cd eewpw-deploy
python3 -m venv tools/parser-venv
source tools/parser-venv/bin/activate
pip install --upgrade pip
pip install eewpw-parser
```

This installs the CLI tools:

- `eewpw-parse`  
- `eewpw-parse-live`  
- `eewpw-replay-log`

All commands will be located in:

```
tools/parser-venv/bin/
```

## 2. Directory Layout

The backend mounts its data directory:

```
eewpw-deploy/
  data/
    backend/          ← backend DATA_ROOT
```

The parser should write outputs here as well:

- Offline parsed JSON → `data/backend/files/`
- Live mode JSONL     → `data/backend/live/raw/<algo>/YYYY-MM-DD_<algo>.jsonl`
- Live merged JSON     → `data/backend/live/archive/`

The backend indexes everything under `data/backend`.

## 3. Offline Parsing

To parse a log file offline into a complete EEWPW JSON:

```bash
tools/parser-venv/bin/eewpw-parse \
  --algo finder \
  --dialect scfinder \
  --output data/backend/files/finder_offline.json \
  /path/to/finder.log
```

You may then index the file using the backend’s `/files` endpoint.

## 4. Live Parsing (Real Logs)

To tail a live log file and continuously write JSONL into the backend data directory:

```bash
tools/parser-venv/bin/eewpw-parse-live \
  --algo vs \
  --dialect scvsmag \
  --logfile /var/log/eew/vs.log \
  --data-root data/backend \
  --instance vs@prod \
  --poll-interval 0.2
```

This produces:

```
data/backend/live/raw/vs/YYYY-MM-DD_vs.jsonl
```

The backend’s scheduled merge job will convert these into:

```
data/backend/live/archive/live_merged_YYYY-MM-DD.json
```

## 5. Generating Synthetic Long Logs

For replay/testing, use:

```bash
tools/parser-venv/bin/eewpw-replay-log \
  --speed 0 \
  --repeat 20 \
  /path/to/finder.log
```

This repeats the file 20 times and adjusts timestamps so the log appears continuous.
Useful for stress testing and validating LIVE mode end‑to‑end.

## 6. Recommended Workflow

1. **Start backend + frontend** with docker-compose.
2. **Install parser** in `tools/parser-venv/` on host.
3. **Run offline** or **live parsing** pointing to `data/backend`.
4. Backend automatically indexes and exposes the results.

Parser remains a **host-only tool** to keep backend images clean and allow users
to parse logs completely offline without Docker.

---

This document may be expanded as additional algorithms and parser features are added.
