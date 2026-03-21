# EEWPW Deployment

[![Backend Build](https://github.com/eewpw/eewpw-backend/actions/workflows/docker-backend.yml/badge.svg?branch=master)](https://github.com/eewpw/eewpw-backend/actions/workflows/docker-backend.yml)
[![Frontend Build](https://github.com/eewpw/eewpw-dashboard/actions/workflows/docker-frontend.yml/badge.svg?branch=master)](https://github.com/eewpw/eewpw-dashboard/actions/workflows/docker-frontend.yml)

> **Acknowledgment:** *Development of EEWPW is supported by the U.S. Geological Survey ShakeAlert project.*

## Summary

This repository is the **deployment entry point** for the *EEW Performance Workpackage (EEWPW)*. It does not contain application code; instead, it orchestrates pre-built Docker images as a runnable system.

The stack consists of a **dashboard** (the web interface you see in your browser), a **backend** service (handles data and communication behind the scenes), and **Redis** (used for caching to improve performance), all managed together via Docker Compose.

EEWPW workflows rely on input files produced by a standalone **eewpw-parser** module. While the parser is not part of this containerized stack, this repository provides support for installing and using it as host-side tooling.

## Prerequisites
#### [⬆Back to top](#eewpw-deployment)

Before starting the EEWPW stack, make sure your machine has the required tools installed.

You will need:
- **Git**
- **Docker** and the **Docker Compose plugin**
- **Python 3** (for parser workflows)
- **make** (required for running commands like `make up`, `make smoke`, and `make update`)

For detailed setup instructions (macOS, Linux, Windows, including WSL2 guidance), see [docs/PREREQUISITES.md](docs/PREREQUISITES.md)

---


## Installation
#### [⬆Back to top](#eewpw-deployment)

This section covers the full setup required to run EEWPW.  
It includes both the containerized stack and the parser tooling used to generate input data.

---

### Part 1: Start the EEWPW stack

1. Clone this repo and change your directory into it:
   ```bash
   git clone https://github.com/eewpw/eewpw.git
   cd eewpw
   ```

2. Copy `.env.example` to `.env`. This file contains the deployment settings used by the EEWPW stack.
   ```bash
   cp .env.example .env
   ```

3. Start the container stack
   ```bash
   make up
   ```
> *Note*: If pulling images fails (e.g. `unauthorized` or `denied`), log in to **GHCR** (GitHub Container Registry) using your GitHub credentials:
> ```bash
> docker login ghcr.io
> ```

4. Verify the installation:
   ```bash
   make smoke
   ```

   The expected output is:

   ```console
   $ make smoke
   ./scripts/smoke.sh
   [SMOKE] Backend /healthz 
   OK (200): {"ok":true,"redis_ok":true,"redis_detail":"PONG"}
   [SMOKE] Backend /status (optional)
   Skipped: /status not implemented (404)
   [SMOKE] Frontend reachability
   OK (200)
   [OK] Smoke tests passed.
   ```

   Then open a browser and go to `http://localhost:8050`. You should be able to see the dashboard.

### Part 2: Install parser tooling (host-side)
The parser is a core component of the EEWPW workflow. It runs on your host machine and is not part of the Docker stack.

Install it with:

```bash
make parser-install
```

This command creates and manages a dedicated environment under `tools/parser-venv` and installs the parser command-line tools there.

You can use the parser in two ways:


**Option A (recommended): run tools directly**
```bash
tools/parser-venv/bin/eewpw-parse --help
```

**Option B: activate the environment (optional)**
```bash
source tools/parser-venv/bin/activate
eewpw-parse --help
```

You can also explore available parser commands using your shell's tab-completion (e.g. press <Tab> after typing `tools/parser-venv/bin/eewpw-` or `eewpw-` if the environment is activated).

The parser will be used in the next section to convert raw logs into EEWPW-compatible JSON files for the dashboard.

