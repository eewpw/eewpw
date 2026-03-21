


# Developer Deployment Notes

This document collects deployment and runtime details that are intentionally kept out of the main [README](../README.md).

The main README is user-oriented and documents the default workflow:
- prepare .env
- run make dirs
- run make up
- run make smoke
- install and use the parser

This document is for developer-facing details such as Compose variants, Redis behavior, and advanced runtime configuration.

## Redis and Compose model

The default deployment is a co-located Docker Compose stack with three services:
- backend
- frontend
- redis

Redis is technically optional at the backend level, but in this project it should be treated as a required system component because it is important for caching and performance.

The main user workflow assumes Redis is present and managed by the default Compose stack.

### Compose variants

The repository includes more than one Compose file.

- `docker-compose.yml` is the default deployment and includes Redis.
- `docker-no-redis-compose.yml` removes Redis from the Compose file, but is intended only for advanced scenarios where Redis is still available externally or managed separately.

This means `docker-no-redis-compose.yml` is not a “no Redis” system design. It is only a different way of providing Redis.

## Using a custom Compose file

When you need a non-default Compose file, pass it explicitly through Make:

```bash
make up COMPOSE_FILE=docker-no-redis-compose.yml
make smoke COMPOSE_FILE=docker-no-redis-compose.yml
make logs COMPOSE_FILE=docker-no-redis-compose.yml
make down COMPOSE_FILE=docker-no-redis-compose.yml
```

Equivalent native Docker Compose commands can also be used:

```bash
docker compose -f docker-no-redis-compose.yml up -d
docker compose -f docker-no-redis-compose.yml down
```

## .env and Redis

The default user workflow should not force users to reason about Redis modes. However, developers may need to control Redis explicitly.

For advanced setups, `REDIS_URL` can be pointed to an externally managed Redis instance, for example:

```env
REDIS_URL=redis://host.docker.internal:6379/0
```

If `REDIS_URL` is not set, the default Compose deployment uses the bundled Redis service.

## DATA_ROOT contract

The deployment repository does not define the semantics of the data stored under `DATA_ROOT`.

Instead, `DATA_ROOT` is a deployment mount contract. By default it is `./data`, and the Makefile creates the required runtime subdirectories such as:
- files
- indexes
- logs
- auxdata
- config
- manifests

These directories are required for runtime mounting and backend operation. The backend owns the data semantics inside them.

## Parser tooling model

The parser is not a Compose service, but it is central to EEWPW workflows because it is the main way to generate EEWPW-compatible input files.

This repository supports parser installation and execution as host-side tooling.

Two practical patterns exist:
- repository-managed helper flow via `make parser-install`, which currently uses `tools/parser-venv`
- manual user-managed virtual environment, with `./venv` as the preferred location

Local leftovers such as old virtual environments should not be treated as part of the deployment contract unless explicitly documented.

## Makefile notes

The Makefile is the primary operational interface for this repository.

Important points:
- `make ensure-env` is the enforcement point for requiring .env
- users are expected to create and edit .env themselves
- `make dirs` prepares runtime directories
- `make up` brings up the default stack
- parser-related targets manage host-side tooling only

## Reproducibility caveat

Floating tags such as `master` are used by default for container images and parser installation sources. Reproducibility is therefore not guaranteed unless tags or revisions are pinned more strictly.