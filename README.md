# EEWPW Deployment

[![Backend Build](https://github.com/eewpw/eewpw-backend/actions/workflows/docker.yml/badge.svg?branch=master)](https://github.com/eewpw/eewpw-backend/actions/workflows/docker.yml)
[![Frontend Build](https://github.com/eewpw/eewpw-dashboard/actions/workflows/docker.yml/badge.svg?branch=master)](https://github.com/eewpw/eewpw-dashboard/actions/workflows/docker.yml)

## What this repo does (summary)
This repository provides a **turn‑key Docker Compose deployment** for the EEW Performance Viewer (EEWPW):
- Orchestrates the **backend API** and the **dashboard (Dash)** containers, plus optional **Redis**.
- Centralizes configuration in a single **`.env`** file (ports, image tags, URLs, data path).
- Offers helper scripts and Make targets for **first‑run**, **updates**, **health checks**, and **config management**.
- Supports two runtime modes:
  1) **With bundled Redis** (`docker-compose.yml`)
  2) **Using an external Redis** (`docker-no-redis-compose.yml`), e.g., your own local/remote Redis.

---

## Table of Contents
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Configuration (.env)](#configuration-env)
- [Manage `eewpw-config.toml`](#manage-eewpw-configtoml)
- [Starting & Stopping](#starting--stopping)
- [Using the Dashboard](#using-the-dashboard)
- [Choose a Redis Mode](#choose-a-redis-mode)
- [Update Images / Upgrade](#update-images--upgrade)
- [Troubleshooting](#troubleshooting)
- [Make Targets](#make-targets)

---

## Prerequisites
- **Docker** and **Docker Compose plugin** (Docker Desktop on macOS/Windows; Docker Engine + Compose on Linux)
- Network access to **GHCR** (GitHub Container Registry) to pull images

---

## Quick Start
1. Clone this repo and create your environment file:
   ```bash
   cp .env.example .env
   ```
2. Create local data directories and start the stack:
   ```bash
   make up
   ```
3. Run the smoke tests:
   ```bash
   make smoke
   ```
4. Open the dashboard: `http://localhost:${FRONTEND_PORT}` (defaults to **http://localhost:8050**).

---

## Configuration (.env)
All runtime config lives in `.env`. Key entries:

```env
# Images (from GHCR)
BACKEND_IMAGE=ghcr.io/eewpw/eewpw-backend
BACKEND_TAG=master
FRONTEND_IMAGE=ghcr.io/eewpw/eewpw-dashboard
FRONTEND_TAG=main

# Ports (host)
BACKEND_PORT=8000
FRONTEND_PORT=8050

# Backend runtime
EEWPW_DATA_DIR=/app/data
DATA_ROOT=./data

# Service-to-service base URL (frontend → backend)
BACKEND_BASE_URL=http://backend:8000
EEWPW_BACKEND_BASE=http://backend:8000

# If using an external Redis, set this (otherwise leave unset)
# REDIS_URL=redis://host.docker.internal:6379/0
```

> **Note:** Inside Docker, the frontend reaches the backend at `http://backend:8000` (Compose service DNS). If you run the frontend natively, set these to `http://localhost:8000`.

---

## Manage `eewpw-config.toml`
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

---

## Starting & Stopping
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

---

## Using the Dashboard
- Open: `http://localhost:${FRONTEND_PORT}` (default: **8050**).
- Upload files and run analyses. The dashboard calls the backend at `BACKEND_BASE_URL`.
- Persistent data created by the backend is stored under `${DATA_ROOT}` on the host (default `./data`).

---

## Choose a Redis Mode
- **Embedded Redis**: use `docker-compose.yml` and **do not** set `REDIS_URL`. Backend will connect to the in‑stack `redis` service.
- **External Redis**: use `docker-no-redis-compose.yml` **and** set `REDIS_URL` in `.env`, e.g.:
  ```env
  REDIS_URL=redis://host.docker.internal:6379/0
  ```

---

## Update Images / Upgrade
Pull the latest images and restart:
```bash
make pull
make up
make smoke
```

If you’re tracking immutable tags (SHAs), update `BACKEND_TAG` / `FRONTEND_TAG` in `.env` accordingly.

---

## Troubleshooting
- **Frontend can’t reach backend**:
  - Ensure `.env` has `BACKEND_BASE_URL=http://backend:8000` (for containerized frontend).
  - `docker compose exec frontend curl -sS http://backend:8000/healthz` should return 200.
- **Redis errors**: Set `REDIS_URL` to your external instance or use the bundled `docker-compose.yml`.
- **Ports in use**: change `BACKEND_PORT` / `FRONTEND_PORT` in `.env`.
- **Permissions on data**: ensure `${DATA_ROOT}` is writable by Docker (Linux: check user/group).
- **Smoke test**:
  ```bash
  make smoke
  ```

---

## Make Targets
```text
make up        # create data dirs and start services
make down      # stop services
make pull      # pull latest images
make logs      # tail logs for all services
make ps        # show container status
make smoke     # health check backend + frontend
```

---

## Using a Custom Compose File
You can run any Make target with a different Docker Compose file by setting the `COMPOSE_FILE` variable.
This is useful when switching between configurations (for example, with or without Redis) without editing the Makefile.

### Examples
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
