# Idam Alternative Configurations
It's possible to disable the Idam-sim containers and run CCD with either full Idam containers provided by the `sidam.yml` file or using the `IDAM_OVERRIDE_URL` environment variable to point services towards an external IDAM instance.
This is useful for covering situations that the simulator cannot cover adequetly.

## Table of Contents

- [Run Full Idam Container Stack locally - SIDAM](#run-full-idam-container-stack-locally---sidam)
    - [Step 1 - Disable Idam sim containers](#step-1---disable-idam-sim-containers)
        - [Scenario 1 - Idam-sim is explictly Enabled](#scenario-1---idam-sim-is-explictly-enabled)
        - [Scenario 2 - Running the default compose files](#scenario-2---running-the-default-compose-files)
    - [Step 2 - Switching between Idam-sim and SIDAM](#step-2---switching-between-idam-sim-and-sidam)
    - [Step 3 - Setting up](#step-3---setting-up)
        - [1. Add idam clients](#1-add-idam-clients)
        - [2. Add Idam roles](#2-add-idam-roles)
        - [3. Add users](#3-add-users)
        - [4. Add CCD roles](#4-add-ccd-roles)
        - [5. Add role assignments](#5-add-role-assignments)
    - [Switching back to Idam Simulator](#switching-back-to-idam-simulator)
- [Using an external IDAM instance](#using-an-external-idam-instance)
    - [Enable Override](#enable-override)
    - [Revert to Idam Simulator](#revert-to-idam-simulator)
- [Troubleshooting full IDAM stack](#troubleshooting-full-idam-stack)

# Run Full Idam Container Stack locally - SIDAM

## Step 1 - Disable Idam sim containers

Make sure 'idam-sim' docker compose files are not enabled. How you do that depends on your currently active compose files.
When no active compose files are present, the default ones are executed. But if there's any active, then the defautl ones are ignored. If you run `./ccd enable show` you can figure out which compose files are currently active:

### Scenario 1 - Idam-sim is explictly Enabled

```bash
./ccd enable show

Currently active compose files:
backend
frontend
idam-sim    <---------- You can see idam-sim is enabled here

Default compose files:
backend
frontend
idam-sim
```

In this case idam-sim is currently explicitly enabled. To disable it run:
 `./ccd disable idam-sim`

You then need to enable `sidam` to replace it:
`./ccd enable sidam`

### Scenario 2 - Running the default compose files
```bash
./ccd enable show
No active compose files, using defaults. <--- Using defaults
Default compose files:
backend
frontend
idam-sim
```

You must explicitly enable only CCD compose files but exclude `idam-sim` and include `sidam` instead:

```bash
./ccd enable backend frontend sidam
./ccd enable show

Currently active compose files:
backend
frontend

Default compose files:
backend
frontend
sidam
```

## Step 2 - Switching between Idam-sim and SIDAM

First we need to set this variable so that all the scripts know that we will be using the IDAM full stack
instead of using the simulator
```bash
export IDAM_FULL_ENABLED=true
```
And if we are changing the port that IDAM will be using then we should also run
```bash
export IDAM_OVERRIDE_URL=http://localhost:5000
```

Here is an example of the process of switching between the two
```bash
# assuming no containers running and Idam-sim is enabled

# start with Idam-sim
./ccd compose up -d

# services started

./ccd compose stop

# disable Idam-sim follwing the steps in 'Step 1 - Disable Idam sim containers'

# tell scripts to use full idam stack logic
export IDAM_FULL_ENABLED=true
# ONLY IF NEEDED - export to override IDAM url 
export IDAM_OVERRIDE_URL=http://localhost:5000

# start with Full Idam Container Stack
./ccd compose up -d

# services started

```

## Step 3 - Setting up

To setup the full idam stack you will need to run an expanded version of the [Quick Start](../README.md#ccd-quick-start) commands

```bash
./bin/add-idam-clients.sh &&
./bin/add-idam-roles.sh &&
./bin/add-users.sh && 
./bin/add-ccd-roles.sh && 
./bin/add-role-assignments.sh
```

### 1. Add idam clients

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

> [!NOTE]
> `SELF_REGISTRATION` - a boolean parameter, defaults to a value of "false" if omitted
>
> `SCOPE` - a space delimited string parameter, defaults to a value of "openid profile roles" if omitted

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


### 2. Add Idam roles

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

> [!NOTE]
> The script adds roles under a _GLOBAL_ namespace and so until the users assigned to these roles are added,
you cannot verify them using SIDAM Web UI


#### Manual Configuration steps

Any roles should be configured for ccd-gateway client/service, on SIDAM Web Admin.

You need to login to the SIDAM Web Admin with the URL and logic credentials here: https://tools.hmcts.net/confluence/x/eQP3P

`Navigate to Home > Manage Roles > Select Your Service > Role Label`

Don't worry about the *Assignable roles* section when adding roles

Once the roles are defined under the client/service, go to the service configuration for the service you created in
Step 1 (`Home > Manage Services > select your service`) and select `ccd-import` role radio option under
**Private Beta Role** section

**Any business-related roles like `caseworker`,`caseworker-<jurisdiction>` etc to be used in CCD later must also be defined under the client configuration at this stage.**

### 3. Add users
See the [Add users](../README.md#1-add-users) section of the README

### 4. Add CCD roles
See the [Add CCD roles](../README.md#2-add-ccd-roles) section of the README

### 5. Add role assignments
See the [Add role assignments](../README.md#3-add-role-assignments) section of the README

### Switching back to Idam Simulator

#### Step 1 - Enable Sidam containers

```bash
./ccd enable idam-sim
```

or just revert to the default:

```bash
./ccd enable default
```

#### Step 2 - Unset environment variables for IDAM overrides
```bash
unset IDAM_FULL_ENABLED
unset IDAM_OVERRIDE_URL
```
> [!WARNING] 
> Always use `compose up` rather than `compose start` when switching between Idam and Idam Stub to have docker compose pick up env vars changes.


# Using an external IDAM instance

## Enable Override
in the '.env' file, uncomment the entries below and use your custom idam url:

```yaml
#IDAM_FULL_ENABLED=true
#IDAM_OVERRIDE_URL=http://some-other-idam-instance:5000
```

To allow some scripts to work properly you also may need to export the same variable:

```bash
export IDAM_FULL_ENABLED=true
export IDAM_OVERRIDE_URL=http://some-other-idam-instance:5000
```
## Revert to Idam Simulator

in the '.env' file, re-comment the entry from before:

```yaml
IDAM_FULL_ENABLED=true
IDAM_OVERRIDE_URL=http://some-other-idam-instance:5000
```

And remember to unset 'IDAM_OVERRIDE_URL' when switching back to the Idam-sim, otherwise it may cause issues
```bash
unset IDAM_FULL_ENABLED
unset IDAM_OVERRIDE_URL
```

# Troubleshooting full IDAM stack
> [!NOTE]
> If using the full Idam stack the containers can be slow to start - both the `definition-store-api` and `data-store-api` containers will
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

[Back to readme](../README.md)