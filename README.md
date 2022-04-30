# Compose arena services

Creates several containers with ARENA services:

* Web server for ARENA (Nginx)
* Database (MongoDB)
* Pubsub (mosquitto)
* Persistence service
* Auth service
* ARTS
* File Store
* Certbot

Source repositories (such as ARENA-core, arena-account, arena-persist) are submodules of this repo. Containers are created from these files. The nginx container serves ARENA-core.

Nginx and mosquitto are configured with TLS/SSL using certificates created by certbot (running as a service in a container), which will periodically attempt to renew the certificates. On the first execution, the configuration files must be initialized by running **init.sh**.

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

## Quick Setup

1. We need [docker](https://docs.docker.com/get-docker/) and [docker-compose](https://docs.docker.com/compose/install/). Our scripts are written for a bash shell. See [Dependencies](#dependenciesassumptions) section for details.

2. Clone this repo (with ```--recurse-submodules``` to make sure you get the contents of the repositories added as submodules):

```bash
git clone https://github.com/conix-center/arena-services-docker.git --recurse-submodules
```

3. Modify configuration:

- Edit hostname and email addresses in [init.env](init.env). This should reflect your setup.

```bash
HOSTNAME=full.domain.name.of.your.host
JITSI_HOSTNAME=full.domain.name.of.your.jitsi.host
EMAIL=nouser@nomail.com
BACKUP_USER=1001:1001
ARENA_DOCKER_REPO_FOLDER=full.path.to.repo.folder
GAUTH_CLIENTID=Google_OAuth_Web_Client_ID
GAUTH_CLIENTSECRET=Google_OAuth_Web_Client_Secret
GAUTH_INSTALLED_CLIENTID=Google_OAuth_Desktop_Client_ID
GAUTH_INSTALLED_CLIENTSECRET=Google_OAuth_Desktop_Client_Secret
DJANGO_SUPERUSER_USERNAME=admin
DJANGO_SUPERUSER_EMAIL=admin@example.com
STORE_ADMIN_USERNAME=admin
```
* ```HOSTNAME``` is the fully qualified domain name (FQDN) of your host. If you don't have a FQDN, you can do a local setup; see [Init Config](#init-config).

* ```JITSI_HOSTNAME``` is the fully qualified domain name (FQDN) of the jitsi server you will use (you can use a [public/managed jitsi instance](https://jitsi.github.io/handbook/docs/community/community-instances/) or [setup your own](https://jitsi.github.io/handbook/docs/devops-guide/)).

* ```EMAIL``` is the email used to get the certificates with [letsencrypt](https://letsencrypt.org/).

* ```BACKUP_USER``` is the ```userid:groupid``` of the *host machine user* that needs to access files backed up by the backup container (must be numberic ids of a host machine user).

* ```ARENA_DOCKER_REPO_FOLDER``` is the full path to the location of this repository e.g. ```/home/user/arena-services-docker```.

* ```GAUTH_CLIENTID``` is the Google Web application Credential Client Id. See setup at [Assumptions > OAuth](README.md/#assumptions).
* ```GAUTH_CLIENTSECRET``` is the Google Web application Credential Client Secret.
* ```GAUTH_INSTALLED_CLIENTID``` is the Google Desktop Credential Client Id.
* ```GAUTH_INSTALLED_CLIENTSECRET``` is the Google Desktop Credential Client Secret.

* ```DJANGO_SUPERUSER_NAME``` and ```DJANGO_SUPERUSER_EMAIL``` are the account admin user and email (usually can be kept as `admin` and `admin@example.com`).

* ```STORE_ADMIN_USERNAME``` the filestore admin user (usually can be kept as `admin`).

> IMPORTANT: The file ```init.env``` is used only the first time you run ```init.sh```; its contents are copied to ```.env``` after the first run, and ```.env``` is the file used at runtime.

> If you are setting up a jitsi server on the same machine, see [Init Config](#init-config) for details.

4. Run init script:

```bash
 ./init.sh
```

> * On the first execution, answer the questions as follows:
>     - _Build js (production instances should skip this step) ? (y/N)_: **N**o (if you are running `./prod.sh` you dont need to build the js).
>     - _Create secret.env ? (y/N)_: **Y**es
>     - _Create RSA key pair ? (y/N)_: **Y**es
>     - _Create Service Tokens ? (y/N)_: **Y**es
>     - _Create a public share on filebrowser ? (y/N)_: **Y**es
>     - _Continue and create config files (backups will be created in conf/)? (y/N)_: **Y**es
>     - _Add server block to redirect requests to Jitsi ? (y/N)_: most setups will want to wanswer **N**o. Answer **Y**es if you are setting up a jitsi server on the same machine.  

The script will attempt to create certificates using [letsencrypt](https://letsencrypt.org/). Self-signed certificates will be created instead if letsencrypt's certbot fails.

> You might need to execute ```sudo ./init.sh``` if [your user does not have permissions to access the docker service](https://docs.docker.com/engine/install/linux-postinstall/).

5. If you see no errors; you are good to start all services:

```bash
 ./prod.sh up
```

> You might need to execute using ```sudo``` (e.g. ```sudo ./prod.sh up```) if your user does not have permission to access the docker service.
> For more details, see [Init Config](#init-config) Section below.
> We also have configurations for development and staging. See the [utility scripts Section](#utility-scripts)

## Dependencies/Assumptions

### Install:

* **docker:** https://docs.docker.com/get-docker/
* **docker-compose:** https://docs.docker.com/compose/install/

### Assumptions:

* **init.sh, prod.sh, dev.sh, staging.sh:** assume a bash shell
* **GNU core utils:** You may need to install GNU core utils to ensure some bash commands we use (`timeout`, ...) are available, **particularly on MacOS**.
* **backup user:**  The ```backup``` container tries to change to the owner of the files backed up to a user indicated in `.env`. This is the ```user:group``` of the *host machine user* that you want to have access to the files backed up by this container.
* **OAuth:** You will need to set up [Google Web OAuth for your domain](https://developers.google.com/identity/protocols/oauth2/web-server) for the ARENA web client as well as [Google Desktop OAuth](https://developers.google.com/identity/protocols/oauth2/native-app) for the ARENA Python and Unity clients. Detailed instructions are available at our [arena-account repo](https://github.com/conix-center/arena-account).

## Init Config

Before starting services, we need to create the configuration files for the services with the right domains and create certificates (using letsencrypt/openssl).

> NOTE: On MacOS, you will need to install GNU core utils
> ```bash
> brew install coreutils
> export PATH="/usr/local/opt/coreutils/libexec/gnubin:$PATH"
> ```

1. Modify configuration:

- Edit hostname, email address and backup user (```user:group``` of the *host machine user* that needs to access the files backed up by the backup container configured in [docker-compose.prod.yaml](docker-compose.prod.yaml)) in the file [init.env](init.env). This should reflect your setup.
- Insert the [Google Auth Web Client ID/Secret for your setup](https://developers.google.com/identity/protocols/oauth2/web-server) and the [Google Auth Limited-Input Client ID/Secret for your setup](https://developers.google.com/identity/protocols/oauth2/limited-input-device).

> ### Local setup
>
> If you want a local setup (usually for development), you can configure ```HOSTNAME``` in the file ```init.env``` to a name that resolves locally on your machine (our script recognizes ```localhost```, or ```*.local``` as a local name):
>
> ```bash
> HOSTNAME=localhost
> ```
> This will result in creating a self-signed certificate to be used with the services. This (`HOSTNAME`) is the name you will enter in your browser: `https://localhost`
>
> * **Make sure the above name resolves in your system (by adding it to [the `hosts` file](https://en.wikipedia.org/wiki/Hosts_(file))**.
> * Note: The file ```init.env``` is used only the first time you run ```init.sh```; its contents are copied to ```.env``` after the first run, and ```.env``` is the file used at runtime.

> ### Setup (public) jitsi in the same machine
>
> If you are going to setup a jitsi instance in the same machine, add the jitsi hostname to `.env`:
> ```
> JITSI_HOSTNAME=<jitsi-hostname>
> ```
> The jitsi hostname should be a DNS CNAME to the machine's IP. When asked (by `init.sh`) to  configure nginx to redirect http requests to a Jitsi virtual host, reply '**Y**es'.

2. Run the init script:

```bash
 ./init.sh
```

The first time you run the script, you will want to answer **Y**es to all questions.

The init script will generate configuration files (from the templates in [conf-templates](conf-templates)) for the services using the hostname and email configured in [init.env](init.env), and attempt to create certificates using letsencrypt. **If letsencrypt fails, it will create a self-signed certificate that can be used for testing purposes**.

> You might need to execute ```sudo  ./init.sh``` if [your user does not have permissions to access the docker service](https://docs.docker.com/engine/install/linux-postinstall/).

> IMPORTANT: The file ```init.env``` is used only the first time you run ```init.sh```; its contents are copied to ```.env``` after the first run, and ```.env``` is the file used at runtime.

3. Start all services:

- For production:
```bash
  ./prod.sh up -d
```

- For staging (adds a dev folder on the webserver):
```bash
 ./staging.sh up -d
```

- For development (no monitoring/backups):
```bash
 ./dev.sh up -d
```

> You might need to execute the above commands with ```sudo``` (e.g. ```sudo ./prod.sh up```) if [your user does not have permissions to access the docker service](https://docs.docker.com/engine/install/linux-postinstall/).
> See [utility scripts](#utility-scripts) for details.

## Update Submodules

To update the repositories added as submodules (**ARENA-core** and **arena-persist**), run:

```bash
./update-submodules.sh
```

After updating the submodules, to have the updates of built containers (persist, arts, python-rt) reflected live, you will need to restart the services and rebuild the containers as follows.

- For production:
```bash
[./prod.sh | ./staging.sh | ./dev.sh] up -d --force-recreate --build
```

* Use ```prod.sh```, ```staging.sh``` or ```dev.sh``` depending on which configuration you want to use.
> You might need to execute the above commands with ```sudo``` if [your user does not have permissions to access the docker service](https://docs.docker.com/engine/install/linux-postinstall/).
> See [utility scripts](#utility-scripts) for the description of these commands.

## Files/Folders Description

* **ARENA-core:** Contents of the ARENA-core repository (submodule).
* **arena-persist:**  Contents of the arena-persist repository (submodule).
* **arena-runtime-simulated:**  Contents of the arena-runtime-simulated repository (submodule).
* **arena-account:** Contents of the arena-account repository (submodule).
* **arts:** Contents of the arts repository (submodule).
* **conf:** Configuration files for the services (e.g. certificates, mosquito, nginx, persistence). These files are generated by ```init.sh```, using the files in the **conf-templates** folder.
* **conf-templates:** Templates of the configuration files for the services.Some important files described below:
  * *conf-templates/mosquitto.conf.tmpl*: used to generate **conf/mosquitto.conf**. Configures listeners on ports 8833 (mqtt), 9001 (mqtt-ws), 8083 (mqtt-wss) and 8883 (mqtt-tls); certificate files under ```/data/certbot/conf``` are mapped to ```/etc/letsencrypt``` in the container.
  * *conf-templates/arena-web.conf.tmpl*: used to generate **conf/arena-web.conf**. Configures the web server to serve a proxy to port 9001 under ```/mqtt/```, forwards requests to```/persist/``` to the **arena-persist** service and requests tp ```/storemng``` to the **store** service;  certificate files under ```/data/certbot/conf``` are mapped to ```/etc/letsencrypt``` in the container.
  * *conf-templates/persist-config.json.tmpl*: used to generate **conf/persist-config.json** and configures the mongodb uri to the container service name.
  * *conf-templates/arts-settings.py.tmpl*: used to generate **conf/arts-settings.py**, the configuration of arts.
  * *conf-templates/arena-account-settings.py.tmpl*: used to generate **conf/arena-account-settings.py**, the configuration of the auth service.
* **data:** Data files (e,g, certificates generated by certbot, mongodb database, ...).
* **init-utils:** Files to create a container with all dependencies of the init scripts.
* **docker-compose.override.yaml:** Compose file that describes services. This is the file used by default by ```docker-compose``` and is intended for development purposes
* **docker-compose.yaml:** Compose file that describes the base services. Use this with the ```docker-compose.prod.yaml``` to create the production config.
* **docker-compose.prod.yaml:** Compose file that describes production services. Relies on the base config in ```docker-compose.yaml``` to create the final production config.
* **docker-compose.staging.yaml:** Compose file that describes adds a dev folder on the web server. Relies on the base config in ```docker-compose.yaml``` to create the final staging config.
* **init-letsencrypt.sh:** Initialize certbot. Called by **init.sh**.
* **init.sh:** Initialize config files. See [Init Config](#init-config) Section.
* **update-submodules.sh:** Run this to get the latest updates from the repositories added as submodules (**ARENA-core**, **arena-persist**). You will need to restart the services to have the changes live (see [Update Submodules](#update-submodules)).
* **update-versions.sh:** Update the versions indicated in ```VERSION``` by looking at the tags in the submodules.
* **VERSION:** Release versions of the arena services stack used by the production deployment (```docker-compose.prod.yaml```).

## Utility Scripts

You can use the ```prod.sh```, ```dev.sh``` and  ```staging.sh``` utility scripts (with a bash shell). These scripts call ```docker-compose``` with the right compose config files, where some files [extend each other](https://docs.docker.com/compose/extends/). The docker compose config files are used as follows:
* **prod.sh**: ```docker-compose.yaml``` and ```docker-compose.prod.yaml```
* **staging.sh**: ```docker-compose.yaml``` and ```docker-compose.staging.yaml```
* **dev.sh**: ```docker-compose.override.yaml```

Call the script by passing any ```docker-compose``` subcommands (such as ```up```, ```down```), e.g.:
* ```./prod.sh up -d```
* ```./prod.sh down```
* ```./dev.sh up```
* ...

> *You might need to execute the scripts with ```sudo``` if [your user does not have permissions to access the docker service](https://docs.docker.com/engine/install/linux-postinstall/)*.

### Script Arguments Quick Reference

The utility scripts pass the arguments to **docker-compose**. You can use them with all [**docker-compose** subcommands](https://docs.docker.com/compose/reference/). Here is a quick reference/examples of subcommands.

**Start services and see their output/logs**

- ```[/prod.sh | d/ev.sh | ./staging.sh] up``` (add ```--force-recreate --build``` to recreate abd build containers; useful after updating code in submodules)

**Start the services in "detached" (daemon) mode (-d)**

- ```[/prod.sh | d/ev.sh | ./staging.sh] up -d``` (add ```--force-recreate  --build``` to recreate abd build containers)

**Start just a particular service**

- ```[/prod.sh | d/ev.sh | ./staging.sh] up <service name in docker-compose*.yaml>```

**Stop services**

- ```[/prod.sh | d/ev.sh | ./staging.sh] down```

**Start a particular service**

- ```[/prod.sh | d/ev.sh | ./staging.sh] stop <service name in docker-compose*.yaml>```

**See logs**

- ```[/prod.sh | d/ev.sh | ./staging.sh] logs```

## Production release/deployment

### Release

To release an arena services stack version, make sure all submodules are pointing the version you want to release (you can run ```update-submodules.sh``` to update to the latest) update the versions in ```VERSION``` using the ```update-versions.sh``` script. This script asks for the new version of the arena services stack to be released and fetches the versions from the submodules. After running this script, you can use the github web interface to create that release. **Note that releases on this repo will be automatically deployed.**

### Deployment

For a production deployment, start the services stack using ```prod.sh```. This script starts the compose stack from ```docker-compose.prod.yaml```, which uses the versions described in the ```VERSION``` file (these are the release versions of the images started).

After starting the stack, you can see versions deployed at ```http://<arena-instance>/conf/versions.html```
