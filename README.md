# CCD Docker :whale:

- [Prerequisites](#prerequisites)
- [Quick start](#quick-start)
- [Configuring CCD](#configuring-ccd)
- [Running branches](#running-branches)
- [Enabling additional projects](#enabling-additional-projects)
- [Under the hood](#under-the-hood-speedboat)
- [Local development](#local-development)
- [Troubleshooting](#troubleshooting)
- [Variables](#variables)
- [Remarks](#remarks)

## Additional Documentation
- [Azure Setup Guide](/docs/Azure.md)
- [Containers explained](/docs/Containers.md)
- [Idam Alternatives](/docs/IdamAlt.md)
- [Running on Apple Silicon (ARM64)](/docs/AppleSilicon.md)
- [Migrate PostgreSQL database to latest](/docs/PostgresUpgrade.md)
- [License](/LICENSE.md)

## Prerequisites

- [JDK 17](https://openjdk.java.net/projects/jdk/17/)
- [Docker](https://www.docker.com)

**Note:** *once docker is installed, increase the memory and CPU allocations (Docker -> Preferences -> Advanced) to the following minimum values for successful execution of ccd applications altogether:*

| Memory   | CPU   |
| :------: | :---: |
| 7+ GB   | 6+    |

- [Azure CLI](/docs/Azure.md) - minimum version 2.0.57
- [jq Json Processor](https://ghcr.io/jqlang/jq)
- Mac users, set your default shell to bash `chsh -s /bin/bash`

*The following documentation assumes that the current directory is `ccd-docker`.*

## Quick start

### 1. Checkout `ccd-docker` and `ccd-definition-store-api` projects:

```bash
git clone git@github.com:hmcts/ccd-docker.git
```

### 2. For Extra Quick setup on Mac/Linux
<div style="color:#fef;padding:12px;background-color:#2d2d2d">
<span style="color:#fef;padding:4px;background-color:#070"> Use <code>./ccd default</code> 
  to setup using default services/configuration and simulated idam
</span>


- After command is run you should be good to go and can skip the rest
- Currently windows not supported for default command
- For custom setup please skip this step and continue setup
</div> 

### 3. Authenticate Azure and login to the Azure Container registry:
Make sure azure cli is installed, if not got to [Azure Setup Guide](/docs/Azure.md)

```bash
az login
./ccd login
```
### 4. Migrate existing Postgres DB
⚠️ <span style="color:#112;padding:2px;background-color:#fa0"> THIS STEP IS ONLY REQUIRED IF YOU NEED TO MIGRATE POSTGRES VERSION
</span>⚠️

<div style="color:#112;padding:12px;background-color:#998e5d">
If ccd-docker has been previously setup, images/volumes and the database may point to an earlier Postgres version. Prior to pulling images run the below commands to **delete** existing images and volumes.
<code>
./ccd compose down
</code>
</div>

See [Guide on migrating postgres](/docs/PostgresUpgrade.md) for more details

### 5. Pull latest Docker images
   
```bash
./ccd compose pull
```

### 6. Set up network and configuration 

Note:
required only on the first run. Once executed, it doesn't need to be executed again

#### A. Create docker network
  
```bash
  ./ccd init
  ```
  Ignore if we get error message ccd-network already exists while running above command
  
#### B. Export environment variables

  CDM apps require a set of environment variables which can be set up by executing the following script.
  
  Windows : 
  ```bash
  ./bin/set-environment-variables.sh
  ```
  
  Linux/Mac : 
  ```bash
  source ./bin/set-environment-variables.sh
  ```
  
  Note: some users of zsh 'Oh My Zsh' experienced issues. Try switching to bash by : `chsh -s /bin/bash`
  
  To persist the environment variables in Linux/Mac run the following script
  ``` bash
  ./bin/add-to-bash-profile.sh
  ``` 
  to add the above command into your ~/.bash_profile.

  Additionally, export these environment variables to enable ElasticSearch

  ```bash
  export ELASTIC_SEARCH_ENABLED=true
  export ES_ENABLED_DOCKER=true
  ```

6. Creating and starting the containers:

```bash
./ccd compose up -d
```

**NOTE**

The `idam-api` container can be slow to start - both the `definition-store-api` and `data-store-api` containers will
try to connect to the `idam-api` container when they start.

The following optional containers will not start successfully until `idam-api` container has started.
* `ts-translation-service`
* `case-disposer`
* `case-document-am`
* `frontend`
* `xui-frontend`
* 'hearings'

If `idam-api` is not up and running and accepting connections
you may see errors in the `definition-store-api` and `data-store-api` containers, such as

```bash
Caused by: org.springframework.web.client.ResourceAccessException:
    I/O error on GET request for "http://idam:5000/o/.well-known/openid-configuration": Connection refused (Connection refused);
        nested exception is java.net.ConnectException: Connection refused (Connection refused)
```

If the containers fail to start with these error, ensure `idam-api` is running using

 ```bash
curl http://localhost:5000/health
 ```

ensuring the response is

```bash
{"status":"UP"}
```

Then restart any dependent containers by bringing up again (compose will automatically bring up just the ones which ones have failed)

```bash
./ccd compose up -d
```
---


Usage and commands available:

```bash
./ccd
```


## Configuring CCD

Once the containers are running, CCD's frontend can be accessed at [http://localhost:3451](http://localhost:3451).

However, some more steps are required to correctly configure CCD before it can be used:

---
**NOTE**

All scripts require the following environment variables to be set
- IDAM_ADMIN_USER
- IDAM_ADMIN_PASSWORD

If they are not working then check you have run `source ./bin/set-environment-variables.sh` correctly.
If still not working then try setting them directly with the following commands.
```bash
export IDAM_ADMIN_USER=idamOwner@hmcts.net
export IDAM_ADMIN_PASSWORD=Ref0rmIsFun
```
And check they match the corresponding values from the confluence page at https://tools.hmcts.net/confluence/x/eQP3P

### CCD Quick Start

At this point most users can run the following 3 scripts

```bash
./bin/add-users.sh && 
./bin/add-ccd-roles.sh && 
./bin/add-role-assignments.sh
```


Create CCD users and roles

a. Clone `ccd-definition-store-api` if not already checked out `git clone git@github.com:hmcts/ccd-definition-store-api.git`
and navigate to the `ccd-definition-store-api`. 

b. Run smoke tests to set up user and roles.

```bash
export TEST_URL=http://localhost:4451

./gradlew clean smoke

```

[
Note: incase of any errors relating to Service Auth when running the smoke test, ensure the following environment variable is set as below:

export IDAM_S2S_URL=http://service-auth-provider-api:8080

Alternatively remove this from the environment by issuing 'unset IDAM_S2S_URL', backend.yaml will default to use 'http://service-auth-provider-api:8080'

./ccd compose up -d

Will need to be re-issued to apply the above changes.
]


The smoke tests creates a file `/aat/befta_recent_executions_info.json`, delete this file after running the tests.

---

Move on to the [Ready for take-off](###Ready-for-take-off) section.

---
A more in depth explanation of the scripts is detailed below


### 1. Add users

A script is provided that sets up some initial users and roles for running functional tests. Execute the following:

```bash
# FOR IDAM FULL STACK
./bin/add-users.sh
```

This script will add the users with associated roles as defined in

```bash
bin/users.json
```

This script runs the checks below, for each user defined in the `users.json`

```bash
check roles
if roles are the same
    do nothing
else
    delete user
    create user with same id
```

Therefore to
 * add a new user - add a new entry to the `users.json`
 * modify an existing user - modify `users.json` to add/remove a role

Alternatively, add a user to SIDAM by using the script

```bash
# FOR IDAM-SIM
./bin/utils/idam-simulator-create-user.sh ROLE EMAIL_ADDRESS LAST_NAME FIRST_NAME
# FOR IDAM FULL STACK
./bin/idam-create-caseworker.sh ROLE EMAIL_ADDRESS LAST_NAME FIRST_NAME
```
---
**NOTE**
LAST_NAME if omitted defaults to `TesterLastName`
FIRST_NAME if omitted defaults to `TesterFirstname`

Password for each user created by the script defaults to `Pa55word11`

---
You may verify the service has been added by logging in to the SIDAM Web Admin with the URL and
logic credentials here:

https://tools.hmcts.net/confluence/x/eQP3P

Navigate to

`Home > Manage Users`

and search for users by email address.

### 2. Add CCD roles

Execute the following script to add roles to CCD:

```bash
# FOR IDAM FULL STACK
./bin/add-ccd-roles.sh
```

The script parses `bin/ccd-roles.json` and loops through a list of roles and their security classifications, passing the values to the `ccd-add-role.sh` script.

By default most FTA (Feature test automation) packs load their own roles into CCD via the definition store each time
the feature tests are run

To add a further role to CCD (by importing it into the definition store), run the following script

```bash
# FOR IDAM FULL STACK
./bin/ccd-add-role.sh
```

supplying the following parameters

```bash
- role: Name of the role. Must be an existing IDAM role.
- classification: Classification granted to the role; one of `PUBLIC`,
        `PRIVATE` or `RESTRICTED`. Default to `PUBLIC`.
```

For example, to add the `caseworker` role (that must exist in SIDAM) to CCD, use

```bash
# FOR IDAM FULL STACK
./bin/ccd-add-role.sh caseworker PUBLIC
```

### 3. Add role assignments

A script is provided that sets up some initial role assignments for users. Execute the following:

```bash
# FOR IDAM FULL STACK
./bin/add-role-assignments.sh
```

This script will add role assignments for the associated users as defined in

```bash
# FOR IDAM FULL STACK
bin/am-role-assignments.json
```

This script runs the checks below, for each user defined in the `am-role-assignments.json`

```bash
if overrideAll flag is true
    delete any existing role assignments for the user
else 
    do nothing

then 
    create all user's assignments
```

Note that currently the role assignments are created in the role assignment database directly due to restrictions in the rules engine of the Role Assignment Service APIs.

The `am-role-assignments.json` can be modified to add further role assignments to users.

### 6. Import case definition

#### Note:

CCD Data Store FTA tests will automatically import the CCD case definitions using the `befta-fw` test framework.

Case definitions can be imported using CCD's dedicated UI

Case definitions can also be imported manually via the command line, using the following script

```bash
./bin/ccd-import-definition.sh <path_to_definition>
```

Parameters:
- `path_to_definition`: Path to `.xlsx` file containing the case definition.

**Note:** For CCD to work, the definition must contain the caseworker's email address.

If the import fails with an error of the form:

```
Validation errors occurred importing the spreadsheet.

- Invalid IdamRole 'caseworker-cmc-loa1' in AuthorisationCaseField tab, case type 'MoneyClaimCase', case field 'submitterId', crud 'CRUD'
```

Then the indicated role, here `caseworker-cmc-loa1`, must be added to CCD (See [2. Create Idam roles](2-.-Create-Idam-roles)).
### Ready for take-off 🛫

Back to [http://localhost:3451](http://localhost:3451), you can now log in with any of the email addresses defined when adding users in [3. Create Users](#3.-Create-users).
All user passwords default to : `Pa55word11`.

If you see only a grey screen after entering your user credentials in the login page, you may need to set profile settings in ccd_user_profile database by adding a single line for the user in the below tables:

1- user_profile

2- user_profile_jurisdiction

## Running branches

By default, all CCD containers are running with the `latest` tag, built from the `master` branch.

### Switch to a branch

Using the `set` command, branches can be changed per project. It's possible to switch to remote branches but also to local branches

To switch to a remote branch the command is:

```bash
./ccd set <project> <remote_branch>
```

* `<project>` the service name as declared in the compose file, e.g. ccd-data-store-api, ccd-test-stubs-service
* `<remote_branch>` must be an existing **remote** branch for the selected project.

To switch to a local branch the command is:

```bash
./ccd set <project> <local_branch> <file://local_repository_path>
```
* `<project>` the service name as declared in the compose file, e.g. ccd-data-store-api, ccd-test-stubs-service
* `<local_branch>` must be an existing **local** branch for the selected project.
* `<file://local_repository_path>` path to the root of the local project repository

__Note__: when working with local branches, to be able to run any new set of local changes those must first be committed and the `switch to a local branch` and `Apply` procedure repeated.

Branches for a project can be listed using:

```bash
./ccd branches <project>
```

### Apply

When switching to a branch, a Docker image is built locally and the Docker compose configuration is updated.

However, to make that configuration effective, the Docker containers must be updated using:

```bash
./ccd compose up -d
```

### Revert to `master`

When a project has been switched to a branch, it can be reverted to `master` in 2 ways:

```bash
./ccd set <project> master
```

or

```bash
./ccd unset <project> [<projects...>]
```

The only difference is that `unset` allows for multiple projects to be reset to `master`.

In both cases, like with the `set` command, for the reset to be effective it requires the containers to be updated:

```bash
./ccd compose up -d
```

### Current branches

To know which branches are currently used, the `status` command can be used:

```bash
./ccd status
```

The 2nd part of the output indicates the current branches.
The output can either be of the form:

> No overrides, all using master

when no branches are used; or:

> Current overrides:
> ccd-admin-web branch:RDM-2414 hash:ced648d

when branches are in use.

:information_source: *In addition to the `status` command, the current status is also displayed for every `compose` commands.*

## Enabling additional projects

By default, `ccd-docker` runs the most commonly used backend and frontend projects required by CCD:

* Back-end:
  * **sidam-api**: Strategic identity and access control
  * **service-auth-provider-api**: Service-to-service security layer
  * **ccd-user-profile-api**: Users/jurisdictions association and usage preferences
  * **ccd-definition-store-api**: CCD's dynamic case definition repository
  * **ccd-data-store-api**: CCD's cases repository
  * **ccd-test-stubs-service**: CCD's testing support for stubbing http calls (service callbacks etc)
  * **am-role-assignment-service**: Users' role assignments for access management
  * **cft-hearing-service**: Hearing Service API
* Front-end:
  * **idam-web-public**: SIDAM's login UI
  * **ccd-api-gateway**: Proxy with SIDAM and S2S integration

Optional compose files will allow other projects to be enabled on demand using the `enable` and `disable` commands.

**Note on Running Optional Projects** 

If this is the first time running these optional projects from ccd docker you will need to do `./ccd compose pull` after you have enable the optional project

Also if a certain database has not been created you might need to create a new ccd shared database image. To do this you need to do this:

* Run `/ccd compose down -v`
* Then find the id of any ccd shared database using `docker images | grep ccd-shared-database`
* Using the ids from previous command use  `docker image rm <id>`
* Then run `./ccd compose up -d`

**Optional Project Commands**

* To enable **document-management-store-app**
  * `./ccd enable backend frontend dm-store`
  * run docker-compose `./ccd compose up -d`
  * create Blob Store in Azurite `./bin/dm-store/document-management-store-create-blob-store-container.sh`

* To enable **ExUI** rather then the CCD UI
  * `./ccd enable xui-frontend`
  * export XUI_LAUNCH_DARKLY_CLIENT_ID to value mentioned in xui web app preview template yaml file. i.e. 645baeea2787d812993d9d70
  * run docker-compose `./ccd compose up -d`
  * access ExUI at `http://localhost:3455`

* To enable **ElasticSearch**
  * NOTE: we recommend at lest 16GB of memory for Docker when enabling elasticsearch
  * `./ccd enable elasticsearch` (assuming `backend` is already enabled, otherwise enable it)
  * export ES_ENABLED_DOCKER=true
  * verify that Data Store is able to connect to elasticsearch: `curl localhost:4452/health`

* To enable **Logstash**
  * `./ccd enable logstash` (assuming `elasticsearch` is already enabled, otherwise enable it)
  * Note that the config for Logstash is contained within the [logstash directory](logstash)

* To enable **ccd-message-publisher**
  * NOTE: By default the CCD Message Publisher will use an embedded ActiveMQ instance. See [ccd-message-publisher](https://github.com/hmcts/ccd-message-publisher) for more information.
  * `./ccd enable backend message-publisher`
  * Run docker-compose `./ccd compose up -d`
  * Verify that ccd-message-publisher is up and running by `curl localhost:4456/health`

* To enable **ccd-case-disposer**
  * `./ccd enable backend case-disposer`
  * Run docker-compose `./ccd compose up -d`

* To enable **ccd-next-hearing-date-updater**
  * `./ccd enable backend ccd-next-hearing-date-updater`
  * Run docker-compose `./ccd compose up -d`

* To enable **ccd-case-document-am-api**
  * `./ccd enable backend frontend dm-store case-document-am`
  * run docker-compose `./ccd compose up -d`
  * verify that ccd-case-document-am-api is up and running by `curl localhost:4455/health`

* To enable **ts-translation-service**
  * `./ccd enable backend ts-translation-service`
  * run docker-compose `./ccd compose up -d`
  * verify that ts-translation-service is up and running by `curl localhost:4650/health`

* To enable **cft-hearing-service**
  * `./ccd enable backend hearings`
  * run docker-compose `./ccd compose up -d`
  * verify that cft-hearing-service is up and running by `curl localhost:4651/health`
  * this will include the inbound and outbound adapters

* To enable **hmc-operational-reports-runner**
  * `./ccd enable backend operational`
  * run docker-compose `./ccd compose up -d`
  * verify that hmc-operational-reports-runner is up and running by `curl localhost:4651/health`

## Under the hood :speedboat:

### Set

#### Non-`master` branches

When switching to a branch with the `set` command, the following actions take place:

1. The given branch is cloned in the temporary `.workspace` folder
2. If required, the project is built
3. A docker image is built
4. The Docker image is tagged as `hmcts/<project>:<branch>-<git hash>`
5. An entry is added to file `.tags.env` exporting an environment variable `<PROJECT>_TAG` with a value `<branch>-<git hash>` matching the Docker image tag

The `.tags.env` file is sourced whenever the `ccd compose` command is used and allows to override the Docker images version used in the Docker compose files.

Hence, to make that change effective, the containers must be updated using `./ccd compose up`.

#### `master` branch

When switching a project to `master` branch, the branch override is removed using the `unset` command detailed below.

### Unset

Given a list of 1 or more projects, for each project:

1. If `.tags.env` contains an entry for the project, the entry is removed

Similarly to when branches are set, for a change to `.tags.env` to be applied, the containers must be updated using `./ccd compose up`.

### Status

Retrieve from `.tags.env` the branches and compose files currently enabled and display them.

### Compose

```bash
./ccd compose [<docker-compose command> [options]]
```

The compose command acts as a wrapper around `docker-compose` and accept all commands and options supported by it.

:information_source: *For the complete documentation of Docker Compose CLI, see [Compose command-line reference](https://docs.docker.com/compose/reference/).*

Here are some useful commands:

#### Up

```bash
./ccd compose up [-d]
```

This command:
1. Create missing containers
2. Recreate outdated containers (= apply configuration changes)
3. Start all enabled containers

The `-d` (detached) option start the containers in the background.

#### Down

```bash
./ccd compose down [-v] [project]
```

This stops and destroys all composed containers.

If provided, the `-v` option will also clean the volumes.

Destroyed containers cannot be restarted. New containers will need to be built using the `up` command.

#### Ps

```bash
./ccd compose ps [<project>]
```

Gives the current state of all or specified composed projects.

#### Logs

```bash
./ccd compose logs [-f] [<project>]
```

Displays the logs for all or specified composed projects.

The `-f` (follow) option allows to follow the tail of the logs.

#### Start/stop

```bash
./ccd compose start [<project>]
./ccd compose stop [<project>]
```

Start or stop all or specified composed containers. Stopped containers can be restarted with the `start` command.

:warning: Please note: Re-starting a project with stop/start does **not** apply configuration changes. Instead, the `up` command should be used to that end.

#### Pull

```bash
./ccd compose pull [project]
```

Fetch the latest version of an image from its source. For the new version to be used, the associated container must be re-created using the `up` command.

### Configuration

#### OAuth 2

OAuth 2 clients must be explicitly declared in service `sidam-api` with their ID and secret.

A client is defined as an environment variable complying to the pattern:

```yml
environment:
  IDAM_API_OAUTH2_CLIENT_CLIENT_SECRETS_<CLIENT_ID>: <CLIENT_SECRET>
```

The `CLIENT_SECRET` must then also be provided to the container used by the client service.

:information_source: *To prevent duplication, the client secret should be defined in the `.env` file and then used in the compose files using string interpolation `"${<VARIABLE_NAME>}"`.*

#### Service-to-Service

Micro-services names and secret keys must be registered as part of `service-auth-provider-api` configuration by adding environment variables like:

```yml
environment:
  MICROSERVICE_KEYS_<SERVICE_NAME>: <SERVICE_SECRET>
```

The `SERVICE_SECRET` must then also be provided to the container running the micro-service.

:information_source: *To prevent duplication, the client secret should be defined in the `.env` file and then used in the compose files using string interpolation `"${<VARIABLE_NAME>}"`.*

#### Address lookup

To use UK address lookup feature an API key for https://postcodeinfo.service.justice.gov.uk is required. When API key is available it needs to be set on host side under `ADDRESS_LOOKUP_TOKEN` variable name.

## Local development

The provided Docker compose files can be used to get up and running for local development.

However, while working, it is more convenient to run a project directly on the localhost rather than having to rebuild a docker image and a container.
This means mixing a locally-run project, the one being worked on, with projects running in Docker containers.

Given their unique configuration and dependencies, the way to achieve this varies slightly from one project to the other.

Here's the overall approach:

### 1. Update containers to point to local project

As is, the containers are configured to use one another.
Thus, the first step to replace a container by a locally running instance is to update all references to this container in the compose files.

For instances, to use a local data store, references in `ccd-api-gateway` service (file `compose/frontend.yml`) must be changed from:

```yml
PROXY_AGGREGATED: http://ccd-data-store-api:4452
PROXY_DATA: http://ccd-data-store-api:4452
```

to, for Mac OS:

```yml
PROXY_AGGREGATED: http://docker.for.mac.localhost:4452
PROXY_DATA: http://docker.for.mac.localhost:4452
```

or to, for Windows:

```yml
PROXY_AGGREGATED: http://docker.for.win.localhost:4452
PROXY_DATA: http://docker.for.win.localhost:4452
```

The `docker.for.mac.localhost` and `docker.for.win.localhost` hostnames point to the host computer (your localhost running Docker).

For other systems, the host IP address could be used.

Once the compose files have been updated, the new configuration can be applied by running:

```
./ccd compose up -d
```

### 2. Configure local project to use containers

The local project properties must be reviewed to use the containers and comply to their configuration.

Mainly, this means:
- **Database**: pointing to the locally exposed port for the associated DB. This port used to be 5000 but has been changed to 5050 after SIDAM integration, which came to use 5000 for sidam-api application.
- **SIDAM**: pointing to the locally exposed port for SIDAM
- **S2S**:
  - pointing to the locally exposed port for `service-auth-provider-api`
  - :warning: using the right key, as defined in `service-auth-provider-api` container
- **URLs**: all URLs should be updated to point to the corresponding locally exposed port


## Troubleshooting

```bash
ERROR: Get <docker_image_url>: unauthorized: authentication required
```
If you see this above authentication issue while pulling images, please follow the [Azure Setup Guide](/docs/Azure.md).

ccd-network could not be found error:

- if you get "CCD: ERROR: Network ccd-network declared as external, but could not be found. Please create the network manually using docker network create ccd-network"
    > ./ccd init

CCD UI not loading:

- it might take few minutes for all the services to startup
    > wait few minutes and then retry accessing CCD UI
- sometimes happens that some of the back-ends (data store, definition store, user profile) cannot startup because the database liquibase lock is stuck.
    > check on the back-end log if there's the following exception: 'liquibase.exception.LockException: Could not acquire change log lock'
    Execute the following command on the database:
    UPDATE DATABASECHANGELOGLOCK SET LOCKED=FALSE, LOCKGRANTED=null, LOCKEDBY=null where ID=1;
- it's possible that some of the services cannot start or crash because of lack of availabel memory. This especially when starting Idam and or ElasticSearch
    > give more memory to Docker. Configurable under Preferences -> Advanced

DM Store issues:

- "uk.gov.hmcts.dm.exception.AppConfigurationException: Cloub Blob Container does not exist"
    > ./bin/dm-store/document-management-store-create-blob-store-container.sh

## Variables
Here are the important variables exposed in the compose files:

| Variable | Description                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              |
| -------- |----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| IDAM_KEY_CCD_DATA_STORE | IDAM service-to-service secret key for `ccd_data` micro-service (CCD Data store), as registered in `service-auth-provider-api`                                                                                                                                                                                                                                                                                                                                                                                                                                                                           |
| IDAM_KEY_CCD_GATEWAY | IDAM service-to-service secret key for `ccd_gw` micro-service (CCD API Gateway), as registered in `service-auth-provider-api`                                                                                                                                                                                                                                                                                                                                                                                                                                                                            |
| IDAM_KEY_CCD_DEFINITION_STORE | IDAM service-to-service secret key for `ccd_definition` micro-service (CCD Definition store), as registered in `service-auth-provider-api`                                                                                                                                                                                                                                                                                                                                                                                                                                                               |
| IDAM_KEY_CCD_ADMIN | IDAM service-to-service secret key for `ccd_admin` micro-service (CCD Admin Web), as registered in `service-auth-provider-api`                                                                                                                                                                                                                                                                                                                                                                                                                                                                           |
| DATA_STORE_S2S_AUTHORISED_SERVICES | List of micro-service names authorised to call this service, comma-separated, as registered in `service-auth-provider-api`                                                                                                                                                                                                                                                                                                                                                                                                                                                                               |
| DEFINITION_STORE_S2S_AUTHORISED_SERVICES | List of micro-services authorised to call this service, comma-separated, as registered in `service-auth-provider-api`                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    |
| USER_PROFILE_S2S_AUTHORISED_SERVICES | List of micro-services authorised to call this service, comma-separated, as registered in `service-auth-provider-api`                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    |
| DATA_STORE_TOKEN_SECRET | Secret for generation of internal event tokens                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           |
| APPINSIGHTS_INSTRUMENTATIONKEY | Secret for Microsoft Insights logging, can be a dummy string in local                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    |
| STORAGEACCOUNT_PRIMARY_CONNECTION_STRING | (If dm-store is enabled) Secret for Azure Blob Storage. It is pointing to dockerized Azure Blob Storage emulator.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        |
| STORAGE_CONTAINER_DOCUMENT_CONTAINER_NAME | (If dm-store is enabled) Container name for Azure Blob Storage                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           |
| AM_DB | Access Management database name                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          |
| AM_DB_USERNAME | Access Management database username                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      |
| AM_DB_PASSWORD | Access Management database password                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      |
| WIREMOCK_SERVER_MAPPINGS_PATH | Path to the WireMock mapping files. If not set, it will use the default mappings from the project repository. __Note__: If setting the variable, please keep all WireMock json stub files in a directory named _mappings_ and exclude this directory in the path. For e.g. if you place the _mappings_ in /home/user/mappings then export WIREMOCK_SERVER_MAPPINGS_PATH=/home/user. Stop the service and start service using command `./ccd compose up -d ccd-test-stub-service`. If switching back to repository mappings please unset the variable using command `unset WIREMOCK_SERVER_MAPPINGS_PATH` |
| IDAM_KEY_CASE_DOCUMENT | IDAM service-to-service secret key for `ccd_case_document_am_api` micro-service (CCD Case Document Am Api), as registered in `service-auth-provider-api`                                                                                                                                                                                                                                                                                                                                                                                                                                                 |
| IDAM_KEY_TS_TRANSLATION_SERVICE | IDAM service-to-service secret key for `ts-translation-service` micro-service (Ts Translation Service), as registered in `service-auth-provider-api`                                                                                                                                                                                                                                                                                                                                                                                                                                                     |
## Remarks

- A container can be configured to call a localhost host resource with the localhost shortcut added for docker containers recently. However the shortcut must be set according the docker host operating system.

```bash
# for Mac
docker.for.mac.localhost
# for Windows
docker.for.win.localhost
```

Remember that once you changed the above for a particular app you have to make sure the container configuration for that app does not try to automatically start the dependency that you have started locally. To do that either comment out the entry for the locally running app from the **depends_on** section of the config or start the app with **--no-deps** flag.

- If you happen to run `docker-compose up` before setting up the environment variables, you will probably get error while starting the DB. In that
case, clear the containers but also watch out for volumes created to be cleared to get a fresh start since some initialisation scripts don't run if
you have already existing volume for the container.

```bash
$ docker volume list
DRIVER              VOLUME NAME

# better be empty
```
