# Config Templates

This folder has templates for the config files used (nginx, mosquitto, account, persist, web client, ...).
These templates have variables replaced from values in env variables using `envsubst`.

When init.sh is executed, this folder's structure will be copied into conf/ and files will be created from templates using `envsubst`.

## Structure

The root of this folder has the config files that are common to all compose configurations (prod, devlocal, staging, ...). A folder for each compose configuration has the files that are specific to it. 

When init.sh is executed, configuration files in conf/arena-web-conf will be copied to each of the compose configuration folders (e.g. conf/prod/arena-web-conf/, conf/devlocal/arena-web-conf/, ...)

```
.
├── arena-web-conf 						# arena web client config, common to all compose configurations
│             ├── ...
│             └── gauth.json
├── demo								# demo compose configuration config files
│             ├── arena-web-conf 		# arena web client config for demo; init.sh copies files from ../../arena-web-conf
│             │             ├── defaults.js
│             │             ├── defaults.json
│             │             └── ...
│             └── arena-web.conf
│
├── localdev							# devlocal compose configuration config files
│             ├── arena-web-conf        # arena web client config for localdev; init.sh copies files from ../../arena-web-conf
│             │             ├── defaults.js
│             │             └── defaults.json
│             │             └── ...
│             └── arena-web.conf
├── prod								# prod compose configuration config files
│             ├── arena-web-conf		# arena web client config for prod; init.sh copies files from ../../arena-web-conf
│             │             ├── defaults.js
│             │             └── defaults.json
│             │             └── ...
│             └── ...
├── ...
│
│   # these are config files common to all setups
├── mosquitto.conf
└── ...
```
