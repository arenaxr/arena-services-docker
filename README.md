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

Source repositories (such as arena-web-core, arena-account, arena-persist) are submodules of this repo. Containers are created from these files. The nginx container serves arena-web-core.

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

## Demo Setup (Recommended for a quick spin)

1. We need [docker](https://docs.docker.com/get-docker/) and [docker-compose](https://docs.docker.com/compose/install/). Our scripts are written for a bash shell. See [Dependencies](#dependenciesassumptions) section for details.

2. Clone this repo's **demo** branch

```bash
git clone -b demo --single-branch https://github.com/arenaxr/arena-services-docker.git
```
> If you plan to use other configurations later, remove the `--single-branch`:
> ```bash
> git clone --recurse-submodules https://github.com/arenaxr/arena-services-docker.git
> ```
>
> You can always get the repo's branches and submodules later:
> ```bash
> git fetch --all
> git submodule update --init --recursive
> ```

3. Startup the demo services:

```bash
 ./demo.sh up
```
> You might need to execute using ```sudo``` (e.g. ```sudo ./demo.sh up```) if your user does not have permission to access the docker service.
> For more details, see [Init Config](#init-config) Section below.
> We also have configurations for production, development and staging. See the [utility scripts Section](#utility-scripts)

If you see no errors, you should be able to point your browser to `https://localhost`. You will have get past the security warnings due to a self-signed certificate, **and use anonymous login** (using OAuth requires additional setup; see [Init Config](#init-config) Section below).

## Dependencies/Assumptions

### Install:

* **docker:** https://docs.docker.com/get-docker/
* **docker-compose:** https://docs.docker.com/compose/install/

> **WARNING**: If you use the **dev.sh** script below, it requres you to build the web source manually, so you will need also: 
> * **nodejs:** https://nodejs.org
> * **parcel:** https://www.npmjs.com/package/parcel

### Assumptions:

* **init.sh, prod.sh, dev.sh, staging.sh:** assume a bash shell
* **GNU core utils:** You may need to install GNU core utils to ensure some bash commands we use (`timeout`, ...) are available, **particularly on MacOS**.
* **backup user:**  The ```backup``` container tries to change to the owner of the files backed up to a user indicated in `.env`. This is the ```user:group``` of the *host machine user* that you want to have access to the files backed up by this container.
* **OAuth:** You will need to set up [Google Web OAuth for your domain](https://developers.google.com/identity/protocols/oauth2/web-server) for the ARENA web client as well as [Google Desktop OAuth](https://developers.google.com/identity/protocols/oauth2/native-app) for the ARENA Python and Unity clients. Detailed instructions are available at our [arena-account repo](https://github.com/arenaxr/arena-account).

## Init Config

Before starting services, we need to create the configuration files for the services with the right domains and create certificates (using letsencrypt/openssl).

First, make sure you have an up to date the master branch with submodules:
```bash
git checkout master
git pull
git submodule update --init --recursive
```

> NOTE: On MacOS, you will need to install GNU core utils
> ```bash
> brew install coreutils
> export PATH="/usr/local/opt/coreutils/libexec/gnubin:$PATH"
> ```

The 'init.env' file has the following configuration that should be updated to reflect your setup:

* ```HOSTNAME``` is the fully qualified domain name (FQDN) of your host. If you don't have a FQDN, you can do a local setup;

* ```JITSI_HOSTNAME``` is the fully qualified domain name (FQDN) of the jitsi server you will use (you can use a public/managed jitsi instance or [setup your own](https://jitsi.github.io/handbook/docs/devops-guide/)).

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

The minimal set of edits you will have to perform is:

- Edit hostname, email address and backup user (```user:group``` of the *host machine user* that needs to access the files backed up by the backup container configured in [docker-compose.prod.yaml](docker-compose.prod.yaml)) in the file [init.env](init.env). This should reflect your setup.
- Insert the [Google Auth Web Client ID/Secret for your setup](https://developers.google.com/identity/protocols/oauth2/web-server) and the [Google Auth Limited-Input Client ID/Secret for your setup](https://developers.google.com/identity/protocols/oauth2/limited-input-device). See setup at [Assumptions > OAuth](README.md/#assumptions).


> ### Local setup
>
> If you want a local setup (usually for development), you can configure ```HOSTNAME``` in the file ```init.env``` to a name that resolves locally on your machine (our script recognizes ```localhost```, ```*.local```, or ```*.arena``` as a local name):
>
> ```bash
> HOSTNAME=localhost
> ```
> This will result in creating a self-signed certificate to be used with the services. This (`HOSTNAME`) is the name you will enter in your browser: `https://localhost`
>
> * **Make sure the above name resolves in your system (by adding it to [the `hosts` file](https://en.wikipedia.org/wiki/Hosts_(file))**.
> * Note: The file ```init.env``` is used only the first time you run ```init.sh```; its contents are copied to ```.env``` after the first run, and ```.env``` is the file used at runtime.

2. Run the init script:

```bash
 ./init.sh -y
```

The first time you run the script, you will want to answer **Y**es to execute all optional sections: create secrets, root keys, service tokens, config files, and certificates. The `-y` argument automatically answers 'yes' to all questions.

> #### `init.sh` Arguments 
>`init.sh` supports the following arguments: 
>* -y indicates that we answer 'yes' to all questions
>* -t passes the 'staging' flag to letsencrypt to avoid request limits
>* -s forces the creation of a self-signed certificate 
>* -n skip certificate creation 
>* -c create config files ONLY (skip everything else) 
>* -r create certificates ONLY (skip everything else) 
>* -b build arena-web-core js ONLY (skip everything else) 
>* -h print help

The init script will generate configuration files (from the templates in [conf-templates](conf-templates)) for the services using the hostname and email configured in [init.env](init.env), and attempt to create certificates using letsencrypt. **If letsencrypt fails, it will create a self-signed certificate that can be used for testing purposes**.

> You might need to execute ```sudo  ./init.sh -y``` if [your user does not have permissions to access the docker service](https://docs.docker.com/engine/install/linux-postinstall/).

> **IMPORTANT**: The file ```init.env``` is used only the first time you run ```init.sh```; its contents are copied to ```.env``` after the first run, and ```.env``` is the file used at runtime.

> ### Setup (public) jitsi in the same machine
>
> If you are going to setup a jitsi instance in the same machine, add the jitsi hostname to `.env`:
> ```
> JITSI_HOSTNAME=<jitsi-hostname>
> ```
> The jitsi hostname should be a DNS CNAME to the machine's IP. **Run `jitsi-add.sh` to add a jitsi server block to redirect http requests to a Jitsi virtual host, reply '**Y**es'**.

> **WARNING**: If you use the **dev.sh** script below, it requires you to build the web source manually, so you will need to: 
> ```
> cd arena-web-core
> npm update
> npm run build
> cd ..
> ```

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

To update the repositories added as submodules (**arena-web-core** and **arena-persist**), run:

```bash
./update-submodules.sh
```

After updating the submodules, to have the updates of built containers (persist, arts, python-rt) reflected live, you will need to restart the services and rebuild the containers as follows.

- For production:
```bash
[./prod.sh | ./staging.sh | ./dev.sh] up -d --force-recreate --build
```

* Use ```demo.sh```, ```prod.sh```, ```staging.sh``` or ```dev.sh``` depending on which configuration you want to use.
> You might need to execute the above commands with ```sudo``` if [your user does not have permissions to access the docker service](https://docs.docker.com/engine/install/linux-postinstall/).
> See [utility scripts](#utility-scripts) for the description of these commands.

## Files/Folders Description

* **arena-web-core:** Contents of the arena-web-core repository (submodule).
* **arena-persist:**  Contents of the arena-persist repository (submodule).
* **arena-account:** Contents of the arena-account repository (submodule).
* **cleanup.sh:** Removes files created by init.sh.
* **conf:** Configuration files for the services (e.g. certificates, mosquito, nginx, persistence). These files are generated by ```init.sh```, using the files in the **conf-templates** folder.
* **conf-templates:** Templates of the configuration files for the services.Some important files described below:
  * *conf-templates/mosquitto.conf.tmpl*: used to generate **conf/mosquitto.conf**. Configures listeners on ports 8833 (mqtt), 9001 (mqtt-ws), 8083 (mqtt-wss) and 8883 (mqtt-tls); certificate files under ```/data/certbot/conf``` are mapped to ```/etc/letsencrypt``` in the container.
  * *conf-templates/arena-web.conf.tmpl*: used to generate **conf/arena-web.conf**. Configures the web server to serve a proxy to port 9001 under ```/mqtt/```, forwards requests to```/persist/``` to the **arena-persist** service and requests tp ```/storemng``` to the **store** service;  certificate files under ```/data/certbot/conf``` are mapped to ```/etc/letsencrypt``` in the container.
  * *conf-templates/persist-config.json.tmpl*: used to generate **conf/persist-config.json** and configures the mongodb uri to the container service name.
  * *conf-templates/account-settings.py.tmpl*: used to generate **conf/arena-account-settings.py**, the configuration of the auth service.
* **data:** Data files (e,g, certificates generated by certbot, mongodb database, ...).
* **docker-compose.localdev.yaml:** Compose file that describes services. This is the file used for development purposes
* **docker-compose.yaml:** Compose file that describes the base services, common to other configurations.
* **docker-compose.prod.yaml:** Compose file that describes production services. Relies on the base config in ```docker-compose.yaml``` to create the final production config.
* **docker-compose.staging.yaml:** Compose file that describes adds a dev folder on the web server. Relies on the base config in ```docker-compose.yaml``` to create the final staging config.
* **gen-root-token.sh:** Generate a root token for username given as arg (defaults to `cli`, if not given).
* **init-utils:** Files to create a container with all dependencies of the init scripts.
* **init-letsencrypt.sh:** Initialize certbot. Called by **init.sh**.
* **init.sh:** Initialize config files. See [Init Config](#init-config) Section.
* **jitsi-add.sh:** Add jitsi configuration, if you are setting up a jistsi server on the same machine.
* **update-submodules.sh:** Run this to get the latest updates from the repositories added as submodules (**arena-web-core**, **arena-persist**). You will need to restart the services to have the changes live (see [Update Submodules](#update-submodules)).
* **update-versions.sh:** Update the versions indicated in ```VERSION``` by looking at the tags in the submodules.
* **VERSION:** Release versions of the arena services stack used by the production deployment (```docker-compose.prod.yaml```).

## Utility Scripts

You can use the ```demo.sh```, ```prod.sh```, ```dev.sh``` and  ```staging.sh``` utility scripts (with a bash shell). These scripts call ```docker-compose``` with the right compose config files, where some files [extend each other](https://docs.docker.com/compose/extends/). The docker compose config files are used as follows:
* **demo.sh**: Demo compose config using a minimal set of pre-created docker images and config files (```docker-compose.yaml``` and ```docker-compose.demo.yaml```);
* **prod.sh**: Production compose config using pre-created docker images with fixed versions and additional monitoring services (```docker-compose.yaml``` and ```docker-compose.prod.yaml```);
* **staging.sh**: Staging compose config that builds images from submodules and adds folders for remote development (```docker-compose.yaml``` and ```docker-compose.staging.yaml```);
* **dev.sh**: Local development compose config that builds images from submodules (```docker-compose.localdev.yaml```).

Call the script by passing any ```docker-compose``` subcommands (such as ```up```, ```down```), e.g.:
* ```./prod.sh up -d```
* ```./prod.sh down```
* ```./dev.sh up```
* ...

> *You might need to execute the scripts with ```sudo``` if [your user does not have permissions to access the docker service](https://docs.docker.com/engine/install/linux-postinstall/)*.

### Script Arguments Quick Reference

The utility scripts pass the arguments to **docker-compose**. You can use them with all [**docker-compose** subcommands](https://docs.docker.com/compose/reference/). Here is a quick reference/examples of subcommands.

**Start services and see their output/logs**

- ```[./demo.sh | ./prod.sh | ./dev.sh | ./staging.sh] up``` (add ```--force-recreate --build``` to recreate abd build containers; useful after updating code in submodules)

**Start the services in "detached" (daemon) mode (-d)**

- ```[./demo.sh | ./prod.sh | ./dev.sh | ./staging.sh] up -d``` (add ```--force-recreate  --build``` to recreate abd build containers)

**Start just a particular service**

- ```[./demo.sh | ./prod.sh | ./dev.sh | ./staging.sh] up <service name in docker-compose*.yaml>```

**Stop services**

- ```[./demo.sh | ./prod.sh | ./dev.sh | ./staging.sh] down```

**Start a particular service**

- ```[./demo.sh | ./prod.sh | ./dev.sh | ./staging.sh] stop <service name in docker-compose*.yaml>```

**See logs**

- ```[./demo.sh | ./prod.sh | ./dev.sh | ./staging.sh] logs```

## Production release/deployment

### Release

To release an arena services stack version, make sure all submodules are pointing the version you want to release (you can run ```update-submodules.sh``` to update to the latest) update the versions in ```VERSION``` using the ```update-versions.sh``` script. This script asks for the new version of the arena services stack to be released and fetches the versions from the submodules. After running this script, you can use the github web interface to create that release. **Note that releases on this repo will be automatically deployed.**

### Deployment

For a production deployment, start the services stack using ```prod.sh```. This script starts the compose stack from ```docker-compose.prod.yaml```, which uses the versions described in the ```VERSION``` file (these are the release versions of the images started).

After starting the stack, you can see versions deployed at ```http://<arena-instance>/conf/versions.html```
