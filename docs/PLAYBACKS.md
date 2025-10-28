# Viewing playback performance with EEWPW

Tachnically, you can already start using the dashboard by opening a browser window and connecting to `http://localhost:8050` (`8050` is the default port). However, in most use cases, you will need to shift the time stamps  so that everything is aligned with the earthquake origin time. Additonally, each scenario will most likely be used with external data files such as MMI contours, moment rate function, earthquake catalog etc.

This document will walk you through the steps needed to prepare your working environment.

## Table of Contents
- [Manage `eewpw-config.toml`](#manage-eewpw-configtoml)
- [Sharing external datasets (MMIs, ruptures, catalogs)](#sharing-external-datasets-mmis-ruptures-catalogs)
- [Uploading new data](#upload-your-data)

---


### Manage `eewpw-config.toml`
#### [⬆Back to top](#viewing-playback-performance-with-eewpw)

> Before continuing, see [Config README](README_CONFIG.md) for a detailed description of all configuration fields and examples. 

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

> **Save this file in your localhost somewhere safe.** 

**Rules**
- All paths should point to `/app/data/auxdata/`. See the [next section](#sharing-external-datasets-mmis-ruptures-catalogs) below.
- You can define more than one file for file-dependent datasets. The paths should be seperated with `;`.
- Time stamps should be in ISO style.

2. The file name we use in this document is `example-scenario/pazarcik.toml`. In the next step, we copy this file into the shared folder. 
```bash
# Copy a local TOML into the container under ./data/config
# ./data/config is the shared folder.
cp example-scenario/pazarcik.toml ./data/config
```

You can freely edit the config file from your host. 

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

### Upload your data
#### [⬆Back to top](#viewing-playback-performance-with-eewpw)

When you connect to the dashboard via your browser (`http://127.0.0.1:8050/` by default), the user interface starts at the `Load` tab with `Upload` and `Refresh list from remote` button. A dropdown widget lists all previous uploads.

**For new files**: Click on the `Upload` (check the dropdown widget first). You can use the `Refresh list from remote` to re-fill the dropdown.

**Caution:** You should not upload the same file each time you work on a specific playback. Once a file is uploaded, it will be stored on the server side (on the locally mounted volume on host machine). Multiple uploads of the same content will only consume the disk space.

After a new upload (or load for pre-existing files), open the `View` panel at the top to visualize the playback performance metrics.

---