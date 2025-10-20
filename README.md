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

> For platform and architecture compatibility, see [Appendix: Platform Compatibility](#platform-compatibility).

---

## Table of Contents
- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Manage `eewpw-config.toml`](#manage-eewpw-configtoml)
- [Sharing external datasets (MMIs, ruptures, catalogs)](#sharing-external-datasets-mmis-ruptures-catalogs)
- [Starting & Stopping](#starting--stopping)
- [Using the Dashboard](#using-the-dashboard)
- [Update Images / Upgrade](#update-images--upgrade)
- [Troubleshooting](#troubleshooting)
- [Appendix](#appendix)

---

## Prerequisites
#### [⬆Back to top](#eewpw-deployment)

- **Docker** and **Docker Compose plugin** (Docker Desktop on macOS/Windows; Docker Engine + Compose on Linux)
- Possibly, network access to **GHCR** (GitHub Container Registry) to pull images
> **Note:** Our containers are public. If at some point they are temporarily made private, you will receive `access error` while building the application. If that's case, login to GitHub Container Registery before proceeding: `docker login ghcr.io`. You will need to use your GitHub username and personal access token.

---

## Installation
#### [⬆Back to top](#eewpw-deployment)


1. Clone this repo and create your environment file:
   ```bash
   git clone https://github.com/eewpw/eewpw.git
   cd eewpw
   ```

2. Prepare environment file
   ```bash
   cp .env.example .env
   ```
   Edit the `.env` file. 
   
   > **You must decide your Redis mode while editing `.env`:** ([more on `.env` in Appendix](#redis-configuration-notes))
   
   * If you already have Redis: Make sure `REDIS_URL=redis://host.docker.internal:6379/0.` is in the `.env` and uncommented.
   * You are sure you have not installed the Redis before: Comment out the `REDIS_URL` line.


3. To start the container stack, use the ([see Appendix → make](#the-make-tool)):

   This step also depends on whether you have Redis or not. Please see the [make](#the-make-tool) tool.
   ```bash
   make up
   ```

4. Run the smoke test:
   ```bash
   make smoke
   ```
   See [make tool](#the-make-tool) for all options.

5. Access the dashboard: 
On your browser, go to `http://localhost:${FRONTEND_PORT}` (defaults to **http://localhost:8050**).


---

## Manage `eewpw-config.toml`
#### [⬆Back to top](#eewpw-deployment)

Use the helper script to manage a config file **inside the frontend container** at `/app/client/eewpw-config.toml`.

```bash
# View current config (uses docker-compose.yml by default)
scripts/manage-config.sh view

# Using the no-redis compose file
EEWPW_COMPOSE_FILE=docker-no-redis-compose.yml scripts/manage-config.sh view

# Copy a local TOML into the container
scripts/manage-config.sh copy ./my-configs/eewpw-config.toml

# Append a single line
scripts/manage-config.sh append 'max_items = 200'

# Append contents of another file
scripts/manage-config.sh append -f ./extra-settings.toml

# Delete the config
scripts/manage-config.sh delete
```

You can override defaults via env vars: `EEWPW_COMPOSE_FILE` (default `docker-compose.yml`), `EEWPW_SERVICE=frontend`, `EEWPW_CONFIG_PATH=/app/client/eewpw-config.toml`.

For a detailed description of all configuration fields and examples, see [docs/README_CONFIG.md](docs/README_CONFIG.md).

---

## Sharing external datasets (MMIs, ruptures, catalogs)
#### [⬆Back to top](#eewpw-deployment)

To make host files (e.g., MMIs, ruptures, earthquake catalogs) visible to the dashboard, place them under the shared data directory and use those paths in your config.

**Convention:** use `./data/auxdata` on the host. The compose files mount this folder into the frontend at `/app/client/auxdata` (read‑only).

Example entries in `eewpw-config.toml`:

```toml
earthquake_catalog = "auxdata/combined_earthquake_catalog.csv"
external_mmi_files = "auxdata/external_mmi/cont_mmi.json"
external_rupture_files = "auxdata/ruptures/rupture1.json; auxdata/ruptures/rupture2.json"
```

> **Important**: `auxdata/...` paths are relative to the dashboard app and resolve to the mounted `/app/client/auxdata` inside the container. The same files live on your host under `./data/auxdata`.

---

## Starting & Stopping
#### [⬆Back to top](#eewpw-deployment)

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

## Using the Dashboard
#### [⬆Back to top](#eewpw-deployment)

- Open: `http://localhost:${FRONTEND_PORT}` (default: **8050**).
- Upload files and run analyses. The dashboard calls the backend at `BACKEND_BASE_URL`.
- Persistent data created by the backend is stored under `${DATA_ROOT}` on the host (default `./data`).

---

## Update Images / Upgrade
#### [⬆Back to top](#eewpw-deployment)

Pull the latest images and restart:
```bash
make pull
make up
make smoke
```

If you’re tracking immutable tags (SHAs), update `BACKEND_TAG` / `FRONTEND_TAG` in `.env` accordingly.

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
