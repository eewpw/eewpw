# EEWPW Deployment

[![Backend Build](https://github.com/eewpw/eewpw-backend/actions/workflows/docker.yml/badge.svg?branch=master)](https://github.com/eewpw/eewpw-backend/actions/workflows/docker.yml)
[![Frontend Build](https://github.com/eewpw/eewpw-dashboard/actions/workflows/docker.yml/badge.svg?branch=master)](https://github.com/eewpw/eewpw-dashboard/actions/workflows/docker.yml)

## Summary
This repository provides a **turn‑key Docker Compose deployment** for the EEW Performance Viewer (EEWPW):
- This repository does not contain the backend or dashboard code — it orchestrates them as Docker images: the **backend API** and the **dashboard (Dash)** containers, plus optional **Redis**.
- Centralizes configuration in a single **`.env`** file (ports, image tags, URLs, data path).
- Offers helper scripts and Make targets for **first‑run**, **updates**, **health checks**, and **config management**.
- Supports two runtime modes:
  1) **With bundled Redis** (`docker-compose.yml`)
  2) **Using an external Redis** (`docker-no-redis-compose.yml`), e.g., your own local/remote Redis.

> **With bundled Redis**: This is the default mode for all scripts. In this mode, we pull both dashboard and backend containers, plus the Redis container. Probably, this mode is the case for most of the end users. 

> **Using an external Redis**: In this mode, you already had the redis container (`eewpw-redis`). This is more practical especially at the development stage. Then runtime environment is slightly adjusted to avoid URL overrides and permission related crashes. In this mode, scripts should be specifically notified which docker-compose is used.

> For platform and architecture compatibility, see [Appendix: Platform Compatibility](#platform-compatibility).

---

## Table of Contents
- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Starting & Stopping](#starting--stopping)
- [Using the Dashboard](#using-the-dashboard)
- [Update Images / Upgrade](#update-images--upgrade)
- [Troubleshooting](#troubleshooting)
- [Appendix](#appendix)
- [Next: Viewing EEW playbacks](#next-viewing-eww-playbacks)

---

## Prerequisites
#### [⬆Back to top](#eewpw-deployment)

- **Docker** and **Docker Compose plugin** (Docker Desktop on macOS/Windows; Docker Engine + Compose on Linux)
- If enforced by the admins, network access to **GHCR** (GitHub Container Registry) to pull images

Our containers are public. If at some point they are temporarily made private, you will receive `access error` while building the application. If that's case, login to GitHub Container Registery before proceeding: `docker login ghcr.io` with your GitHub username and personal access token.

---

## Installation
#### [⬆Back to top](#eewpw-deployment)


1. We start with cloning this repo:
   ```bash
   git clone https://github.com/eewpw/eewpw.git
   cd eewpw
   ```

2. Then, we prepare environment file
   ```bash
   cp .env.example .env
   ```
   Edit the `.env` file. 
   
   > **You must decide your Redis mode while editing `.env`:** ([more on `.env` in Appendix](#redis-configuration-notes))
   
   * If you already have Redis: Make sure `REDIS_URL=redis://host.docker.internal:6379/0.` is in the `.env` and uncommented.
   * You are sure you have not installed the Redis before: Comment out the `REDIS_URL` line.


3. To start the container stack, we recommend to use the ([see Appendix → make](#the-make-tool)):

   This step also depends on whether you have Redis or not. Please see the [make](#the-make-tool) tool.
   ```bash
   make up
   ```

4. Finally, run the smoke test:
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

## Starting & Stopping
#### [⬆Back to top](#eewpw-deployment)

We recommend to use our [make tool](#the-make-tool) for managing the repo environment. However, you can also use the native `docker compose` commands.

**With bundled Redis** (default compose):
```bash
docker compose up -d           # start all
make down                      # stop
```

**With external Redis** (no Redis service):
```bash
docker compose -f docker-no-redis-compose.yml up -d
```

**Restart a single service**:
```bash
docker compose restart backend
```

> **Tip:** If you encounter an “address already in use” error on startup, another process or container may already be using port 8000 or 8050. You can adjust these in your `.env` file:
> ```env
> BACKEND_PORT=8001
> FRONTEND_PORT=8051
> ```
> Then restart your stack:
> ```bash
> make down && make up
> ```
---

## Update Images / Upgrade
#### [⬆Back to top](#eewpw-deployment)

When there is an update to any of the repositories, you should pull the latest images and restart.

First, update the `eewpw` main repository:
```bash
cd eewpw
git pull
```

Then, update and restart the containers:
```bash
# Shutdown running containers
make down
# Pull the latest versions
make pull
# Start them up again
make up
# Run the smoke tests
make smoke
```

---

## Troubleshooting
#### [⬆Back to top](#eewpw-deployment)

- **Frontend can’t reach backend**:
  - Ensure `.env` has `BACKEND_BASE_URL=http://backend:8000` (for containerized frontend).
  - `docker compose exec frontend curl -sS http://backend:8000/healthz` should return 200.
- **Redis errors**: Set `REDIS_URL` to your external instance or use the bundled `docker-compose.yml`.
- **Ports in use**: If you see “failed to bind host port … address already in use,” update `BACKEND_PORT` / `FRONTEND_PORT` in `.env` to unused values (e.g., 8001, 8051) and restart with `make down && make up`.
- **Permissions on data**: ensure `${DATA_ROOT}` is writable by Docker (Linux: check user/group).
- **Smoke test**:
  ```bash
  make smoke
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

```env
# Images (from GHCR)
BACKEND_IMAGE=ghcr.io/eewpw/eewpw-backend
BACKEND_TAG=master
FRONTEND_IMAGE=ghcr.io/eewpw/eewpw-dashboard
FRONTEND_TAG=master

# Ports (host)
# You can change these if 8000 or 8050 are already in use on your system.
# For example, BACKEND_PORT=8001 and FRONTEND_PORT=8051 will avoid conflicts.
BACKEND_PORT=8000
FRONTEND_PORT=8050

# Backend runtime
EEWPW_DATA_DIR=/app/data
DATA_ROOT=./data

# Service-to-service base URL (frontend → backend)
BACKEND_BASE_URL=http://backend:8000
EEWPW_BACKEND_BASE=http://backend:8000

# If using an external Redis, set this (otherwise leave unset) <<<========
# REDIS_URL=redis://host.docker.internal:6379/0
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
| **make ensure-env** | Verifies `.env` exists before running other targets. Exits with an error if missing. |
| **make dirs** | Creates the data directory structure (`$DATA_ROOT/files`, `indexes`, `logs`, `auxdata`). Automatically called by `make up`. |
| **make pull** | Pulls the latest backend and frontend images from GitHub Container Registry (GHCR). |
| **make up** | Starts the full stack in detached mode (`-d`). Runs `dirs` first to ensure paths exist. |
| **make down** | Stops and removes containers and the network, but keeps data volumes. |
| **make logs** | Follows combined logs for all services (latest 200 lines). Press `Ctrl+C` to stop. |
| **make ps** | Lists container status (running, exited, unhealthy, etc.). |
| **make smoke** | Performs a backend health check via `/healthz` using `scripts/smoke.sh`. |
| **make clean** | Stops and removes containers **and** all volumes for a clean reset. |


#### **Using a Custom Compose File**
To switch between configurations (e.g., with or without Redis), specify a compose file inline:

```bash
# Start the stack without bundled Redis
make up COMPOSE_FILE=docker-no-redis-compose.yml

# Run smoke test using the same configuration
make smoke COMPOSE_FILE=docker-no-redis-compose.yml

# View container logs with a specific compose file
make logs COMPOSE_FILE=docker-no-redis-compose.yml

#### Examples
```bash
# Default: uses docker-compose.yml
make up

# Use docker-no-redis-compose.yml
make up COMPOSE_FILE=docker-no-redis-compose.yml

# View logs using the same file
make logs COMPOSE_FILE=docker-no-redis-compose.yml

# Stop containers using a specific compose file
make down COMPOSE_FILE=docker-no-redis-compose.yml
```

This variable works for all Make targets (`up`, `down`, `pull`, `logs`, `ps`, `smoke`, etc.).

## Next: Viewing EWW playbacks

So far, this README has covered how to set up and manage the EEWPW containers and codebase. The next step is to explore how to view and analyze playback performances through the dashboard.
See the detailed guide for how to [view playback performances](docs/PLAYBACKS.md).

---
