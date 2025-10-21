# Viewing playback performance with EEWPW

Tachnically, you can already start using the dashboard by opening a browser window and connecting to `http://localhost:8050` (`8050` is the default port). However, in most use cases, you will need to shift the time stamps  so that everything is aligned with the earthquake origin time. Additonally, each scenario will most likely be used with external data files such as MMI contours, moment rate function, earthquake catalog etc.

This document will walk you through the steps needed to prepare your working environment.

## Table of Contents
- [Manage `eewpw-config.toml`](#manage-eewpw-configtoml)
- [Sharing external datasets (MMIs, ruptures, catalogs)](#sharing-external-datasets-mmis-ruptures-catalogs)

---


### Manage `eewpw-config.toml`
#### [⬆Back to top](#viewing-playback-performance-with-eewpw)

> Before continuing, see [Config README](README_CONFIG.md) for a detailed description of all configuration fields and examples. 

EEWPW is shipped with a helper script (`scripts/manage-config.sh`) to manage the configuration file which resides **inside the frontend container** at `/app/client/eewpw-config.toml`. 

1. When EEWPW is built the first time, the config file does not exist. For your first performance simulations, we will prepare a minimal profile inside a file in `toml` format. 

```toml
[profiles.pazarcik]
origin_time = "2023-02-06 10:21:48"
playback_time = "2025-02-10 22:30:18"
earthquakes_timedelta = 600
mmi_distances = "CY08_worden"
earthquake_catalog = "/app/data/auxdata/pazarcik/earthquake_catalog.csv"
external_mmi_files = "/app/data/auxdata/pazarcik/usgs_mmi_pazarcik.json"
external_rupture_files = "/app/data/auxdata/pazarcik/rupture_elbistan.json; /app/data/auxdata/pazarcik/rupture_pazarcik.json"
moment_rate_function = "/app/data/auxdata/pazarcik/moment_rate_function.mr"
```

**Save this file in your localhost somewhere safe.** When docker containers need to be restarted from scratch, the containers will reset their states, and the configuration inside the docker container will be lost.

**Rules**
- All paths should point to `/app/data/auxdata/`. See the [next section](#sharing-external-datasets-mmis-ruptures-catalogs) below.
- You can define more than one file for file-dependent datasets. The paths should be seperated with `;`.
- Time stamps should be in ISO style.

2. The file name we use in this document is `example-scenario/pazarcik.toml`. In the next step, we copy this file into the container. 
```bash
# Copy a local TOML into the container
scripts/manage-config.sh copy ./example-scenario/pazarcik.toml

# Using the no-redis compose file
EEWPW_COMPOSE_FILE=docker-no-redis-compose.yml scripts/manage-config.sh copy ./example-scenario/pazarcik.toml
```

Then verify with:

```bash
# View current config (uses docker-compose.yml by default)
scripts/manage-config.sh view

# Using the no-redis compose file
EEWPW_COMPOSE_FILE=docker-no-redis-compose.yml scripts/manage-config.sh view
```

3. In your successive runs, you can use `append` option instead of `copy`. However, this depends on how you store your profiles: 
- You may choose to have individual profiles. In that case `append` is more appropriate. Otherwise, each `copy` will overwrite your old config file. 
- Alternatively, you can collect all your profiles in a single file. Then `copy` should be used in order not to duplicate the profiles.

```bash
# Append contents of another file
scripts/manage-config.sh append -f ./extra-settings.toml
```

4. If you need to delete the file
```bash
# Delete the config
scripts/manage-config.sh delete
```


---

### Sharing external datasets (MMIs, ruptures, catalogs)
#### [⬆Back to top](#viewing-playback-performance-with-eewpw)

To make host files (e.g., MMIs, ruptures, earthquake catalogs) visible to the dashboard, place them under the shared data directory (and use those paths in your config).

The data location on your host is `./data/auxdata`. The compose yaml file mounts this folder into the `frontend` container at `/app/client/auxdata` (read‑only).

Finally, place each file to where it belongs. For instance, if you config has 
```toml
earthquake_catalog = "/app/data/auxdata/pazarcik/earthquake_catalog.csv"
```

You need to create a `pazarcik` folder under `./data/auxdata` and copy the `earthquakes_catalog.csv` there.
```bash
cp /some/path/earthquakes_catalog.csv ./data/auxdata
```

Reload your app by refreshing your browser, if the dashboard was already open.

---