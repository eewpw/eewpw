# Viewing playback performance with EEWPW

Technically, you can already start using the dashboard by opening a browser window and connecting to `http://localhost:8050` (`8050` is the default port). However, in most use cases, you will need to shift the time stamps  so that everything is aligned with the earthquake origin time. Additonally, each scenario will most likely be used with external data files such as MMI contours, moment rate function, earthquake catalog etc.

This document will walk you through the steps needed to prepare your working environment.

## Table of Contents
- [Manage `eewpw-config.toml`](#manage-eewpw-configtoml)
- [Sharing external datasets (MMIs, ruptures, catalogs)](#sharing-external-datasets-mmis-ruptures-catalogs)
- [Check your JSON file](#check-and-re-order-your-json-file)
- [Uploading new data](#upload-your-data)
- [Uploading large JSON files](#uploading-large-json-files)
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
- Time stamps should be in ISO or one of the commonly used formats.

2. The file name we use in this document is `example-scenario/pazarcik.toml`. In the next step, we copy this file into the shared folder. 
```bash
# Copy a local TOML into the container under ./data/config, which is the shared 
# folder. Note that the config file needs to be copied as 'eewpw-config.toml'
cp example-scenario/pazarcik.toml ./data/config/eewpw-config.toml
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

### Check and re-order your JSON file
#### [⬆Back to top](#viewing-playback-performance-with-eewpw)

The `sort_detections_by_time.py` utility script ensures that detection entries inside large EEWPW JSON files are **chronologically ordered** by their `"timestamp"` field while leaving the rest of the JSON structure untouched.

> **Why is this needed?** There is absolutely no harm skipping this step. However, if your JSON content is out of order, the time slider widget will be using the indexes and your analysis will be more confusing: As you progress in time, detections will jump backward.

#### Usage

```bash
python sort_detections_by_time.py <path-to-json> [--output <path>] [--dry] [--drop]
```

#### Arguments

| Argument | Description |
|-----------|-------------|
| `input` | Path to the JSON file to process. |
| `--output` | Optional output path. If omitted, the input file is modified in-place. |
| `--dry` | Dry run: analyze and report, but do **not** write changes. |
| `--drop` | Remove the duplicated JSON blocks from the file. |

#### Behavior

- Automatically detects and sorts:
  - Top-level lists of detections.
  - Lists stored under the `"detections"` key.
- Other structures (e.g. `"annotations"`) are **not** modified.
- Sorting is **stable** and based on the `"timestamp"` value (timestamps **must be** ISO 8601-compatible).
- Reports how many records were out of chronological order before sorting and duplicated information.
- Optionally removes the duplicates.

#### Example 
Recommended: If you run the command **with** `--dry`, it will only provide a summary. 

```bash
python3 scripts/sort_detections_by_time.py ../test-data/plum_20251106_07.json -o ../test-data/plum_20251106_07-sorted.json --drop
```

Output:

```text
[INFO] ../test-data/plum_20251106_07.json
  top-level-list: 23130 records
    Count before    : 23130
    Count after     : 1542
    Requires sorting: True
    Out of order    : 14
    Duplicates rem. : 21588
    First before    : 2025-11-06T18:48:11.000Z
    First after     : 2025-11-06T18:48:11.000Z
    Last  before    : 2025-11-07T15:47:33.000Z
    Last  after     : 2025-11-07T15:47:33.000Z
    Original size   : 1195.21 MB
  [OK] Written to ../test-data/plum_20251106_07-sorted.json
  New file size     : 79.68 MB
```


To confirm, you can run the script again **with** dry option on the sorted JSON:

```bash
python3 scripts/sort_detections_by_time.py ../test-data/plum_20251106_07-sorted.json --dry
```

```text
[INFO] ../test-data/plum_20251106_07-sorted.json
  top-level-list: 1542 records
    Count before    : 1542
    Count after     : 1542
    Requires sorting: False
    Out of order    : 0
    Duplicates rem. : 0
    First before    : 2025-11-06T18:48:11.000Z
    First after     : 2025-11-06T18:48:11.000Z
    Last  before    : 2025-11-07T15:47:33.000Z
    Last  after     : 2025-11-07T15:47:33.000Z
    Original size   : 79.68 MB
  [DRY] No changes written.
```


#### Examples

```bash
# Preview (no write)
python3 sort_detections_by_time.py data/event.json --dry

# Apply sort in-place
python3 sort_detections_by_time.py data/event.json

# Write sorted output to a new file
python3 sort_detections_by_time.py data/event.json --output data/event_sorted.json
```

---


### Upload your data
#### [⬆Back to top](#viewing-playback-performance-with-eewpw)

> **Warning**: The `Upload` functionality is for convenience. It is unlikely that your browser can handle very large data files (e.g. gigabytes). Use the *upload large data* helper script instead.

When you connect to the dashboard via your browser (`http://127.0.0.1:8050/` by default), the user interface starts at the `Load` tab with `Upload` and `Refresh list from remote` button. A dropdown widget lists all previous uploads.

**For new files**: Click on the `Upload` (check the dropdown widget first). You can use the `Refresh list from remote` to re-fill the dropdown.

**Caution:** You should not upload the same file each time you work on a specific playback. Once a file is uploaded, it will be stored on the server side (on the locally mounted volume on host machine). Multiple uploads of the same content will only consume the disk space.

After a new upload (or load for pre-existing files), open the `View` panel at the top to visualize the playback performance metrics.

---

### Uploading Large JSON Files
#### [⬆Back to top](#viewing-playback-performance-with-eewpw)

The EEWPW backend supports uploading very large JSON data files (e.g., >500 MB).
Direct uploads through the web interface are not recommended for such files because browsers cannot handle multi-GB payloads.

Use the helper script instead:
```bash
# Run a dry run for what the script would do
./scripts/upload_large_json.sh --dry /path/to/large.json

# If the script is not executable, try with bash
bash ./scripts/upload_large_json.sh --dry /path/to/large.json

# Upload a large JSON file to your local backend
./scripts/upload_large_json.sh /path/to/large.json

# Or specify a custom backend URL if not using the defaults
./scripts/upload_large_json.sh /path/to/large.json http://myserver:8000
```

The script will:
- Validate that the file exists.
- Use EEWPW_BACKEND_URL if defined, otherwise default to http://localhost:8000.
- Print a short summary and upload the file to the backend’s /files endpoint.

Example output:
```bash
------------------------------------------------------------
EEWPW large JSON upload
  File       : /data/plum_20251106_07.json
  Backend URL: http://localhost:8000/files
------------------------------------------------------------
{"file_id":"c6b4d43e-f4be-480a-acd2-88405cd84f3d","status":"processing","message":null,"progress":0}
Upload finished.
```

---

