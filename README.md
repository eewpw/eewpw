# EEWPW Deployment

[![Backend Build](https://github.com/eewpw/eewpw-backend/actions/workflows/docker-backend.yml/badge.svg?branch=master)](https://github.com/eewpw/eewpw-backend/actions/workflows/docker-backend.yml)
[![Frontend Build](https://github.com/eewpw/eewpw-dashboard/actions/workflows/docker-frontend.yml/badge.svg?branch=master)](https://github.com/eewpw/eewpw-dashboard/actions/workflows/docker-frontend.yml)

> **Acknowledgment:** *Development of EEWPW is supported by the U.S. Geological Survey ShakeAlert project.*

## Summary

This repository is the **deployment entry point** for the *EEW Performance Workpackage (EEWPW)*. It does not contain application code; instead, it orchestrates pre-built Docker images as a runnable system.

The stack consists of a **dashboard** (the web interface you see in your browser), **backend** service (handles data and communication behind the scenes), and **Redis** (used for caching to improve performance), all managed together via Docker Compose.

EEWPW workflows rely on input files produced by a standalone **eewpw-parser** module. While the parser is not part of this containerized stack, this repository provides support for installing and using it as host-side tooling.

## Prerequisites
#### [⬆Back to top](#eewpw-deployment)

Before starting the EEWPW stack, make sure your machine has the required tools installed.

You will need:
- **Git**
- **Docker** and the **Docker Compose plugin**
- **Python 3** (for parser workflows)
- **make** (recommended for running commands like `make up`, `make smoke`, and `make update`)

For detailed setup instructions (macOS, Linux, Windows, including WSL2 guidance), see:
- [docs/PREREQUISITES.md](docs/PREREQUISITES.md)

---


## Installation
#### [⬆Back to top](#eewpw-deployment)


1. Clone this repo:
   ```bash
   git clone https://github.com/eewpw/eewpw.git
   cd eewpw
   ```

2. Create a `.env` file based on `.env.example` and edit it according to your setup.

   The default deployment uses the bundled stack managed by this repository. Advanced Redis and Compose variants are documented in [docs/DEVELOPERS.md](docs/DEVELOPERS.md).

3. Create required directories:
   ```bash
   make dirs
   ```

4. To start the container stack, we recommend to use the ([see Appendix → make](#the-make-tool)):
   ```bash
   make up
   ```

5. Finally, run the smoke test (no Redis conflict here):
   ```bash
   make smoke
   ```
   See [make tool](#the-make-tool) for all options. The expected output is:
   
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

6. Access the dashboard in your browser at `http://localhost:${FRONTEND_PORT}` (default: `http://localhost:8050`).

7. Install and use the parser (host-side tooling)

   EEWPW workflows depend on parser-generated input files. This repository provides helper targets to install and manage the standalone `eewpw-parser` tools (for offline log parsing, JSON creation, or replay) in an isolated virtual environment on the host:

   ```bash
   make parser-install
   ```

   This will create (if needed) a virtual environment under `tools/parser-venv` and install the latest `eewpw-parser` from GitHub into it. You can then access the CLI tools via:

   ```bash
   tools/parser-venv/bin/eewpw-parse --help
   tools/parser-venv/bin/eewpw-parse-live --help
   tools/parser-venv/bin/eewpw-replay-log --help
   ```

   Alternatively, you may install the parser in your own preferred virtual environment (e.g. `./venv`) and run the CLI tools from there.

   We recommend creating a dedicated virtual environment for local parser tooling. A repository-local `./venv` is a good default for manual workflows.

   To upgrade to the latest parser version later, run:

   ```bash
   make parser-update
   ```


**[Next chapter](docs/PLAYBACKS.md) will explain how to set up the dashboard for viewing the EEW performance for a playback. Please continue to read first to find out about managing the EEWPW tools and its environment.**


---

## Customizing the user interface

> `.env` allows for some customization on the UI. Currently, custom parameters are limited to the font sizes and alert polygon cosmetics. Edit the file to your taste:

```bash
# UI Font Sizes - customize as desired (no spaces around '=')
TITLE_FONT_SIZE=16        # Plot title font size
AXIS_LABEL_FONT_SIZE=14   # Axis title font size (x/y labels)
TICK_LABEL_FONT_SIZE=14   # Tick label font size
LEGEND_FONT_SIZE=12       # Legend text size
TOOLTIP_FONT_SIZE=12      # Tooltip (hover label) text size
# Thickness, opacity and border color for alert polygons. 
# Use RGB hex color code for border color (in quotes) 
ALERT_POLY_THICKNESS=4.5
ALERT_POLY_BORDER_THICKNESS=0.1
ALERT_POLY_BORDER_COLOR="#000000"
ALERT_POLY_OPACITY=0.9
```

After editing, run `make up` and refresh your browser window (if you had the dashboard open) to make the changes take effect. These settings affect only the frontend Dash plots (e.g., PGA vs Distance and Magnitude Evolution).

---

## Starting & Stopping
#### [⬆Back to top](#eewpw-deployment)

We recommend using the [make tool](#the-make-tool) for day-to-day management. However, you can also use native Docker Compose commands directly.

Start the default stack:
```bash
# With the make tool
make up

# Or with docker compose
docker compose up -d
```

Restart a single service:
```bash
docker compose restart backend
```

Advanced Compose variants are documented in [docs/DEVELOPERS.md](docs/DEVELOPERS.md).

---

## Update Images / Upgrade
#### [⬆Back to top](#eewpw-deployment)

When there is an update to any of the repositories, you should pull the latest images and restart.

First, update the `eewpw` main repository:
```bash
cd eewpw
git pull
```

> **Note:** `git pull` under the `eewpw` directory only updates the deployment repo. Please check the `.env.example` file to make sure your local copy (`.env`) is not missing any newly introduced environmental variables.  

Then, update containers:

```bash
make update

# Then run smoke tests
make smoke
```

If you would like to shutdown all containers, and update:

```bash
# Shutdown running containers
# WARNING: All data copied inside the container will be lost
make down
# Update
make update
# Run the smoke tests
make smoke
```

**Note:** Each `docker compose pull` or `make update` (which runs `pull` + `up`) fetches new images for the same tags (e.g. `:master`). Over time this leaves old, unreferenced images (shown as `<none>` in `docker image ls`). To reclaim disk space, you can occasionally run `make prune`. **This performs a global Docker cleanup**, so use it only when you want to remove unused images and containers from **all** projects.

---

## Troubleshooting
#### [⬆Back to top](#eewpw-deployment)

- **Frontend can’t reach backend**:
  - Ensure `.env` has `BACKEND_BASE_URL=http://backend:8000` (for containerized frontend).
  - `docker compose exec frontend curl -sS http://backend:8000/healthz` should return 200.
- **Redis errors**: In the default setup, Redis is started as part of the deployment. For advanced Redis configurations, see [docs/DEVELOPERS.md](docs/DEVELOPERS.md).
- **Ports in use**: If you see “failed to bind host port … address already in use”, update `BACKEND_PORT` / `FRONTEND_PORT` in `.env` to unused values (e.g., 8001, 8051) and restart with `make up`.
> ```env
> BACKEND_PORT=8001
> FRONTEND_PORT=8051
> ```

> ```bash
> # Then restart your stack:
> make up
> ```

- **Permissions on data**: ensure `${DATA_ROOT}` is writable by Docker (Linux: check user/group).
- **Smoke test**:
  ```bash
  make smoke
  ```
- **No docker deamon** error: Start your Docker app.
```bash
docker compose -f docker-compose.yml ps
Cannot connect to the Docker daemon at unix:///Users/savas/.docker/run/docker.sock. Is the docker daemon running?
make: *** [ps] Error 1
```

---


## Appendix: 

### Platform Compatibility
#### [⬆Back to top](#eewpw-deployment)
EEWPW containers are **multi-architecture images** built for both `linux/amd64` and `linux/arm64`.  
They run seamlessly on macOS (Intel or Apple Silicon), Linux, and Windows via Docker Desktop (WSL 2).

| Platform | Works? | Notes |
|-----------|--------|-------|
| **macOS (Intel / Apple Silicon)** | ✅ | Fully supported; multi-arch images run natively |
| **Linux** | ✅ | Fully supported |
| **Windows 10 / 11 + Docker Desktop (WSL 2)** | ✅ | Fully supported — must be in Linux containers mode |
| **Windows Server / Windows containers mode** | ❌ | Not supported — EEWPW images are Linux-based |

> **Notes:**  
> - On Windows, enable **WSL 2 based engine** in Docker Desktop (`Settings → General`).  
> - Keep your project folder under a user path (e.g. `C:\Users\you\Projects\eewpw`).  
> - Compose and Make commands are identical across platforms:
>   ```bash
>   make up
>   make smoke
>   ```

---



### Runtime configuration
#### [⬆Back to top](#eewpw-deployment)

All runtime config lives in `.env`. Key entries:

```bash
# Images (pulled from GHCR)
BACKEND_IMAGE=ghcr.io/eewpw/eewpw-backend
BACKEND_TAG=master
FRONTEND_IMAGE=ghcr.io/eewpw/eewpw-dashboard
FRONTEND_TAG=master

# Ports (host-side)
BACKEND_PORT=8000
FRONTEND_PORT=8050
REDIS_PORT=6379

# Redis configuration
# The default deployment uses the bundled Redis service.
# Advanced Redis setups are documented in docs/DEVELOPERS.md.
# REDIS_URL=redis://host.docker.internal:6379/0

# Backend config
EEWPW_DATA_DIR=/app/data
BACKEND_BASE_URL=http://backend:8000
EEWPW_BACKEND_BASE=http://backend:8000
CORS_ENABLED=1
CORS_ORIGINS=http://127.0.0.1:8050,http://localhost:8050
JSON_LOGS=1
LOG_TO_FILE=1
CURSOR_TTL_SECONDS=0
# Maximum upload size in megabytes. Does not guarantee uploads 
# of this size will succeed, as browser limits and other factors may apply.
MAX_UPLOAD_MB=60

# Local mode flags (if used by backend)
LOCAL_MODE=true
DEFAULT_USER_ID=local

# Volumes (host paths)
DATA_ROOT=./data

# URL for tracking the latest EEWPW version
EEWPW_UPDATE_STATUS_URL=https://raw.githubusercontent.com/eewpw/eewpw-update-status/main/update.json

# UI Font Sizes - customize as desired (no spaces around '=')
TITLE_FONT_SIZE=16        # Plot title font size
AXIS_LABEL_FONT_SIZE=14   # Axis title font size (x/y labels)
TICK_LABEL_FONT_SIZE=14   # Tick label font size
LEGEND_FONT_SIZE=12       # Legend text size
TOOLTIP_FONT_SIZE=12      # Tooltip (hover label) text size
# Thickness, opacity and border color for alert polygons. 
# Use RGB hex color code for border color (in quotes) 
ALERT_POLY_THICKNESS=4.5
ALERT_POLY_BORDER_THICKNESS=0.1
ALERT_POLY_BORDER_COLOR="#000000"
ALERT_POLY_OPACITY=0.9
```

> **Note:** Inside Docker, the frontend reaches the backend at `http://backend:8000` (Compose service DNS). If you run the frontend natively, set these to `http://localhost:8000`.

--- 

### The `make` tool
#### [⬆Back to top](#eewpw-deployment)

The `Makefile` included in this repository simplifies day-to-day management of the EEWPW deployment.  
It wraps all necessary Docker Compose commands, ensures environment setup, and creates required directories before launching containers.

Each `make` target performs a defined operation.  
Run any of these commands from the project root (where your `.env` file is located).  
By default, `docker-compose.yml` is used. Advanced Compose overrides are documented in [docs/DEVELOPERS.md](docs/DEVELOPERS.md).



#### **Core Commands**
| Command | Description |
|----------|--------------|
| **make help** | Shows all available Make targets and usage hints. |
| **make pull** | Pulls the latest backend and frontend images from GitHub Container Registry (GHCR). |
| **make up** | Starts the full stack in detached mode (`-d`). Runs `dirs` first to ensure paths exist. |
| **make down** | Stops and removes containers and the network, but keeps data volumes. |
| **make update**| Combines `make pull` and `make up`. | 
| **make ensure-env** | Verifies `.env` exists before running other targets. Exits with an error if missing. |
| **make dirs** | Creates the data directory structure (`$DATA_ROOT/files`, `indexes`, `logs`, `auxdata`). Automatically called by `make up`. |
| **make logs** | Follows combined logs for all services (latest 200 lines). Press `Ctrl+C` to stop. |
| **make ps** | Lists container status (running, exited, unhealthy, etc.). |
| **make smoke** | Performs a backend health check via `/healthz` using `scripts/smoke.sh`. |
| **make clean** | Stops and removes containers **and** all volumes for a clean reset. |
| **make prune** | Global Docker cleanup: prunes all unused images, containers, volumes, and networks. Affects all Docker projects on this machine – use with care. |


#### **Parser-related commands**

These targets manage a local virtual environment for the `eewpw-parser` project. They do **not** affect any Docker containers or images.

| Command | Description |
|----------|-------------|
| **make parser-install** | Creates (if needed) `tools/parser-venv` and force-(re)installs the latest `eewpw-parser` from GitHub into it. Safe to run repeatedly. |
| **make parser-update**  | Alias of `make parser-install`, but with the mental model of "upgrade parser to the current version". |

After running `make parser-install` (or `make parser-update`), the parser CLI tools are available at `tools/parser-venv/bin/`, for example:

```bash
tools/parser-venv/bin/eewpw-parse --help
tools/parser-venv/bin/eewpw-parse-live --help
tools/parser-venv/bin/eewpw-replay-log --help
```



## Next: Viewing EWW playbacks

So far, this README has covered how to set up and manage the EEWPW containers and codebase. The next step is to explore how to view and analyze playback performances through the dashboard.
See the detailed guide for how to [view playback performances](docs/PLAYBACKS.md).

---
