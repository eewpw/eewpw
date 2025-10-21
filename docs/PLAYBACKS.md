# Viewing playback performance with EEWPW


## Table of Contents
- [Manage `eewpw-config.toml`](#manage-eewpw-configtoml)
- [Sharing external datasets (MMIs, ruptures, catalogs)](#sharing-external-datasets-mmis-ruptures-catalogs)

---


### Manage `eewpw-config.toml`
#### [⬆Back to top](#eewpw-deployment)

> Before continuing, see [Config README](docs/README_CONFIG.md) for a detailed description of all configuration fields and examples. A set of configuration profiles are needed for including external data files into the EEWPW tool, or running your playbacks correctly. 

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

### Sharing external datasets (MMIs, ruptures, catalogs)
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