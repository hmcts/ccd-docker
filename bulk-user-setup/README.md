# The bulk user creation script

The script requires the following bash utilities. Please install them depending on your OS.

1. jq - [Json Processor](https://stedolan.github.io/jq)

2. [csvkit](https://formulae.brew.sh/formula/csvkit) - collection of CSV tools 

----

The script will prompt for the following information:

* path to the CSV input file (Directory path)
* ccd _idam-admin_ username
* ccd _idam-admin_ password
* idam oauth2 secret for _ccd-bulk-user-management_ client - 
* environment - will be prod in production environment

To get the oauth2 secret for idam client run the following:

az login (if not already logged in to Azure)
az keyvault secret show --vault-name ccd-prod --name ccd_bulk_user_management_secret

Generated log file and output files will be placed in bulk-user-setup/test/outputs/{Date} folder.

----

## CSV file format

The CSV input file must contain the following *mandatory* elements, including a header row.

| Header       | Mandatory                | Description                                                         |
|--------------|--------------------------|---------------------------------------------------------------------|
| operation    | **Yes**                  | `add` or `delete` or `updateName` or `find`                         |
| email        | **Yes**                  | Email address of the user.                                          |
| firstName    | **Depends on operation** | First name of the user.                                             |
| lastName     | **Depends on operation** | Last name of the user.                                              |
| roles        | **Depends on operation** | A pipe delimited list of roles for the user to be added or removed. |
| status       | (output)                 | Status of operation, e.g. `SUCCESS`, `HTTP-404`, etc.               |

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

Run the following scripts to create client and required users and roles for local testing from bulk-user-setup directory.

1. open terminal ensuring to change directory into root folder bulk-user-setup
2. cd into ./test/utils
3. execute ./add-idam-clients.sh
4. execute ./add-idam-roles.sh
   (Roles to be added are defined in the file: roles.json)
5. execute ./add-users.sh
   (Users to be added are defined in the file: users.json. Please ensure roles are created before assigning to users via the add-users.sh 
    script. To add a user without any roles, pass the roles as "''" as can be seen in the example file included in this repo.)

   Before running the main script make sure the input csv file(s) are copied to bulk-user-setup/test/inputs folder.

6. change directory back into root folder "bulk-user-setup"
7. execute ./bulk-user-setup.sh
   For testing in local, enter local when prompted for environment

After running the main script input files copied to bulk-user-setup/test/inputs will be processed in turn (only files with extension .csv will be considered)
Generated output and backup of input files will be copied to ../outputs/{DateTime} (i.e. /bulk-user-setup/test/outputs/{DateTime}) folder.
Any invalid input file will be skipped (i.e. due to missing or incorrect mandatory CSV header) and remain in the original bulk-user-setup/test/inputs folder.

When running the script you will be prompted for which environment to use (default being 'local'). This translates to the idam api url to use i.e.:

prod = https://idam-api.platform.hmcts.net
local = http://localhost:5000
other = https://idam-api.${other}.platform.hmcts.net

## Production setup / user guide

To use this bulk script in any environment other than local the following should be changed (if required):

1. Open a terminal session at the root directory 'bulk-user-setup'
2. Issue the command ./bulk-user-setup.sh
3. Provide inputs as required
4. Finally check output (results and logs to understand console output other than success, i.e. skipped, failed executions)

