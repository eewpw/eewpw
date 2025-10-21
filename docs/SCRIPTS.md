`manage-config.sh` is a script designed to manage the `eewpw-config.toml` configuration file inside the frontend container of the EEWPW project. It allows you to copy, append, view, or delete the configuration file within the running container environment.

## Usage Summary

```bash
manage-config.sh [command] [options] [arguments]

Commands:
  copy <local-file>       Copy a local configuration file into the frontend container.
  append -f <local-file>  Append the contents of a local file to the config inside the container.
  view                   Display the contents of the configuration file inside the container.
  delete                 Remove the configuration file from the container.
```

## Environment Variables

- `EEWPW_COMPOSE_FILE`: Path to the Docker Compose file used to identify the frontend service container. Defaults to `docker-compose.yml` if not set.
- `EEWPW_SERVICE`: Name of the frontend service in the Docker Compose file. Defaults to `frontend`.
- `EEWPW_CONFIG_PATH`: Path to the configuration file inside the frontend container. Defaults to `/app/client/eewpw-config.toml`.

## Command Reference

### copy

**Summary:** Copy a local configuration file into the frontend container, replacing any existing config.

**Usage:**

```bash
manage-config.sh copy /path/to/local-config.toml
```

**Behavior:** This command overwrites the `eewpw-config.toml` inside the frontend container with the specified local file.

### append

**Summary:** Append the contents of a local file to the existing configuration inside the container.

**Usage:**

```bash
manage-config.sh append -f /path/to/local-config-part.toml
```

**Behavior:** Adds the contents of the specified local file to the end of the `eewpw-config.toml` inside the container. The `-f` flag is required to specify the file to append.

### view

**Summary:** Display the current contents of the configuration file inside the frontend container.

**Usage:**

```bash
manage-config.sh view
```

**Behavior:** Outputs the contents of `eewpw-config.toml` to the terminal.

### delete

**Summary:** Remove the configuration file from the frontend container.

**Usage:**

```bash
manage-config.sh delete
```

**Behavior:** Deletes the `eewpw-config.toml` file inside the container, effectively resetting the config.

## Examples

```bash
# Copy a new config file into the container as eewpw-config.toml
manage-config.sh copy ./configs/my-config.toml

# Append additional settings to the existing config
manage-config.sh append -f ./configs/extra-settings.toml

# View the current config inside the container
manage-config.sh view

# Delete the config file from the container
manage-config.sh delete
```

---
