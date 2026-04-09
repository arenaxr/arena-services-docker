# Contributing to ARENA Services Docker

The general Contribution Guide for all ARENA projects can be found [here](https://docs.arenaxr.org/content/contributing.html).

This document covers **development rules and conventions** specific to this repository. These rules are mandatory for all contributors, including automated/agentic coding tools.

## Development Rules

### 1. Dependencies — Pin All Versions

**All dependencies must use exact, pegged versions** (no `^`, `~`, or `*` ranges). This prevents version drift across environments and ensures reproducible builds for security.

## Local Development

To develop `arena-services-docker` scripts or configurations locally:
1. Run `./init.sh -y` to generate local keys and certificates.
2. Use `./localdev.sh` (or `docker-compose -f docker-compose.localdev.yaml up -d`) to deploy the local stack.

## Code Style
- Follow standard shell scripting guidelines (`shellcheck`) for `.sh` files.
- Keep `docker-compose` YAML clean and consistent.

The `arena-services-docker` uses [Release Please](https://github.com/googleapis/release-please) to automate CHANGELOG generation and semantic versioning. Your PR titles *must* follow Conventional Commit standards (e.g., `feat:`, `fix:`, `chore:`).
