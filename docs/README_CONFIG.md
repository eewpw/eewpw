# EEWPW Configuration Template

The file `eewpw-config-template.toml` defines all supported parameters used by the dashboard to control playback, input data, and visualization behavior.

> **Important:** External file paths in your config (catalogs, MMIs, ruptures, etc.) must be visible **inside the container**. By default, the deployment mounts the host folder `./data/auxdata` into the backend container at `/app/data/auxdata` (read‑only). Use absolute container paths such as `/app/data/auxdata/...` in your config.

---

## Quick Start

1. Copy the template to create your working configuration:
   ```bash
   cp eewpw-config-template.toml your-config.toml
   ```
2. Edit `your-config.toml` to adjust paths and parameters for your dataset.
3. You may define multiple simulation profiles inside a single file using separate `[profiles.<name>]` sections.
4. Use the helper script to copy you new file into the docker container:
    ```bash
    bash scripts/manage-config.sh copy your-config.toml
    ```
---

#### Path rules (for inside Docker)

- All file paths in the configuration file must use absolute container paths under `/app/data`.
- Place your datasets on the **host** machine under `./data/auxdata/...`; they will appear inside the container at `/app/data/auxdata/...`.
- Do NOT use host paths (e.g., `/Users/...`, `C:\...`) — the container cannot see them.
- For a tidier workspace, you can create subfolders.

Example:
```toml
earthquake_catalog = "/app/data/auxdata/pazarcik/earthquake_catalog.csv"
```

### Accessing the container

To inspect files directly inside the container, use the following command:
```bash
docker exec -it eewpw-backend bash
```
Then navigate to the mounted data directory:
```bash
cd /app/data
ls -al
```
Uploaded files are located under `/app/data/files`, logs under `/app/data/logs`, and external datasets under `/app/data/auxdata`.

## Parameter Reference

| Field | Description |
|------|-------------|
| **origin_time** | Earthquake origin time in UTC. |
| **playback_time** | Playback reference time. Together with `origin_time`, it aligns displayed timestamps with real event times. |
| **earthquakes_timedelta** | Time window (seconds). Only earthquakes within `[time step ± timedelta]` are visible on the map. |
| **mmi_distances** | Empirical relation used for MMI estimation (`CY08_worden` or `BA08_worden`). |
| **earthquake_catalog** | Path to a CSV file listing earthquakes. Required columns: `Otime, longitude, latitude, depth_km, magnitude_type, magnitude, eventID, catalog`. |
| **external_mmi_files** | One or more GeoJSON files with external MMI data. If multiple, separate with semicolons. |
| **external_rupture_files** | One or more GeoJSON rupture files. If multiple, separate with semicolons. |
| **moment_rate_function** | Path to a text file with the exact format shown below. |
```
2023-02-06 01:17:34
dt: 0.01
Time[s]     Moment_Rate [Nm]
0.00        0.0000e+00
0.01        2.4079e+07
....        ....
``` 


---

## Example Profile

```toml
[profiles.example]
origin_time = "2023-02-06 10:21:48"
playback_time = "2025-02-10 22:30:18"
earthquakes_timedelta = 600
mmi_distances = "CY08_worden"
earthquake_catalog = "/app/data/auxdata/earthquake_catalog.csv"
external_mmi_files = "/app/data/auxdata/some_mmi.json"
external_rupture_files = "/app/data/auxdata/rupture1.json; /app/data/auxdata/rupture2.json"
moment_rate_function = "/app/data/auxdata/moment_rate_function.mr"
```
---
