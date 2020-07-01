# Compose arena services

The [docker-compose.yaml](docker-compose.yaml) creates several containers with ARENA services:

* Web server for ARENA (Nginx)
* Database (MongoDB)
* Pubsub (mosquitto)
* Persistence service 
* File Upload (Droppy)
* Certbot

We clone **ARENA-core** and **arena-persist** to create containers with these services. The **ARENA-core** files are copied into the web server container (called ```arena-web```) at build time (thus, updates to ARENA-core require a rebuild of the container). 

Nginx and mosquitto are configured with TLS/SSL using certificates created by certbot (running as a service in a container), which will periodically attempt to renew the certificates. On the first execution, certbot must be initialized. See [Certbot Init](certbot-init) Section below.

## Quick Setup

1. Make sure you have [docker](https://docs.docker.com/get-docker/), [docker-compose](https://docs.docker.com/compose/install/) and [openssl](https://www.openssl.org/) installed.
2. Clone this repo (with ```--recurse-submodules``` to make sure you get the contents of the repositories added as submodules): 
   * ```git clone git@github.com:conix-center/arena-services-docker.git --recurse-submodules```

3. Configure and init certbot.  Make sure that [init-letsencrypt.sh](init-letsencrypt.sh) has the right information about the domain(s) and execute it. See [Certbot Init](certbot-init) Section below.

4. Run the init script:

```bash
 ./init-letsencrypt.sh
```

5. Create a user and password to protect the web server's ```/upload/``` area by opening the ```/upload``` URL (e.g. ```https://mr.andrew.cmu.edu/upload```)  in your browser. See details in the [Asset Upload](asset-upload) Section below.

6. Start services:

```bash
 docker-compose up
```

* After checking the output, start as daemon (see [Compose Quick Reference](compose-quick-reference)).

## Files/Folders Description

* **ARENA-core:**	Contents of the ARENA-core repository (submodule)	
* **arena-persist:**	Contents of the arena-persist repository (submodule)	
* **conf:** Configuration files for the services (e.g. certificates, mosquito, nginx, persistence). Some important files described below.	
  * *mosquitto.conf*: configures listners on ports 8833 (mqtt), 9001 (mqtt-ws), 8083 (mqtt-wss) and 8883 (mqtt-tls); certificate files under ```data/certs``` are mapped to ```/certs``` in the container.
  * *nginx-default-site.conf*: configures the webserver to serve a proxy to port 9001 under ```/mqtt/``` and forwards requests to```/persist/``` to the **arena-persist** service;  certificate files under ```data/certs``` are mapped to ```/certs``` in the container.
  * *persist-config.json*: configures the mongodb uri to the container service name. 
* **data:** Data files (e,g, mongodb database, uploaded files)
* **docker-compose.yaml:** Compose file that describes all services	
* **init-letsencrypt.sh:** Initialize certbot. . See [Certbot Init](certbot-init) Section below.
* **update-submodules.sh:** Run this to get the latest updates from the repositories added as submodules (ARENA-core, arena-persist). You will need to restart the services to have the changes online (see [Compose Quick Reference](compose-quick-reference)).

## Certbot Init

Before starting services, we need to configure certbot with the right domains and then execute **init-letsencrypt.sh** (needs [openssl](https://www.openssl.org/)):

1. Modify configuration:

- Add domains and email addresses to **init-letsencrypt.sh**  (e.g. ```mr.andrew.cmu.edu```) 
- Edit primary domain (the first one you added to **init-letsencrypt.sh**; e.g. ```mr.andrew.cmu.edu```) in **data/nginx/arena.conf**

2. Run the init script:

```bash
 ./init-letsencrypt.sh
```

## Assets Upload

The web server files under ```/assets``` (e.g. ```https://mr.andrew.cmu.edu/assets```) can be uploaded via a web interface available at ```/upload```  (e.g. ```https://mr.andrew.cmu.edu/upload```) . The uploads area is protected by a user and password that needs to be setup the first time we access it. 

**Be sure to open the ```/upload``` URL on your browser and setup the user and password. **

## Compose Quick Reference

**Start services and see their output/logs**

- ```docker-compose up``` (add ```--force-build  ``` to build containers after updating submodules)

**Start the services in "detached" (daemon) mode (-d)**

- ```docker-compose up -d``` (add ```--force-build  ``` to build containers after updating submodules)

**Start just a particular service**

- ```docker-compose start <service name in docker-compose.yml>```

**Stop services**

- ```docker-compose down -d```

**Restart the services**

- ```docker-compose restart```

**See logs** 

- ```docker-compose logs```

