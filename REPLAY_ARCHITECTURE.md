# ARENA 3D Replay Architecture Roadmap

This document maps the technical implementation of the ARENA 3D Replay feature, detailing accomplishments and next steps across its system components. For conceptual reasoning, design constraints, and storage logic, please refer to the complementary `REPLAY_DESIGN.md`.

---

## Phase 1: Foundation & Proxy Architecture (Completed)

The foundational infrastructure has been established across the `arena-services-docker`, `arena-account`, and `arena-web-core` workspaces.

### 1. Recording Microservice (`arena-recorder`)
A dedicated backend service built in **Go 1.20** to handle high-throughput, concurrent I/O operations.
- **Service Skeleton**: `main.go` and `api/server.go` expose an HTTP REST API on port `8885` with `/recorder/start` and `/recorder/stop` endpoints.
- **Authentication Setup**: `auth/jwt.go` provides middleware that securely extracts the `mqtt_token` from cookies, verifies the JWT signature against the public key, and enforces proper `publ`/`subs` topic ACLs before allowing recordings to start.
- **Dockerization**: The service is packaged into a minimal `alpine` image and integrated natively into `docker-compose.yaml`. It seamlessly mounts `/conf/persist-config.json` to extract `jwt_service_token` and `jwt_service_user` for authenticated connection to the ARENA MQTT broker.

### 2. Infrastructure & Routing
- **Nginx Reverse Proxy**: Injected a `location ^~ /recorder/` block into the `arena-web.conf.tmpl` templates, enabling external frontend REST traffic to securely hit the Go microservice dynamically.
- **Web Bundler Integration**: `arena-web-core/replay/index.html` is now natively captured by the Parcel bundler workflow, exposing an isolated, read-only 3D spectator viewer disconnected from `build3d` editor mutations.

### 3. Portal UI Triggers
- **Arena-Account Integration**: "Record" buttons have been embedded in the Portal's (`arena-account`) user profile scene list, prompting a SweetAlert modal to trigger backend recordings natively.
- **Editor Hooks**: Added Record buttons into `scenes/index.html` and `build/index.html`.

---

## Phase 2: Data Ingestion & Playback Engine (Next Up)

This phase will focus on actually capturing the live MQTT traffic, flushing it to disk, and parsing it back in the frontend client.

### 1. Ingestion Engine (`mqtt/recorder.go`)
- **Subscription Management**: Dynamically subscribe to `realm/s/<namespace>/<scene>/#` when a validated REST `/recorder/start` request arrives.
- **Event Buffering**: Capture incoming `action: create/update/delete` JSON packets. Trigger and capture the initial scene state (the $t=0$ keyframe) from the persist DB.
- **Storage Strategy**: Stream the buffered packets to chunked `.jsonl` files stored in the dedicated `/recording-store` docker volume mount.
- **Concurrency & Lifecycle**: Enforce max-duration limits and cleanly teardown Goroutines and open file handles when a recording ceases by admin or timeout.

### 2. Playback REST API (`api/server.go`)
- **Session Lookup**: Expose an endpoint that queries available recording IDs/sessions for a given namespace/scene based on the `.jsonl` files generated in the store.
- **File Streaming**: Expose an endpoint to stream the `.jsonl` bytes across HTTP back to the browser securely.

### 3. Local Client Pump (`arena-web-core/src/replay.js`)
- **Fetch & Prime**: Download the replay payload from the REST API into local browser memory. Parse the unique `gltf-model` URL metadata to warm up browser caches preventing scrubbing stutters.
- **Timeline Engine**: Act as an isolated local "pump" that replaces standard ARENA MQTT loop logic natively. Based on a local `playhead` timestamp slider, inject the loaded `.jsonl` messages directly into A-Frame components.
- **Scrubbing Fast-Forward**: Implement programmatic fast-forward logic to rapidly replay object state mutations in memory from the last known keyframe up to the desired seek timeframe.

---

## Phase 3: Watch Parties (Future Implementation)
*Deferred for later due to complex dynamic MQTT ACL proxying requirements.*
- **Backend Pump**: The Go backend becomes the timeline pump, broadcasting the parsed `.jsonl` payloads to an ephemeral real-time topic (e.g., `realm/s/<namespace>/replay_<uuid>`).
- **Spectator Sync**: Users join via standard ARENA clients in a forced "Spectator Mode" (invisible avatars, no publish rights) to view the re-broadcasted history exactly in sync with the Watch Party Host.
