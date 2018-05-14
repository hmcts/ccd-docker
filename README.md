# CCD Docker :whale:

- [Getting started](#getting-started)
  - [Prerequisites](#prerequisites)
  - [Starting CCD](#starting-ccd)
  - [Using CCD](#using-ccd)
  - [Monitoring](#monitoring-)
  - [Stopping and cleaning up](#stopping-and-cleaning-up)
  - [Applying updates](#applying-updates)
  - [Pulling images](#pulling-images)
  - [Switching branches](#switching-branches)
  - [Service to service configuration](#service-to-service-configuration)
- [Containers](#containers)
- [Local development](#local-development)
- [Variables](#variables)
- [Remarks](#remarks)

## Getting started

The following documentation assumes that the current directory is `ccd-docker`.

### Prerequisites

- [Docker](https://www.docker.com)

### Starting CCD

Choice is given to start CCD with or without its front-end depending on the use case.

To start CCD __with__ the front-end:

```bash
./compose-frontend.sh up -d
```

To start CCD __without__ the front-end:

```bash
./compose-backend.sh up -d
```

The `-d` (detached) option start the containers in the background.

The `./compose-frontend.sh` and `./compose-backend.sh` are wrappers for the following commands:
- `./compose-frontend.sh` -> `docker-compose -f compose/backend.yml -f compose/frontend.yml`
- `./compose-backend.sh` -> `docker-compose -f compose/backend.yml`

Regular `docker-compose` commands and options can be provided to the wrappers.

The containers will take ~1 minute to start. Their current status can be checked using the command:

```bash
docker ps
```

All containers should be flagged as `Up` and `healthy`.

### Using CCD

Once the containers are running, CCD's frontend can be accessed at [http://localhost:3451](http://localhost:3451).

However, 3 more steps are required to correctly configure IDAM and CCD before it can be used:

#### 1. Create a caseworker user

A caseworker user can be created in IDAM using the following command:

```bash
./bin/idam-create-caseworker.sh <roles> <email> [password] [surname] [forename]
```

Parameters:
- `roles`: a comma-separated list of roles. Roles must be existing IDAM roles for the CCD domain. Every caseworker requires at least it's coarse-grained jurisdiction role (`caseworker-<jurisdiction>`).
- `email`: Email address used for logging in.
- `password`: Optional. Password for logging in. Defaults to `password`.

For example:

```bash
./bin/idam-create-caseworker.sh caseworker-probate,caseworker-probate-solicitor probate@hmcts.net
```

#### 2. Add roles

Before a definition can be imported, roles referenced in a case definition Authorisation tabs must be defined in CCD using:

```bash
./bin/ccd-add-role.sh <role> [classification]
```

Parameters:
- `role`: Name of the role, e.g: `caseworker-divorce`.
- `classification`: Optional. One of `PUBLIC`, `PRIVATE` or `RESTRICTED`. Defaults to `PUBLIC`.

#### 3. Import case definition

To reduce impact on performances, case definitions are imported via the command line rather than using CCD's dedicated UI:

```bash
./bin/ccd-import-definition.sh <path_to_definition>
```

Parameters:
- `path_to_definition`: Path to `.xlsx` file containing the case definition.

**Note:** For CCD to work, the definition must contain the caseworker's email address created at [step 1](#1-create-a-caseworker-user).

If the import fails with an error of the form:

```
Validation errors occurred importing the spreadsheet.

- Invalid IdamRole 'caseworker-cmc-loa1' in AuthorisationCaseField tab, case type 'MoneyClaimCase', case field 'submitterId', crud 'CRUD'
```

Then the indicated role, here `caseworker-cmc-loa1`, must be added to CCD (See [2. Add roles](#2-add-roles)).

#### Ready for take-off 🛫

Back to [http://localhost:3451](http://localhost:3451), you can now log in with the email and password defined at [step 1](#1-create-a-caseworker-user).
If you left the password out when creating the caseworker, by default it's set to: `password`.

### Monitoring 🚥

Status of the containers can be checked using Docker's `ps` command:

```bash
./compose-frontend.sh ps
```

Logs for running containers can be viewed with:

```bash
./compose-frontend.sh logs [-f] [service]
```

The `-f` option allows to follow the tail of the logs.

The `service` parameter restricts the logs to the given service. It must match the name of a service as defined in the compose file.

For example:

```bash
./compose-frontend.sh logs -f ccd-definition-store-api
```

Omitting the `service` parameter will show logs for all the containers.

### Stopping and cleaning up

Containers can be stopped with:

```bash
./compose-frontend.sh stop [service]
```

Omitting the `service` parameters will stop all containers.

Stopped containers are **not** destroyed and can be restarted later using:

```bash
./compose-frontend.sh start [service]
```

To stop and destroy containers:

```bash
./compose-frontend.sh down [-v] [service]
```

If provided, the `-v` option will also clean the volumes.

Destroyed containers cannot be restarted. A new container will need to be built using the `up` command.

### Applying updates

Changes to container configuration, for example by using environment variables, can be applied by calling:

```bash
./compose-frontend.sh up [service]
```

Docker will compare the new configuration with the one currently running and recreate the modified containers.

### Pulling images

To get the latest version of an image from Artifactory, the `pull` command must be used.

```bash
./compose-frontend.sh pull [service]
```

### Switching branches

By default, the compose files are using CCD's `master` tag which indicates stable, release candidate code.

To switch to the Docker images representing the latest state of development, a `BRANCH` environment variable must be defined as `develop`.

```bash
export BRANCH=develop
```

### Service to service configuration

Micro-services names and secret keys must be registered as part of `service-auth-provider-api` configuration by adding environment variables like:

```yml
environment:
  auth.provider.service.server.microserviceKeys.<microservice_name>: <secret_key>
```

The `secret_key` must then also be provided to the container running the micro-service.

To remove duplication, the `secret_key` can be extracted to the Docker `.env` file and then be interpolated in the compose file, e.g:

`.env`:
```
IDAM_KEY_CCD_DATA_STORE=AAAAAAAAAAAAAAAB
```

`compose/backend.yml`:
```yml
environment:
  auth.provider.service.server.microserviceKeys.ccd_data: "${IDAM_KEY_CCD_DATA_STORE}"
```

## Containers

### Back-end

#### ccd-definition-store-api

Store holding the case type definitions, which are a case's states, events and schema as well as its display configuration for rendering in CCD's UI.

#### ccd-data-store-api

Store where the versioned instances of cases are recorded.

#### ccd-user-profile-api

Display preferences for the CCD users.

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

```bash
./compose-frontend.sh up
```

### 2. Configure local project to use containers

The local project properties must be reviewed to use the containers and comply to their configuration.

Mainly, this means:
- **Database**: pointing to the locally exposed port for the associated DB
- **IDAM**: pointing to the locally exposed port for IDAM
- **S2S**:
  - pointing to the locally exposed port for `service-auth-provider-api`
  - :warning: using the right key, as defined in `service-auth-provider-api` container
- **URLs**: all URLs should be updated to point to the corresponding locally exposed port

## Variables
Here are the important variables exposed in the compose files:

| Variable | Description |
| -------- | ----------- |
| IDAM_KEY_CCD_DATA_STORE | IDAM service-to-service secret key for `ccd_data` micro-service (CCD Data store), as registered in `service-auth-provider-api` |
| IDAM_KEY_CCD_GATEWAY | IDAM service-to-service secret key for `ccd_gw` micro-service (CCD API Gateway), as registered in `service-auth-provider-api` |
| IDAM_KEY_CCD_DEFINITION_STORE | IDAM service-to-service secret key for `ccd_definition` micro-service (CCD Definition store), as registered in `service-auth-provider-api` |
| DATA_STORE_S2S_AUTHORISED_SERVICES | List of micro-service names authorised to call this service, comma-separated, as registered in `service-auth-provider-api` |
| DEFINITION_STORE_S2S_AUTHORISED_SERVICES | List of micro-services authorised to call this service, comma-separated, as registered in `service-auth-provider-api` |
| USER_PROFILE_S2S_AUTHORISED_SERVICES | List of micro-services authorised to call this service, comma-separated, as registered in `service-auth-provider-api` |
| DATA_STORE_TOKEN_SECRET | Secret for generation of internal event tokens |
| APPINSIGHTS_INSTRUMENTATIONKEY | Secret for Microsoft Insights logging, can be a dummy string in local |
| DATA_STORE_DB_USE_SSL | `true` if data store application must use SSL while accessing DB, can be `false` for local environments |
| DEFINITION_STORE_DB_USE_SSL | `true` if definition store application must use SSL while accessing DB, can be `false` for local environments  |
| USER_PROFILE_DB_USE_SSL | `true` if user profile application must use SSL while accessing DB, can be `false` for local environments  |


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

- If you happen to see a following error when running `docker pull <image>` (eg. `docker pull idam-api`):
```
$ docker pull idam-api
Using default tag: latest
Error response from daemon: Get https://registry-1.docker.io/v2/library/idam-api/manifests/latest: unauthorized: incorrect username or password
```
then try running `docker image ls`
```
$ docker image ls
REPOSITORY                                                                        TAG                                        IMAGE ID            CREATED             SIZE
docker.artifactory.reform.hmcts.net/auth/idam-api                                 latest                                     8c25cb589020        11 days ago         121MB
```
and then see the actual registry REPOSITORY. You can then rerun it with proper REPOSITORY `docker pull docker.artifactory.reform.hmcts.net/auth/idam-api` to pull the image.

Alternatively use the recommended `./compose-frotned.sh pull` which will pull all required images using `docker-compose` command.

## LICENSE

This project is licensed under the MIT License - see the [LICENSE](LICENSE.md) file for details.

