# Compose arena services

The [docker-compose.yaml](docker-compose.yaml) creates several containers with ARENA services:

* Web server for ARENA (Nginx)
* Database (MongoDB)
* Pubsub (mosquitto)
* Persistence service
* Auth service
* ARTS
* File Store
* Certbot

Source repositories (such as ARENA-core, ARENA-auth, arena-persist) are submodules of this repo. Containers are created from these files. ARENA-core is served by the nginx container.

Nginx and mosquitto are configured with TLS/SSL using certificates created by certbot (running as a service in a container), which will periodically attempt to renew the certificates. On the first execution, the configuration files must be initialized by running **init.sh**.

## Quick Setup

1. We need [docker](https://docs.docker.com/get-docker/) and [docker-compose](https://docs.docker.com/compose/install/) installed. The [init](init.sh) script needs a bash shell. The ```backup``` service in docker-compose.yaml also assumes the existence of host user ```1001``` (which can be edited to another user).

2. Clone this repo (with ```--recurse-submodules``` to make sure you get the contents of the repositories added as submodules):

```bash
git clone git@github.com:conix-center/arena-services-docker.git --recurse-submodules
```

If ```recurse-submodules``` fails, or you forget to add it in the first clone, you can enter the repo folder and:

```bash
git submodule update --init
```

3. Modify configuration:

- Edit hostname and email addresses in [environment.env](environment.env). This should reflect your setup.

```bash
HOSTNAME="arena.andrew.cmu.edu"
EMAIL="wiselab.develop@gmail.com"
```

4. Run init script:

```bash
 ./init.sh
```

5. If you see no errors; you are good to start all services:

```bash
 docker-compose up -d
```

For more details, see [Init Config](init-config) Section below.

4. Open the file store management interface and change the default admin password (**user**:admin;**pass**:admin). To open the file store, point to ```/storemng``` (e.g. ```https://arena.andrew.cmu.edu/storemng```) in your browser. See details in the [File Store](file-store) Section below.

## Init Config

Before starting services, we need to create the configuration files for the services with the right domains and initialize letsencrypt.

1. Modify configuration:

- Edit hostname and email addresses in [environment.env](environment.env). This should reflect your setup.

2. Run the init script:

```bash
 ./init.sh
```

The init script will generate configuration files (from the templates in **conf/templates**) for the services using the hostname and email configured in **environment.env**, and attempt to create certificates using letsencrypt. **If letsencrypt fails, it will create a self-signed certificate that can be used for testing purposes**.

3. Start all services:

```bash
 docker-compose up -d
```

## File Store

The web server files under ```/store``` (e.g. ```https://arena.andrew.cmu.edu/store```) can be uploaded via a web interface available at ```/storemng```  (e.g. ```https://arena.andrew.cmu.edu/storemng```) . The store admin password should be change on the first execution and other users can then be added.

**Be sure to open the ```/storemng``` URL on your browser and change the *admin* user default password (*admin*).**

## Update Submodules

To update the repositories added as submodules (**ARENA-core** and **arena-persist**), run:

```bash
./update-submodules.sh
```

After updating the submodules, to have the updates of built containers (persist, arts, python-rt) reflected live, you will need to restart the services and rebuild the containers:

```bash
docker-compose down; docker-compose up -d --force-build
```

*  See [Compose Quick Reference](compose-quick-reference) for the description of these commands.

## Files/Folders Description

* **ARENA-core:**	Contents of the ARENA-core repository (submodule).
* **arena-persist:**	Contents of the arena-persist repository (submodule).
* **arena-runtime-simulated:**	Contents of the arena-runtime-simulated repository (submodule).
* **ARENA-auth:**	Contents of the ARENA-auth repository (submodule).
* **arts:**	Contents of the arts repository (submodule).
* **conf:** Configuration files for the services (e.g. certificates, mosquito, nginx, persistence). Most files are generated at init time, using the files in the **templates** folder. Some important files described below
  * *templates/mosquitto.tmpl*: used to generate **mosquitto.conf**. Configures listeners on ports 8833 (mqtt), 9001 (mqtt-ws), 8083 (mqtt-wss) and 8883 (mqtt-tls); certificate files under ```/data/certbot/conf``` are mapped to ```/etc/letsencrypt``` in the container.
  * *templates/arena-web.tmpl*: used to generate **nginx-conf/arena-web.conf**. Configures the web server to serve a proxy to port 9001 under ```/mqtt/```, forwards requests to```/persist/``` to the **arena-persist** service and requests tp ```/storemng``` to the **store** service;  certificate files under ```/data/certbot/conf``` are mapped to ```/etc/letsencrypt``` in the container.
  * *persist-config.json*: configures the mongodb uri to the container service name.
  * *templates/arts-settings.tmpl*: used to generate **arts-settings.py**, the configuration of arts.
  * *templates/auth-config.tmpl*: used to generate **auth-config.json**, the configuration of the auth service.
* **data:** Data files (e,g, certificates generated by certbot, mongodb database, ...).
* **docker-compose.yaml:** Compose file that describes all services.
* **init-letsencrypt.sh:** Initialize certbot. Called by **init.sh**.
* **init.sh:** Initialize config files. See [Init Config](init-config) Section.
* **update-submodules.sh:** Run this to get the latest updates from the repositories added as submodules (**ARENA-core**, **arena-persist**). You will need to restart the services to have the changes live (see [Update Submodules](update-sybmodules)).

## Compose Quick Reference

**Start services and see their output/logs**

- ```docker-compose up``` (add ```--force-build  ``` to build containers after updating submodules)

**Start the services in "detached" (daemon) mode (-d)**

- ```docker-compose up -d``` (add ```--force-recreate  ``` to recreate containers after updating submodules)

**Start just a particular service**

- ```docker-compose start <service name in docker-compose.yml>```

**Stop services**

- ```docker-compose down```

**Restart the services**

- ```docker-compose restart```

**See logs**

- ```docker-compose logs```
