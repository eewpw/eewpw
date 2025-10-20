

# EEWPW Configuration Template

This directory contains the configuration template for the **EEW Performance Viewer (EEWPW)** application.  
The file `eewpw-config-template.toml` defines all supported parameters used by the dashboard to control playback, input data, and visualization behavior.

> **Important** The external files paths defined in the config file need to take 

---

## Quick Start

1. Copy the template to create your working configuration:
   ```bash
   cp eewpw-config-template.toml your_config.toml
   ```
2. Edit `your_config.toml` to adjust paths and parameters for your specific dataset.
3. Multiple simulation profiles can be defined inside a single file using separate `[profiles.<name>]` sections.

---

## Parameter Reference

| Field | Description |
|-------|--------------|
| **origin_time** | Earthquake origin time in UTC. |
| **playback_time** | Playback reference time. Together with `origin_time`, it aligns displayed timestamps with real event times. |
| **earthquakes_timedelta** | Time window (seconds). Only earthquakes within `[time step - timedelta]` are visible on the map. |
| **mmi_distances** | Empirical relation used for MMI estimation (`CY08_worden` or `BA08_worden`). |
| **earthquake_catalog** | Path to a CSV file listing earthquakes. Columns must include:<br>`Otime,longitude,latitude,depth_km,magnitude_type,magnitude,eventID,catalog` |
| **external_mmi_files** | One or more GeoJSON files with external MMI data. |
| **external_rupture_files** | One or more GeoJSON rupture files (semicolon-separated). |
| **moment_rate_function** | Text file describing the moment-rate function. Format: <br><br>```text<br>2023-02-06 01:17:34<br>dt: 0.01<br>Time[s]     Moment_Rate [Nm]<br>0.00        0.0000e+00<br>0.01        2.4079e+07<br>``` |

---

## Example Profile

```toml
[profiles.example]
origin_time = "2023-02-06 10:21:48"
playback_time = "2025-02-10 22:30:18"
earthquakes_timedelta = 600
mmi_distances = "CY08_worden"
earthquake_catalog = "auxdata/combined_earthquake_catalog.csv"
external_mmi_files = "../../daily_json/external_mmi/cont_mmi.json"
external_rupture_files = "rupture1.json; rupture2.json"
moment_rate_function = "../../daily_json/moment_rate_pazarcik.mr"
```

---

## Notes

- You can define multiple profiles under `[profiles.<name>]` to quickly switch between events or scenarios.  
- File paths can be relative to the location of `dashapp.config`. You can also use absolute file paths.  
- The template file itself should not be modified; copy it before editing.

---
