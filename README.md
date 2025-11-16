# EEWPW Deployment

[![Backend Build](https://github.com/eewpw/eewpw-backend/actions/workflows/docker-backend.yml/badge.svg?branch=master)](https://github.com/eewpw/eewpw-backend/actions/workflows/docker-backend.yml)
[![Frontend Build](https://github.com/eewpw/eewpw-dashboard/actions/workflows/docker-frontend.yml/badge.svg?branch=master)](https://github.com/eewpw/eewpw-dashboard/actions/workflows/docker-frontend.yml)

> **Acknowledgment:** *Development of EEWPW is supported by the U.S. Geological Survey ShakeAlert project.*

## Summary

This repository provides a **Docker Compose deployment** for the *EEW Performance Workpackage (EEWPW)*. It does not contain the source code of submodules (e.g. the frontend dashboard for the viewer, or backend API), but orchestrates them as pre-built Docker images. 

The main components are the **backend API**, the **dashboard (Dash)** container, and an optional **Redis** container. 
Configuration is centralized in a single **`.env`** file, which defines ports, image tags, URLs, and data paths. Helper scripts 
and Make targets are provided for **first-run setup**, **updates**,  **health checks**, and **log inspection**. 

For platform and architecture details, see [Appendix: Platform Compatibility](#platform-compatibility).

> **Note**  
> We support two runtime modes, and this document includes instructions for both:
>
> 1. **With bundled Redis** (`docker-compose.yml`) – for common users.  
>    This is the default mode for all scripts. In this mode, both the dashboard and backend containers are started, along with the Redis container.
>
> 2. **Using an external Redis** (`docker-no-redis-compose.yml`) – generally for developers.  
>    At the development stage, running the Redis container (`eewpw-redis`) separately is often more practical for testing front- and back-end components. 
>    In this mode, scripts must explicitly specify which Compose file is being used. The runtime environment is slightly adjusted to prevent URL overrides 
>    and permission-related issues.

---



## Table of Contents
- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Customizing the user interface](#customizing-the-user-interface)
- [Starting & Stopping](#starting--stopping)
- [Update Images / Upgrade](#update-images--upgrade)
- [Troubleshooting](#troubleshooting)
- [Appendix](#appendix)
- [Next: Viewing EEW playbacks](docs/PLAYBACKS.md)


---


## Prerequisites
#### [⬆Back to top](#eewpw-deployment)

- **Docker** and the **Docker Compose plugin**  
  (Docker Desktop on macOS/Windows; Docker Engine + Compose on Linux)
- Network access to **GHCR** (GitHub Container Registry), if required by your administrators, to pull container images.

*Our containers are public. If they are temporarily made private, you may encounter an* `access error` *when building the 
application. In that case, log in to the GitHub Container Registry before proceeding:*

```bash
# Use your personal access token
docker login ghcr.io
```

---


## Installation
#### [⬆Back to top](#eewpw-deployment)


1. Clone this repo:
   ```bash
   git clone https://github.com/eewpw/eewpw.git
   cd eewpw
   ```

2. Prepare the environment file
   ```bash
   cp .env.example .env
   ```
   Edit the `.env` file. 
   
   > **You must decide your Redis mode while editing `.env`:** ([more on `.env` in Appendix](#redis-configuration-notes))
   
   * If you already have Redis: Make sure `REDIS_URL=redis://host.docker.internal:6379/0.` is in the `.env` and uncommented.
   * You have not manually installed the Redis container `eewpw-redis`: Comment out the `REDIS_URL` line.

3. To start the container stack, we recommend to use the ([see Appendix → make](#the-make-tool)):

   This step also depends on whether you have Redis or not. 
   ```bash
   make up
   ```

4. Finally, run the smoke test (no Redis conflict here):
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

5. Access the dashboard: Dashboard should be ready after this. On your browser, go to `http://localhost:${FRONTEND_PORT}` (defaults to **http://localhost:8050**). 


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

We recommend to use our [make tool](#the-make-tool) for managing the repo environment. However, you can also use the native `docker compose` commands.

**With bundled Redis** (default compose):
```bash
# With the make tool
make up                      

# Or with docker compose
docker compose up -d
```

**With external Redis** (no Redis service required):
```bash
make up COMPOSE_FILE=docker-no-redis-compose.yml

# or
docker compose -f docker-no-redis-compose.yml up -d
```

**Restart a single service**:
```bash
# make does not wrap restart - use docker compose
docker compose restart backend
```

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
# With Redis 
make update

# If you already have Redis
make update COMPOSE_FILE=docker-no-redis-compose.yml

# Then, run smoke tests
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
- **Redis errors**: Set `REDIS_URL` to your external instance or use the bundled `docker-compose.yml`.
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

### Redis Configuration Notes
#### [⬆Back to top](#eewpw-deployment)

- **Bundled Redis** (default):  
  No `REDIS_URL` is needed; Compose runs Redis automatically.

- **External Redis**:  
  Uncomment and set `REDIS_URL` in `.env`, for example:  
  `REDIS_URL=redis://host.docker.internal:6379/0`  
  This is useful if you already run Redis locally or remotely.

> You can switch between these modes anytime by editing `.env` and restarting with `make down && make up`.

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

# -- Redis configuration --
# If you already have a Redis server running, uncomment this. 
# Otherwise, leave it commented (undefined) to use the bundled Redis.
# REDIS_URL=redis://host.docker.internal:6379/0
# ---

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
By default, `docker-compose.yml` is used — override it by adding `COMPOSE_FILE=<path>`.


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


#### **Using a Custom Compose File**
To switch between configurations (e.g., with or without Redis), specify a compose file inline:

```bash
# Start the stack without bundled Redis
make up COMPOSE_FILE=docker-no-redis-compose.yml

# Run smoke test using the same configuration
make smoke COMPOSE_FILE=docker-no-redis-compose.yml

# View container logs with a specific compose file
make logs COMPOSE_FILE=docker-no-redis-compose.yml

# Stop containers using a specific compose file
make down COMPOSE_FILE=docker-no-redis-compose.yml
```

This variable works for all Make targets (`up`, `down`, `pull` etc.).

## Next: Viewing EWW playbacks

So far, this README has covered how to set up and manage the EEWPW containers and codebase. The next step is to explore how to view and analyze playback performances through the dashboard.
See the detailed guide for how to [view playback performances](docs/PLAYBACKS.md).

---
