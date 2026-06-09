# Agent Guide

Orientation for agents (and humans) working in this repo. Detailed docs live in the files below — this file is just the index.

## Start here
- [README.md](README.md) — what ARENA Services Docker is, Docker Compose orchestration of ARENA services (Nginx, MQTT, persistence, accounts, web client, file store).
- [REQUIREMENTS.md](REQUIREMENTS.md) — machine- and human-readable reference for features, architecture, and source layout.

## Conventions & development rules
- [CONTRIBUTING.md](CONTRIBUTING.md) — mandatory rules for all contributors, **including agents**: development conventions specific to this repository.

## Sub-services
Each sub-service has its own documentation set:

### arena-web-core
- [arena-web-core/README.md](arena-web-core/README.md) — ARENA browser client (A-Frame / three.js), multiuser XR environment.
- [arena-web-core/REQUIREMENTS.md](arena-web-core/REQUIREMENTS.md) — features, architecture, and source layout for the web client.
- [arena-web-core/CONTRIBUTING.md](arena-web-core/CONTRIBUTING.md) — development rules for arena-web-core (MQTT topics, A-Frame components, etc.).
- [arena-web-core/CHANGELOG.md](arena-web-core/CHANGELOG.md) — generated release history.

### arena-account
- [arena-account/README.md](arena-account/README.md) — Django user account management and authentication for the ARENA.
- [arena-account/REQUIREMENTS.md](arena-account/REQUIREMENTS.md) — features, architecture, and source layout for the account service.
- [arena-account/CONTRIBUTING.md](arena-account/CONTRIBUTING.md) — development rules for arena-account (dependency pinning, etc.).
- [arena-account/CHANGELOG.md](arena-account/CHANGELOG.md) — generated release history.
- [arena-account/docs/mqtt-v1.md](arena-account/docs/mqtt-v1.md) — sample MQTT JWT topic permissions v1 (deprecated).
- [arena-account/docs/mqtt-v2.md](arena-account/docs/mqtt-v2.md) — sample MQTT JWT topic permissions v2.

### arena-persist
- [arena-persist/README.md](arena-persist/README.md) — persistence service: listens on MQTT for ARENA objects to save to MongoDB.
- [arena-persist/REQUIREMENTS.md](arena-persist/REQUIREMENTS.md) — features, architecture, and source layout for the persistence service.
- [arena-persist/CONTRIBUTING.md](arena-persist/CONTRIBUTING.md) — development rules for arena-persist.
- [arena-persist/CHANGELOG.md](arena-persist/CHANGELOG.md) — generated release history.

### arena-recorder
- [arena-recorder/README.md](arena-recorder/README.md) — Go-based 3D Replay Recorder microservice: ingests, buffers, and stores MQTT messages for replay.
- [arena-recorder/REQUIREMENTS.md](arena-recorder/REQUIREMENTS.md) — features, architecture, and source layout for the recorder service.
- [arena-recorder/CONTRIBUTING.md](arena-recorder/CONTRIBUTING.md) — development rules for arena-recorder.
- [arena-recorder/CHANGELOG.md](arena-recorder/CHANGELOG.md) — generated release history.

## Infrastructure & utilities
- [conf-templates/README.md](conf-templates/README.md) — config templates for services (nginx, mosquitto, account, persist, web client); variables replaced via `envsubst`.
- [init-utils/README.md](init-utils/README.md) — init script dependencies Docker container (bash, python, envsubst, certbot, etc.).
- [store/models/README.md](store/models/README.md) — 3D models used in ARENA (most have moved to the file store).
