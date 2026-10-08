## Project Overview

ConnectGH Document Server — fork of ONLYOFFICE Docker-DocumentServer. Single-container Docker image for ONLYOFFICE Docs (pinned to 9.4.0) with all services (docservice, converter, nginx, PostgreSQL, Redis, RabbitMQ) managed by Supervisor.

## Tech Stack

Docker, Docker BuildX, Bash, Nginx, Supervisor, PostgreSQL/MySQL/MariaDB/MSSQL/Oracle, Redis, RabbitMQ/ActiveMQ

## Project Structure

```
Dockerfile              — Main image (Ubuntu 24.04 base)
production.dockerfile   — Stable/release image builder
docker-compose.yml          — Local dev CE (documentserver only, no bundled services)
docker-compose.enterprise.yml — Local dev EE (with postgres, rabbitmq, redis)
docker-compose.developer.yml  — Local dev DE (with postgres, rabbitmq, redis)
docker-bake.hcl         — BuildX multi-platform config
Makefile                — Build system (image, deploy, clean targets)
run-document-server.sh  — Main entrypoint script (842 lines)
config/supervisor/ds/        — Supervisor service configs (ds, ds-adminpanel, ds-converter, ds-docservice, ds-example, ds-metrics)
config/supervisor/supervisor — Shell script for supervisord startup
tests/                  — Integration tests (DB/AMQP/SSL matrix)
fonts/                  — Custom fonts directory
oracle/                 — Oracle SQLPlus wrapper
```

## Build & Run

```bash
# Build with Makefile
make image                         # 9.4.0 by default
make image PRODUCT_VERSION=9.4.1   # other upstream release

# Build with Docker
docker build --target documentserver-community -t connectgh/documentserver .

# Run
docker run -i -t -d -p 80:80 connectgh/documentserver

# Docker Compose Community Edition
docker-compose up -d

# Docker Compose Enterprise Edition
docker compose -f docker-compose.enterprise.yml up -d

# Run tests
cd tests && ./test.sh
```

## Key Patterns

- Branding: image names, compose service/container names, labels and docs say ConnectGH. `COMPANY_NAME=onlyoffice`, in-container paths (`/var/www/onlyoffice`, `/etc/onlyoffice`), `ONLYOFFICE_*` env vars and the editor UI come from the upstream package — don't rename them
- Upstream version: `PACKAGE_VERSION` in Dockerfile, `PRODUCT_VERSION` in Makefile, `PACKAGE_VERSION` in docker-bake.hcl — bump together
- CI: `.github/workflows/build.yml` builds every edition on amd64 and arm64 for PRs and pushes to `develop`/`master`, checks the installed package matches `PACKAGE_VERSION`, and waits for `/healthcheck`. `publish.yml` runs on pushes to `master`: builds + health-checks Community on amd64/arm64 and pushes `connectgh/documentserver:<version>`, `<major.minor>`, `latest` (needs `DOCKERHUB_USERNAME`/`DOCKERHUB_TOKEN` secrets). Only Community is published. `trivy-ds.yml`/`zap-ds.yaml` are manual upstream scanners that target ONLYOFFICE's images
- Single-container architecture: all services in one image via Supervisor
- Three editions: Community, Enterprise (-ee), Developer (-de)
- `run-document-server.sh` handles all configuration, DB init, service startup
- Multi-arch support: amd64, arm64
- Multiple database backends via DB_TYPE environment variable
- SSL/TLS with Let's Encrypt integration (Certbot)
- Non-root execution possible

## Review Focus

**Security**: JWT validation, SSL/TLS config, credential handling in entrypoint
**Shell**: `run-document-server.sh` is critical — quoting, error handling, DB initialization logic
**Docker**: Image size, layer count, base image updates
**Supervisor**: Service configs, process dependencies, restart policies
**Config**: Default ports, exposed services, database connection strings

## Git Workflow

- **Main branch**: `master`
- **Integration branch**: `develop`
- **Branch naming**: `feature/*`, `bugfix/*`, `hotfix/*`, `release/*`
