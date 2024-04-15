# ARENA Demo Setup (recommended for a quick spin)

Creates several containers with ARENA services:

* Web server for ARENA (Nginx)
* Database (MongoDB)
* Pubsub (mosquitto)
* Persistence service
* Auth service
* ARTS
* File Store
* Certbot

## Hardware
ARENA has some minimum hardware requirements to run:
- CPU: 4 cores (more will allow you to scale more users)
- RAM: 8 GB (more will allow you to scale more users)
- Disk: No minimum (more will give your users more room to store models)
- Ports: For MQTT and [Jitsi](https://jitsi.github.io/handbook/docs/devops-guide/devops-guide-quickstart/#setup-and-configure-your-firewall)
  - 80/tcp (web)
  - 443/tcp (web)
  - 3000/tcp (jitsi)
  - 8883/tcp (mqtt)
  - 9700/tcp (jitsi)
  - 10000/udp (jitsi)

## Quick Start

1. We need [docker](https://docs.docker.com/get-docker/) and [docker-compose](https://docs.docker.com/compose/install/). Our scripts are written for a bash shell. See [Dependencies](#dependenciesassumptions) section for details.

2. Clone this repo's **demo** branch

```bash
git clone -b demo --single-branch https://github.com/arenaxr/arena-services-docker.git
```

3. Startup the demo services:

```bash
 ./demo.sh
```
> You might need to execute using ```sudo``` (e.g. ```sudo ./demo.sh up```) if your user does not have permission to access the docker service.
> For more details, see [Init Config](#init-config) Section below.
> We also have configurations for production, development and staging. See the [utility scripts Section](#utility-scripts)

If you see no errors, you should be able to point your browser to `https://localhost`. You will have get past the security warnings due to a self-signed certificate, **and use anonymous login** (using OAuth requires additional setup; see [Init Config](#init-config) Section below).