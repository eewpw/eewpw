# EEWPW Deployment

[![Backend Build](https://github.com/eewpw/eewpw-backend/actions/workflows/docker-backend.yml/badge.svg?branch=master)](https://github.com/eewpw/eewpw-backend/actions/workflows/docker-backend.yml)
[![Frontend Build](https://github.com/eewpw/eewpw-dashboard/actions/workflows/docker-frontend.yml/badge.svg?branch=master)](https://github.com/eewpw/eewpw-dashboard/actions/workflows/docker-frontend.yml)

> **Acknowledgment:** *Development of EEWPW is supported by the U.S. Geological Survey ShakeAlert project.*

## Summary

This repository is the **deployment entry point** for the *EEW Performance Workpackage (EEWPW)*. It does not contain application code; instead, it orchestrates pre-built Docker images as a runnable system.

The stack consists of a **dashboard** (the web interface you see in your browser), a **backend** service (handles data and communication behind the scenes), and **Redis** (used for caching to improve performance), all managed together via Docker Compose.

EEWPW workflows rely on input files produced by a standalone **eewpw-parser** module. While the parser is not part of this containerized stack, this repository provides support for installing and using it as host-side tooling.

## Prerequisites
#### [⬆Back to top](#eewpw-deployment)

You will need:
- **Git**
- **Docker** and the **Docker Compose plugin**
- **Python 3** (for parser workflows)
- **make** (required for running commands like `make up`, `make smoke`, and `make update`)

For setup instructions (macOS, Linux, Windows, including WSL2 guidance), see [the prerequisites documentation](docs/PREREQUISITES.md)

---


## Installation
#### [⬆Back to top](#eewpw-deployment)

This section covers the full setup required to run EEWPW.  
It includes both the containerized stack and the parser tooling used to generate input data.

---

### Part 1: Start the EEWPW stack

1. Clone this repo and change your directory into it:
   ```bash
   git clone https://github.com/eewpw/eewpw.git
   ```
   ```bash
   cd eewpw
   ```


2. Copy `.env.example` to `.env`. This file contains the deployment settings used by the EEWPW stack.
   ```bash
   cp .env.example .env
   ```


3. Start the container stack:
   ```bash
   make up
   ```

> *Note*: If pulling images fails (e.g. `unauthorized` or `denied`), log in to **GHCR** (GitHub Container Registry) using your GitHub credentials:
> ```bash
> docker login ghcr.io
> ```


4. Verify the installation:
   ```bash
   make smoke
   ```

   The expected output is:

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

   Then open a browser and go to `http://localhost:8050` or `http://127.0.0.1/8050`. You should be able to see the dashboard.


If everything worked as expected, your Docker stack is now up and running. If you are curious, you can also inspect the running containers with:
```bash
docker ps --all --filter "name=eewpw"
```



### Part 2: Install parser tooling (host-side)
The parser is a core component of the EEWPW workflow. It runs on your host machine and is not part of the Docker stack.

Install it with:

```bash
make parser-install
```

This command creates and manages a dedicated environment under `tools/parser-venv` and installs the parser command-line tools there.

The main command most users will use for offline parsing workflows is `eewpw-parse`.

You can use the parser in two equivalent ways. The first runs the tools directly without changing your shell environment. The second activates the environment, which may feel more familiar if you are used to working with Python virtual environments.


**Option A: using the absolute path `tools/parser-venv/bin/`**
```bash
tools/parser-venv/bin/eewpw-parse --help
```


**Option B: activate the environment (optional, if preferred)**
```bash
source tools/parser-venv/bin/activate
eewpw-parse --help
```

When the environment is activated, you can run the parser commands from any directory (you do not need to be in the `eewpw` project root). This can be convenient if your input data lives elsewhere.

> *Hint*: You can explore available parser commands using your shell's tab-completion (e.g. press <Tab> after typing `tools/parser-venv/bin/eewpw-` or `eewpw-` if the environment is activated).
>
> You should see commands such as:
> - `eewpw-parse`
> - `eewpw-parse-live`
> - `eewpw-replay-log`
  

---

## Run an example project
#### [⬆Back to top](#eewpw-deployment)

In this section, we run a complete example workflow using the EEWPW system. The goal is to take raw log files, process them with the parser, and load the resulting EEWPW-compatible JSON files into the dashboard.

We will:

1. Use example raw logs located under `example-data/raw-logs/`
2. Use example parser profile JSON files under `example-data/parser-profiles/profiles/`
3. Run the parser (`eewpw-parse`) with a custom configuration root
4. Generate an output JSON file

### Example structure

The relevant folders are:

```text
example-data/
  raw-logs/
    Elm2020/
      scfinder.log
  parser-profiles/
    profiles/
      scfinder_time_vs_mag.json
      vs_time_vs_mag.json
```

- `raw-logs/` contains input log files to be parsed
- `parser-profiles/profiles/` contains JSON files that define how log lines are interpreted by the parser


### Prepare parser profile JSON files

Before running the parser, we will prepare two parser profile JSON files:

- `example-data/parser-profiles/profiles/scfinder_time_vs_mag.json`
- `example-data/parser-profiles/profiles/vs_time_vs_mag.json`

See the [parser technical guide](docs/tools/parser.md) for a full list of dialects and currently supported file names.


These files define the patterns that the parser searches for in the raw logs. The parser uses them in a `grep`-like way: it scans the logs, finds matching lines, and records them together with their timestamps. These are referred to as `annotations`.

The filenames must stay exactly as shown above.

**Important**: The profile JSON files **must** be placed inside a directory named `profiles/`. The parser expects this structure and will not detect the files if they are placed directly under another directory.

Users can edit the `patterns` section freely. Each entry must contain:

- a pattern identifier (the key; can be any string)
- the pattern string to search for in the log file

A minimal example looks like this:

```json
{
  "algorithm": "finder",
  "dialect": "scfinder",
  "patterns": {
    "1": "length has increased",
    "2": "length has decreased"
  }
}
```

The top-level `algorithm` and `dialect` fields are informational. For this workflow, the main part to edit is `patterns`.

In many cases, these profile JSONs can be reused across runs. Users often keep them in a central location and apply them to similar log files.


### Run the parser

Before running the parser, make sure the output directory exists. If not, create it manually, for example:

```bash
mkdir -p example-data/output
```

A few important points that require your attention:

1. The `--config-root` argument must point to the parent directory that contains the `profiles/` folder (not the `profiles/` folder itself). In this example, it points to `example-data/parser-profiles`, which contains the required `profiles/` subdirectory.

2. Always provide `--config-root` when using custom profile files, otherwise the parser will use its default configuration.

3. The parser automatically selects the correct profile JSON file based on the `--algo` and `--dialect` arguments. The filenames must follow the expected naming convention (for example, `scfinder_time_vs_mag.json` for `finder + scfinder`, and `vs_time_vs_mag.json` for `vs + scvsmag`). These filenames must remain unchanged so that the parser can locate and use them correctly.


Now, we run the parser for finder/scfinder:

```bash
tools/parser-venv/bin/eewpw-parse \
  --algo finder \
  --dialect scfinder \
  --config-root example-data/parser-profiles \
  --mode batch \
  --output example-data/output/finder_scfinder.json \
  example-data/raw-logs/Elm2020/scfinder.log
```

We repeat the same process for the VS example:

```bash
tools/parser-venv/bin/eewpw-parse \
  --algo vs \
  --dialect scvsmag \
  --config-root example-data/parser-profiles \
  --mode batch \
  --output example-data/output/vs_scvsmag.json \
  example-data/raw-logs/Elm2020/scvsmag-processing-info.log
```

You should see the EEWPW-compatible JSON files in `example-data/output/`. Each output file contains detections and annotations extracted from the logs using the defined patterns. \


For a full list of supported algorithms and dialects, see the [parser technical guide](docs/tools/parser.md).


---

## Load results into the dashboard
#### [⬆Back to top](#eewpw-deployment)

### Upload, merge and view

1. Open the dashboard in your browser (`http://localhost:8050` or `http://127.0.0.1:8050`)
2. Upload the generated JSON files from `example-data/output/` using the `Upload file` button
3. Merge the uploaded files to create a combined dataset using the `Create merged dataset` button
4. Switch to the `View` panel and use the time slider to explore the data. 

---

### Configure the dashboard for auxiliary data

The dashboard requires a configuration file to define scenarios and external data.

Copy the example configuration file:

```bash
cp example-data/dashboard-config/Elm2020-demo/eewpw-config.toml data/config/eewpw-config.toml
```

**Important**:
- The configuration file must be named `eewpw-config.toml`
- It must be placed under `data/config/`

---

The configuration file may reference additional data (e.g. GeoJSON files). These must be placed under the `data/auxdata/` directory.

Copy the example auxiliary data:

```bash
cp -r example-data/dashboard-auxdata/Elm2020-demo data/auxdata/
```

Inside the configuration file, paths are defined using `/app/data/...`. This is the container-internal path that maps to your local `data/` directory.

For example:

```toml
external_mmi_files = "/app/data/auxdata/Elm2020-demo/demo-fake-cont-mmi.json"
```

This corresponds to the following location on your machine:

```text
data/auxdata/Elm2020-demo/demo-fake-cont-mmi.json
```

---

### Experiment with the dashboard

Move your mouse to the left of your browser window while on the `View` panel. An auto-hiding control panel will appear. There, you can:

* Load your `dashboard profile` to view the external datasets
* Hide/show layers under the `Display` section
* Toggle the algorithms that are being displayed.

When you need to visualize a new dataset, you can either select a pre-uploaded file under the `Load` panel, or repeat the steps above to start from fresh raw logs.

---

### Recap

The following rules must be respected for EEWPW to work correctly:

**Parser**
- `--config-root` must point to a directory that contains a `profiles/` folder
- Profile JSON files must be placed under `profiles/`
- Profile filenames must follow the expected naming convention (e.g. `scfinder_time_vs_mag.json`, `vs_time_vs_mag.json`)

**Dashboard**
- The configuration file must be named `eewpw-config.toml` and placed under `data/config/`
- All auxiliary files must be placed under `data/auxdata/`
- Paths inside the configuration must use `/app/data/...`
- Paths in the configuration must match the actual directory structure under `data/auxdata/`
