# Prerequisites for EEWPW

This guide explains what you need on your machine **before** you continue with the main [README](../README.md).


## A short note about the `make` tool:

In this repository, the `make` tool (listed below in the OS setup section) is used for convenience to simplify common tasks. 

Instead of typing these long Docker commands

```bash
docker compose -f docker-compose.yml up -d
```

you can run shorter commands like: 

```bash
make up
``` 

The `make` tool is optional. If you do not install `make`, you can still use EEWPW, but you will need to run the equivalent Docker commands manually. For most users, installing `make` is strongly recommended because it makes the workflow simpler and less error-prone.


## Operating-system-specific setup
Install or verify these tools/software for your operating system:

### macOS

- **Git**: https://git-scm.com/downloads
- **Docker Desktop**: https://www.docker.com/products/docker-desktop/
- **Python 3**: https://www.python.org/downloads/
- **make** (usually preinstalled; otherwise install via Xcode Command Line Tools)

Run EEWPW commands in a standard **Terminal** app.

### Linux

- **Git**: https://git-scm.com/downloads
- **Docker Engine**: https://docs.docker.com/engine/install/
- **Docker Compose plugin** 

    *Note*: The compose plugin is included in modern Docker installs. You can check it with: `docker compose version`. If not included, you need to follow your Docker version instructions and install the compose plugin manually. 

- **Python 3**: https://www.python.org/downloads/
- **make** (install via your package manager, e.g. `apt`, `yum`, `dnf`)

Run EEWPW commands in your normal shell.

### Windows (recommended setup)

- **Git**: https://git-scm.com/downloads
- **Docker Desktop**: https://www.docker.com/products/docker-desktop/
- **Python 3**: https://www.python.org/downloads/
- **WSL2 (Windows Subsystem for Linux)**: https://learn.microsoft.com/windows/wsl/install

  *Note*: **WSL2** lets you run a Linux terminal inside Windows. You can install it by following the official Microsoft guide linked above. 

- **Ubuntu for WSL2** (install from Microsoft Store after enabling WSL2)
- **`make`** inside Ubuntu
    
    If `make` is missing inside Ubuntu (e.g. `make --version` returns command not found), install it with:

    ```bash
    sudo apt update
    sudo apt install make
    ```

**Important:** Run EEWPW commands in the **Ubuntu terminal inside WSL2**, not in CMD.


## Quick checks before continuing

Before continuing with the main [README](../README.md), check that the required tools are available.

### Check Docker

```bash
docker --version
docker compose version
```

### Check Python

```bash
python3 --version
```

### Check Git

```bash
git --version
```

### Check make

```bash
make --version
```

If one of these commands fails, install that tool first before continuing. Expected example output:

```bash
$ docker --version
Docker version 29.2.1, build a5c7197

$ docker compose version
Docker Compose version v5.0.2

$ python3 --version
Python 3.12.7

$ git --version
git version 2.51.2

$ make --version
GNU Make 3.81
Copyright (C) 2006 Free Software Foundation, Inc.
This is free software; see the source for copying conditions.
There is NO warranty; not even for MERCHANTABILITY or FITNESS FOR A
PARTICULAR PURPOSE.
```

## After this

Once the checks above are complete, return to the main [README](../README.md) and continue with the installation steps.