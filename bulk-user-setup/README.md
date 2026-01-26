# The bulk user creation script

The script requires the following bash utilities. Please install them depending on your OS.

1. jq - [Json Processor](https://ghcr.io/jqlang/jq)

2. [csvkit](https://formulae.brew.sh/formula/csvkit) - collection of CSV tools 

----
The script will prompt for the following information dependent on what is passed to the prompt for 'environment to use':

default environment is assumed to be 'local', for testing against the local docker environment no further prompts will be displayed
as all the required information is contained within 'bulk-user-setup.config'

1. environment (default if nothing provided is 'local')

If any other environment is passed i.e. 'prod' the following prompts will appear:

2. directory path containing csv input files (only enter the directory path)
3. ccd idam-admin username
4. ccd idam-admin password
5. idam oauth2 secret for ccd-bulk-user-register client -


To get the oauth2 secret for idam client against the prod environment run the following:

az login (if not already logged in to Azure)
az keyvault secret show --vault-name ccd-prod --name ccd_bulk_user_management_secret

Generated log file and output files will be placed in bulk-user-setup/test/outputs/{Date} folder.

----

## CSV file format

The CSV input file must contain the following *mandatory* elements, including a header row.

| Header            | Mandatory                | Description                                                         |
|-------------------|--------------------------|---------------------------------------------------------------------|
| operation         | **Yes**                  | `add` or `delete` or `updateName` or `find`                         |
| email             | **Yes**                  | Email address of the user.                                          |
| firstName         | **Depends on operation** | First name of the user.                                             |
| lastName          | **Depends on operation** | Last name of the user.                                              |
| roles             | **Depends on operation** | A pipe delimited list of roles for the user to be added or removed. |
| isActive          | (output)                 | active state of the user (TRUE/FALSE or blank)                      |
| lastModified      | (output)                 | datetime stamp user last updated or blank                           |
| status            | (output)                 | Status of operation, e.g. `SUCCESS`, `FAILED`, `SKIPPED`            |
| responseMessage   | (output)                 | additional output message for operation                             |

To enable overall testing we can supply the following headers in the test input files:

operation,email,firstName,lastName,roles,userExists,result,prerequisite,comment

where: 
userExists is a boolean value (TRUE/FALSE) which can later be used for verification
result is a string value (SUCCESS/FAILED/SKIPPED). If this header is provided and populated the test will verify the actual 
result of the operation.


> Note: The field headings are case-sensitive but the order of the columns is not important. Any additional columns
  will be ignored by the process.

The import CSV file is renamed by the process to discourage its accidental re-use. However, at the end of the process
 a copy of the output file is copied to the original input file location. This new file will contain the additional
 output fields listed above.

> Note: In the unlikely event the script terminates early; then manual intervention would be required to generate the
  ‘next’ input file: by combining the unprocessed input records with those already present in the latest output file.
  **Care should be taken to ensure the CSV data columns copied from the input file are in the same order as those in
  the output file.**

----

## Local docker testing setup

Run the following scripts to create the client and required users and roles for local testing.

****************************************************************************************************************************************************************************
** Testing ssoID logic can only be currently performed in the Demo environment. This is due to a limitation on local
   as the idam_api for search user does not return the ssoId attributes when using local docker instance image
   
   To test in demo, ensure the required demo test accounts are created first using the steps below
   a. Connect to the VPN
   b. Open a browser tab to 'https://idam-api.demo.platform.hmcts.net/swagger-ui/index.html?urls.primaryName=Testing%20Support#/Testing%20Support/createTestAccount'
   c. click try-it out
   d. Enter body payload, example:
        {
            "email": "ccd.test.add.ssoid@eJudiciary.net",
            "forename": "test",
            "surname": "tester",   
            "password": "Password123!",   
            "ssoId": "72b606e0-dd56-4c49-9335-2b0bd8f56f86",   
            "ssoProvider": "eJudiciary.net" 
        }
    e.  When executing the ./bulk-user-setup.sh, enter the following details for the demo environment 'ccd-bulk-user-register' service:
        environment: demo
        directory path: <enter absolute path and file name of input file to test in demo>
        username: test1.demo.bulkscript@hmcts.net
        password: Password123!
        oauth2 secret: <get from Az keyvault-secrets (env: demo, key-name: ccd-bulk-user-oauth2-client-secret)>
        If an account does not exist in demo (i.e. if the above is not used within 90 days the password will expire and a new account may be required)
        create the account such that it has the following roles: ccd-admin, ccd-import, idam-user-dashboard--access
****************************************************************************************************************************************************************************

1. open terminal ensuring to change directory into root folder "bulk-user-setup"
2. execute ./test/utils/add-idam-clients.sh (this needs to be done the first time only)
3. execute ./test/utils/add-idam-roles.sh (this should be executed the first time and any time new roles need to be added)
   ** Roles to be added are defined in the file: roles.json
4. execute ./test/utils/add-users.sh (see below first)

   ** Users to be added are defined in the file: users.json. Please ensure roles are created before assigning to them to users
   ** To add a user without any roles, pass the roles as "''" as can be seen in the example file included in this repo

   ** Note: In 'bulk-user-setup.config' the variable CREATE_TEST_USERS=true implies test users will be created 
      prior to processing any input file
   
   ** Since the search user api now uses the /api/v1 elastic search end-point, CREATE_TEST_USERS is set to false
      please wait some time between creating the test users and running the test cases (due to cache commits etc.)

   ** Before running the main script make sure the input csv file(s) are copied to bulk-user-setup/test/inputs folder.
   
5. execute ./bulk-user-setup.sh
   ** For testing in local, enter 'local' when prompted for environment

After running the main script input files copied to bulk-user-setup/test/inputs will be processed in turn (only files with extension .csv will be considered)
Generated output and backup of input files will be copied to ../outputs/{DateTime} (i.e. /bulk-user-setup/test/outputs/{DateTime}) folder.
Any invalid input file will be skipped (i.e. due to missing or incorrect mandatory CSV header) and remain in the original bulk-user-setup/test/inputs folder.

## Verifying results when testing locally against the test input scenario files

1. After all the .csv test input files are processed you should find a output log file i.e. BULK-SCRIPT-OUTPUT2022-11-14.log
2. Open this file and locate lines beginning with "Start - processing input file ../bulk-user-setup/test/inputs/<file>.csv"
   and "End - processing input file ../bulk-user-setup/test/inputs/<file>.csv"
3. Assuming the file was not skipped over (due to invalid format or invalid header attributes), you should see one of 
   the following just after each "End - processing input file..." statement
   "INFO **** ALL TESTS PASSED ****" or "INFO **** ALL TESTS FAILED ****" or "INFO **** NOT ALL TESTS PASSED ****"
4. If all tests did not pass in a particular input file, the log will display the line number of the failing test i.e.
   "DEBUG test failed at record number: 10"

When running the script you will be prompted for which environment to use (default being 'local'). This translates to the idam api url to use i.e.:

prod = https://idam-api.platform.hmcts.net
local = environment variable IDAM_OVERRIDE_URL if present otherwise http://localhost:5000
other = https://idam-api.${other}.platform.hmcts.net

## Production setup / user guide

To use this bulk script in any environment other than local the following should be changed (if required):

1. Open a terminal session at the root directory 'bulk-user-setup'
2. In 'bulk-user-setup.config' change CREATE_TEST_USERS=true to CREATE_TEST_USERS=false
3. Issue the command ./bulk-user-setup.sh
4. Provide inputs as required
5. Finally check output (results and logs to understand console output other than success, i.e. skipped, failed executions)
6. if ENABLE_CASEWORKER_CHECKS=true is set within 'bulk-user-setup.config', the script will (after processing the CSV input files) 
   check the local master caseworker file (caseworker-roles-master.txt) against the remote caseworker roles fetched via a GET api call
   Comparison results will be outputted to the console and log file. There is no automated process for updating the local master file.
   Refer to the output and decide if the missing caseworker roles need to be added to the processing logic.

