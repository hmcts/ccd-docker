# CCD Docker :whale:

- [Prerequisites](#prerequisites)
- [Quick start](#quick-start)
- [Using CCD](#using-ccd)
- [Idam Stub](#idam-stub)
- [Running branches](#running-branches)
- [Enabling additional projects](#enabling-additional-projects)
- [Under the hood](#under-the-hood-speedboat)
- [Containers](#containers)
- [Local development](#local-development)
- [Troubleshooting](#troubleshooting)
- [Migrate existing v9.6 PostgreSQL database to v11](/PostgresV11.md)
- [Variables](#variables)
- [Remarks](#remarks)
- [License](#license)

## Prerequisites

- [JDK 11](https://openjdk.java.net/projects/jdk/11/)
- [Docker](https://www.docker.com)

**Note:** *once docker is installed, increase the memory and CPU allocations (Docker -> Preferences -> Advanced) to the following minimum values for successful execution of ccd applications altogether:*

| Memory   | CPU   |
| :------: | :---: |
| 12+ GB   | 6+    |

- [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest) - minimum version 2.0.57
- [jq Json Processor](https://stedolan.github.io/jq)
- Mac users, set your default shell to bash `chsh -s /bin/bash`

*The following documentation assumes that the current directory is `ccd-docker`.*

## Quick start

1. Checkout `ccd-docker` and `ccd-definition-store-api` projects:

```bash
git clone git@github.com:hmcts/ccd-docker.git
```

2. Login to the Azure Container registry:

```bash
./ccd login
```
Note:
if you experience any error with the above command, try `az login` first for [Azure Authentication for pulling latest docker images](#azure-authentication-for-pulling-latest-docker-images)



3. Add Postgres V11 DB settings - **THIS STEP IS ONLY REQUIRED IF YOU NEED TO MIGRATE TO POSTGRES V11**
- [Postgres v11 database set-up](/PostgresV11-prerequisites.md)



4. Pull latest Docker images:

```bash
./ccd compose pull
```


5. Set up environment: 

Note:
required only on the first run. Once executed, it doesn't need to be executed again

  a. Create docker network
  ```bash
  ./ccd init
  ```
  
  b. Export environment variables

  CDM apps require a set of environment variables which can be set up by executing the following script.
  
  Windows : `./bin/set-environment-variables.sh`
  
  Linux/Mac : `source ./bin/set-environment-variables.sh`
  
  Note: some users of zsh 'Oh My Zsh' experienced issues. Try switching to bash
  
  To persist the environment variables in Linux/Mac, copy the contents of `env_variables_all.txt` file into ~/.bash_profile.
  A prefix 'export' will be required for each environment variable.

  Additionally, export these environment variables to disable ElasticSearch

  ```bash
  export ELASTIC_SEARCH_ENABLED=false
  export ES_ENABLED_DOCKER=false
  ```

6. Creating and starting the containers:

```bash
./ccd compose up -d
```

**NOTE**

The `idam-api` container can be slow to start - both the `definition-store-api` and `data-store-api` containers will
try to connect to the `idam-api` container when they start.

If `idam-api` is not up and running and accepting connections
you may see errors in the `definition-store-api` and `data-store-api` containers, such as

```bash
Caused by: org.springframework.web.client.ResourceAccessException:
    I/O error on GET request for "http://idam-api:5000/o/.well-known/openid-configuration": Connection refused (Connection refused);
        nested exception is java.net.ConnectException: Connection refused (Connection refused)
```

If you the containers fail to start with these error, ensure `idam-api` is running using

 ```bash
curl http://localhost:5000/health
 ```

ensuring the response is

```bash
{"status":"UP"}
```

Then restart the `definition-store-api` & `data-store-api` containers

```bash
./ccd compose restart ccd-definition-store-api ccd-data-store-api
```
---


Usage and commands available:

```bash
./ccd
```


## Using CCD

Once the containers are running, CCD's frontend can be accessed at [http://localhost:3451](http://localhost:3451).

However, some more steps are required to correctly configure SIDAM and CCD before it can be used:

---
**NOTE**

All scripts require the following environment variables to be set

```bash
export IDAM_ADMIN_USER=<value of Username>
export IDAM_ADMIN_PASSWORD=<value of Password>
```

with the corresponding values from the confluence page at https://tools.hmcts.net/confluence/x/eQP3P

### CCD Quick Start

At this point most users can run the following 4 scripts

```bash
./bin/add-idam-clients.sh
./bin/add-idam-roles.sh
./bin/add-users.sh
./bin/add-ccd-roles.sh
./bin/add-role-assignments.sh
```


Create CCD users and roles

a. Clone `ccd-definition-store-api` if not already checked out `git clone git@github.com:hmcts/ccd-definition-store-api.git`
and navigate to the `ccd-definition-store-api`. 

b. Run smoke tests to set up user and roles.

```bash
export TEST_URL=http://localhost:3451

./gradlew clean smoke
```

The smoke tests creates a file `/aat/befta_recent_executions_info.json`, delete this file after running the tests.

---

Move on to the [Ready for take-off](###Ready-for-take-off) section.

---
A more in depth explanation of the scripts is detailed below

### 1. Configure Oauth2 Client of CCD Gateway on SIDAM

An oauth2 client should be configured for ccd-gateway application, on SIDAM Web Admin.

A script is provided that sets up the CCD Gateway client.  Execute the following:

```bash
./bin/add-idam-clients.sh
```

You may verify the service has been added by logging in to the SIDAM Web Admin with the URL and
logic credentials here:

https://tools.hmcts.net/confluence/x/eQP3P

Navigate to

`Home > Manage Services`

Optionally - to add any further IDAM service clients you can update the

```bash
./bin/add-idam-clients.sh
```

to add a new entry and re-run the script (any entries in this file that already exist are skipped)

`${dir}/utils/idam-create-service.sh LABEL CLIENT_ID CLIENT_SECRET REDIRECT_URL SELF_REGISTRATION SCOPE`

---
**NOTE**

* SELF_REGISTRATION - a boolean parameter, defaults to a value of "false" if omitted
* SCOPE - a space delimited string parameter, defaults to a value of "openid profile roles" if omitted
---

#### Manual Configuration steps

Instead of running the above scripts you can add the services manually using the SIDAM Web UI

You need to login to the SIDAM Web Admin with the URL and logic credentials here: https://tools.hmcts.net/confluence/x/eQP3P

Navigate to

```bash
Home > Manage Services > Add a new Service
```

On the **Add Service** screen the following fields are required:

```
label : <any>
description : <any>
client_id : ccd_gateway
client_secret : ccd_gateway_secret
new redirect_uri (click 'Add URI' before saving) : http://localhost:3451/oauth2redirect
```

Follow below steps to configure XUI Webapp on SIDAM Web Admin

On the **Add Service** screen the following fields are required:

```
label : <xui_webapp>
description : <xui_webapp>
client_id : xui_webapp
client_secret : xui_webapp_secrect
new redirect_uri (click 'Add URI' before saving) : http://localhost:3455/oauth2/callback
client scope: profile openid roles manage-user create-user
```


### 2. Create Idam roles

Execute the following script to add roles to SIDAM:

```bash
./bin/add-idam-roles.sh
```

The script parses `bin/users.json` and loops through a list of unique roles, passing the role to the `idam-add-role.sh`
script

To add any further IDAM roles, for example "myNewIdamRole", run the script as follows

```bash
    ./bin/utils/idam-add-role.sh "myNewIdamRole"
```

---
**NOTE**

The script adds roles under a _GLOBAL_ namespace and so until the users assigned to these roles are added,
you cannot verify them using SIDAM Web UI

---

#### Manual Configuration steps

Any roles should be configured for ccd-gateway client/service, on SIDAM Web Admin.

You need to login to the SIDAM Web Admin with the URL and logic credentials here: https://tools.hmcts.net/confluence/x/eQP3P

`Navigate to Home > Manage Roles > Select Your Service > Role Label`

Don't worry about the *Assignable roles* section when adding roles

Once the roles are defined under the client/service, go to the service configuration for the service you created in
Step 1 (`Home > Manage Services > select your service`) and select `ccd-import` role radio option under
**Private Beta Role** section

**Any business-related roles like `caseworker`,`caseworker-<jurisdiction>` etc to be used in CCD later must also be defined under the client configuration at this stage.**

#### Adding a role to CCD

Execute the following script to add roles to CCD:

```bash
./bin/add-ccd-roles.sh
```

The script parses `bin/ccd-roles.json` and loops through a list of roles and their security classifications, passing the values to the `ccd-add-role.sh` script.

By default most FTA (Feature test automation) packs load their own roles into CCD via the definition store each time
the feature tests are run

To add a further role to CCD (by importing it into the definition store), run the following script

```bash
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
./bin/ccd-add-role.sh caseworker PUBLIC
```

### 3. Create users

A script is provided that sets up some initial users and roles for running functional tests. Execute the following:

```bash
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

### 4. Create role assignments

A script is provided that sets up some initial role assignments for users. Execute the following:

```bash
./bin/add-role-assignments.sh
```

This script will add role assignments for the associated users as defined in

```bash
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

### 5. Import case definition

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

## Idam Stub
It's possible to disable the Idam containers and run CCD with an Idam Stub provided by ccd-test-stubs-service. This is useful as a back up plan for when docker Idam is broken or when you local machine is running low on memory and you don't want to spin up the whole Idam containers

### Enable Idam Stub

#### Step 1 - Disable Sidam containers

make sure 'sidam', 'sidam-local', 'sidam-local-ccd' docker compose files are not enabled. How you do that depends on your currently active compose files.
When no active compose files are present, the default ones are executed. But if there's any active, then the defautl ones are ignored. For example:

```bash
./ccd enable show

Currently active compose files:
backend
frontend
sidam
sidam-local
sidam-local-ccd

Default compose files:
backend
frontend
sidam
sidam-local
sidam-local-ccd
```

In this case sidam is currently explicitly enabled. To disable it:

```bash
./ccd disable sidam sidam-local sidam-local-ccd
```

If you are instead running with the default compose file as in:
```bash
./ccd enable show

Default compose files:
backend
frontend
sidam
sidam-local
sidam-local-ccd
```

You must explicitly enable only CCD compose files but exclude sidam:

```bash
./ccd enable backend frontend
./ccd enable show

Currently active compose files:
backend
frontend

Default compose files:
backend
frontend
sidam
sidam-local
sidam-local-ccd
```

#### Step 2 - Setup Env Vars

in the '.env' file, uncomment:

```yaml
#IDAM_STUB_SERVICE_NAME=http://ccd-test-stubs-service:5555
#IDAM_STUB_LOCALHOST=http://localhost:5555
```

To allow definition imports to work ('ccd-import-definition.sh') you need to:

```bash
export IDAM_STUB_LOCALHOST=http://localhost:5555
```

:warning: Please note: remember to unset 'IDAM_STUB_LOCALHOST' when switching back to the real Idam, otherwise definition import won't work

```bash
unset IDAM_STUB_LOCALHOST
```

#### Step 3 - (Optional) Customise IDAM roles

IDAM Stub comes with a predefined IDAM user.\
To permanently customise the stub user info such as its roles follow the instructions in 'backend.yml' -> ccd-test-stubs-service\
To modify the user info at runtime, see https://github.com/hmcts/ccd-test-stubs-service#idam-stub

#### Step 4 - Enable stub service dependency

Enable ccd-test-stubs-service dependency on ccd-data-store-api and ccd-definition-store-api in 'backend.yml' file.

Uncomment the below lines in 'backend.yml' file
```yaml
      #      ccd-test-stubs-service:
      #        condition: service_started
```

Comment the below lines in 'backend.yml' file
```yaml
      idam-api:
        condition: service_started
```

### Revert to Idam

#### Step 1 - Enable Sidam containers

```bash
./ccd enable sidam sidam-local sidam-local-ccd
```

or just revert to the default:

```bash
./ccd enable default
```

#### Step 2 - Setup Env Vars

in the '.env' file, make sure the following env vars are commented:

```yaml
#IDAM_STUB_SERVICE_NAME=http://ccd-test-stubs-service:5555
#IDAM_STUB_LOCALHOST=http://localhost:5555
```

then from the command line:

```bash
unset IDAM_STUB_LOCALHOST
```

#### Step 3 - Disable stub service dependency

Disable ccd-test-stubs-service dependency on ccd-data-store-api and ccd-definition-store-api in 'backend.yml' file.

Comment the below lines in 'backend.yml' file
```yaml
    #   ccd-test-stubs-service:
    #       condition: service_started
```

Uncomment the below lines in 'backend.yml' file
```yaml
      idam-api:
        condition: service_started
```

### Switching between Idam and Idam Stub Example

```bash
#assuming no containers running and Idam is enabled

#start with Idam
./ccd compose up -d

#services started

./ccd compose stop

#enable Idam Stub follwing the steps in 'Enable Idam Stub'

#start with Idam Stub
./ccd compose up -d

#services started

you also can issue a 'down' when Idam Stub is enabled without risking of losing Idam data, since it's disabled
./ccd compose down

enable Idam follwing the steps in 'Revert to Idam'

#start with Idam. This will now create new CCD containers and reuse the old Idam ones
./ccd compose up -d
```

NOTE: :warning: always use 'compose up' rather than 'compose start' when switching between Idam and Idam Stub to have docker compose pick up env vars changes.

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
> ccd-case-management-web branch:RDM-2414 hash:ced648d

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
* Front-end:
  * **idam-web-public**: SIDAM's login UI
  * **ccd-api-gateway**: Proxy with SIDAM and S2S integration
  * **ccd-case-management-web**: Caseworker UI

Optional compose files will allow other projects to be enabled on demand using the `enable` and `disable` commands.

* To enable **document-management-store-app**
  * `./ccd enable backend frontend dm-store`
  * run docker-compose `./ccd compose up -d`
  * create Blob Store in Azurite `./bin/document-management-store-create-blob-store-container.sh`

* To enable **ExUI** rather then the CCD UI
  * `./ccd enable xui-frontend`
  * run docker-compose `./ccd compose up -d`
  * (optional) stop the CCD UI docker container `ccd-case-management-web`
  * access ExUI at `http://localhost:3455`

* To enable **ElasticSearch**
  * NOTE: we recommend at lest 16GB of memory for Docker when enabling elasticsearch
  * `./ccd enable elasticsearch` (assuming `backend` is already enabled, otherwise enable it)
  * export ES_ENABLED_DOCKER=true
  * verify that Data Store is able to connect to elasticsearch: `curl localhost:4452/health`

* To enable **Logstash**
* `./ccd enable logstash` (assuming `elasticsearch` is already enabled, otherwise enable it)

* To run **service specific logstash instance**
  * First build the local log stash instances for all services using instructions on ccd-logstash [ccd-logstash](https://github.com/hmcts/ccd-logstash)
  * Export CCD_LOGSTASH_SERVICES environment variable to use service specific logstash instances
  * If CCD_LOGSTASH_SERVICES is not exported, then `ccd-logstash:latest` will be used
  * Make sure to set the below two environment variables in `.env` file
  * By default CCD_LOGSTASH_REPOSITORY_URL is point to remote repository `hmctspublic.azurecr.io`, this is defined in `.env` file.

```bash
    CCD_LOGSTASH_REPOSITORY_URL=hmctspublic.azurecr.io
```

   * For local docker repository please change the values as below

```bash
    CCD_LOGSTASH_REPOSITORY_URL=hmcts
```
   * To run service specific instances of logstash, give service names a comma serparated string as below

```bash
    export CCD_LOGSTASH_SERVICES=divorce,sscs,ethos,cmc,probate
```

   * To run all service instances of logstash

```bash
    CCD_LOGSTASH_SERVICES=all
```
OR

```bash
    CCD_LOGSTASH_SERVICES=testall
```

* To enable **ccd-definition-designer-api**
  * `./ccd enable backend ccd-definition-designer-api`
  * run docker-compose `./ccd compose up -d`
  * verify that ccd-definition-designer-api is up and running by `curl localhost:4544/health`

* To enable **ccd-message-publisher**
  * NOTE: By default the CCD Message Publisher will use an embedded ActiveMQ instance. See [ccd-message-publisher](https://github.com/hmcts/ccd-message-publisher) for more information.
  * `./ccd enable backend message-publisher`
  * Run docker-compose `./ccd compose up -d`
  * Verify that ccd-message-publisher is up and running by `curl localhost:4456/health`
 
* To enable **ccd-case-document-am-api**
  * `./ccd enable backend frontend dm-store case-document-am`
  * run docker-compose `./ccd compose up -d`
  * verify that ccd-case-document-am-api is up and running by `curl localhost:4455/health`
    
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

## Containers

### Back-end

#### ccd-definition-store-api

Store holding the case type definitions, which are a case's states, events and schema as well as its display configuration for rendering in CCD's UI.

#### ccd-data-store-api

Store where the versioned instances of cases are recorded.

#### ccd-user-profile-api

Display preferences for the CCD users.

#### ccd-test-stubs-service

Service to facilitate testing of external http calls using wiremock. It returns canned responses for requests matching
the predefined criteria.
Currently used for:
   - exposing a set of default callbacks that can be invoked for testing purposes
   - Idam Stub

### Front-end

#### ccd-api-gateway

API gateway securing interactions between `ccd-case-management-web` and the back-end services.

#### ccd-case-management-web

Caseworker frontend, exposed on port `3451`.

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

### Azure Authentication for pulling latest docker images

```bash
ERROR: Get <docker_image_url>: unauthorized: authentication required
```

If you see this above authentication issue while pulling images, please follow below commands,

Install Azure-CLI locally,

```bash
brew update && brew install azure-cli
```

and to update a Azure-CLI locally,

```bash
brew update azure-cli
```

then,
login to MS Azure,

```bash
az login
```
and finally, Login to the Azure Container registry:

```bash
./ccd login
```

On windows platform, we are installing the [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest) using executable .msi file.
If "az login" command throws an error like "Access Denied", please follow these steps.
We will need to install the az cli using Python PIP.
1. If Microsoft Azure CLI is already installed, uninstall it from control panel.
2. Setup the Python(version 2.x/3.x) on windows machine. PIP is bundled with Python.
3. Execute the command "pip install azure-cli" using command line. It takes about 20 minutes to install the azure cli.
4. Verify the installation using the command az --version.

## Troubleshooting

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
    > ./bin/document-management-store-create-blob-store-container.sh

## Variables
Here are the important variables exposed in the compose files:

| Variable | Description |
| -------- | ----------- |
| IDAM_KEY_CCD_DATA_STORE | IDAM service-to-service secret key for `ccd_data` micro-service (CCD Data store), as registered in `service-auth-provider-api` |
| IDAM_KEY_CCD_GATEWAY | IDAM service-to-service secret key for `ccd_gw` micro-service (CCD API Gateway), as registered in `service-auth-provider-api` |
| IDAM_KEY_CCD_DEFINITION_STORE | IDAM service-to-service secret key for `ccd_definition` micro-service (CCD Definition store), as registered in `service-auth-provider-api` |
| IDAM_KEY_CCD_ADMIN | IDAM service-to-service secret key for `ccd_admin` micro-service (CCD Admin Web), as registered in `service-auth-provider-api` |
| DATA_STORE_S2S_AUTHORISED_SERVICES | List of micro-service names authorised to call this service, comma-separated, as registered in `service-auth-provider-api` |
| DEFINITION_STORE_S2S_AUTHORISED_SERVICES | List of micro-services authorised to call this service, comma-separated, as registered in `service-auth-provider-api` |
| USER_PROFILE_S2S_AUTHORISED_SERVICES | List of micro-services authorised to call this service, comma-separated, as registered in `service-auth-provider-api` |
| DATA_STORE_TOKEN_SECRET | Secret for generation of internal event tokens |
| APPINSIGHTS_INSTRUMENTATIONKEY | Secret for Microsoft Insights logging, can be a dummy string in local |
| STORAGEACCOUNT_PRIMARY_CONNECTION_STRING | (If dm-store is enabled) Secret for Azure Blob Storage. It is pointing to dockerized Azure Blob Storage emulator. |
| STORAGE_CONTAINER_DOCUMENT_CONTAINER_NAME | (If dm-store is enabled) Container name for Azure Blob Storage |
| AM_DB | Access Management database name |
| AM_DB_USERNAME | Access Management database username |
| AM_DB_PASSWORD | Access Management database password |
| WIREMOCK_SERVER_MAPPINGS_PATH | Path to the WireMock mapping files. If not set, it will use the default mappings from the project repository. __Note__: If setting the variable, please keep all WireMock json stub files in a directory named _mappings_ and exclude this directory in the path. For e.g. if you place the _mappings_ in /home/user/mappings then export WIREMOCK_SERVER_MAPPINGS_PATH=/home/user. Stop the service and start service using command `./ccd compose up -d ccd-test-stub-service`. If switching back to repository mappings please unset the variable using command `unset WIREMOCK_SERVER_MAPPINGS_PATH` |
| IDAM_KEY_CASE_DOCUMENT | IDAM service-to-service secret key for `ccd_case_document_am_api` micro-service (CCD Case Document Am Api), as registered in `service-auth-provider-api` |

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

## LICENSE

This project is licensed under the MIT License - see the [LICENSE](LICENSE.md) file for details.
