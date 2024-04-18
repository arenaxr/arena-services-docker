# ARENA Prod Setup

Creates several containers with ARENA services, from pre-build images at versions from VERSION:

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


```bash
git clone -b prod --single-branch https://github.com/arenaxr/arena-services-docker.git
```

2. Create Config

Before starting services, we need to create the configuration files for the services with the right domains and create certificates (using letsencrypt/openssl).

The 'init.env' file has the following configuration that should be updated to reflect your setup:

* ```HOSTNAME``` is your host's fully qualified domain name (FQDN). If you don't have a FQDN, you can do a local setup;

* ```JITSI_HOSTNAME``` is the fully qualified domain name (FQDN) of the jitsi server you will use (you can use a public/managed jitsi instance or [setup your own](https://jitsi.github.io/handbook/docs/devops-guide/)).

* ```EMAIL``` is the email to get the certificates with [letsencrypt](https://letsencrypt.org/).

* ```BACKUP_USER``` is the ```userid:groupid``` of the *host machine user* that needs to access files backed up by the backup container.

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
- Insert the [Google Auth Web Client ID/Secret for your setup](https://developers.google.com/identity/protocols/oauth2/web-server) and the [Google Auth Limited-Input Client ID/Secret for your setup](https://developers.google.com/identity/protocols/oauth2/limited-input-device). 

Now, run the init script:

```bash
 ./init.sh -y
```

3. Startup the services:

```bash
 ./prod.sh up
```
> You might need to execute using ```sudo``` (e.g. ```sudo ./demo.sh up```) if your user does not have permission to access the docker service.

If you see no errors, you should be able to point your browser to `https://localhost`. You will have get past the security warnings due to a self-signed certificate, **and use anonymous login** (using OAuth requires additional setup; see the main/master branch).
