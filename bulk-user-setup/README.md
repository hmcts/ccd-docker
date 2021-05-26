# The bulk user creation scrpt

The script requires the following bash utilities. Please install them depending on your OS.

1. jq - [Json Processor](https://stedolan.github.io/jq)

2. [csvkit](https://formulae.brew.sh/formula/csvkit) - collection of CSV tools 

----

The script will prompt for the following information:

* path to the CSV input file
* ccd _idam-admin_ username
* ccd _idam-admin_ password
* idam oauth2 secret for _ccd-bulk-user-register_ client
* environment

----

## CSV file format

The CSV input file must contain the following *mandatory* elements, including a header row.

| Header       | Mandatory | Description                                               |
|--------------|-----------|-----------------------------------------------------------|
| operation    | **Yes**   | Either `create` or `update`                                  |
| email        | **Yes**   | Email address of user.                                    |
| firstName    | **Yes**   | First name of user.                                       |
| lastName     | **Yes**   | Last name of user.                                        |
| roles        | **Yes**   | A pipe delimited list of roles for the user.              |
| rolesToAdd   | no        | A pipe delimited list of roles to add for the user.       |
| rolesToRemove| no        | A pipe delimited list of roles to remove for the user.    |
| inviteStatus | (output)  | Status of invite, e.g. `SUCCESS`, `HTTP-404`, etc.  NB: If process is re-run using the output file then it will skip rows that have `inviteStatus == 'SUCCESS'`. |
| idamResponse | (output)  | JSON response from API.                                   |
| idamUserJson | (output)  | Copy of JSON submission to API.                           |
| timestamp    | (output)  | Time of API call for user record.                         |

> Note: The field headings are case sensitive but the order of the columns is not important.  Any additional columns
  will be ignored by the process.

The import CSV file is renamed by the process to discourage its accidental re-use.  However at the end of the process
 a copy of the output file is copied to the original input file location.  This new file will contain the additional
 output fields listed above: these include the *inviteStatus* field which prevents successfully processed fields from
 being included in a repeat run.

> Note: In the unlikely event the script terminates early; then manual intervention would be required to generate the
  ‘next’ input file: by combining the unprocessed input records with those already present in the latest output file.
  **Care should be taken to ensure the CSV data columns copied from the input file are in the same order as those in
  the output file.**

----

## Local docker testing setup

1. Create a new client using [idam admin web interface](http://localhost:8082)

    * Client-id / label to  =>  "ccd-bulk-user-register"
    * Client description to  =>   "CCD bulk user register"
    * Client secret => anything
    * Scope => "create-user manage-user"
    * Redirect-uri => https://create-bulk-user-test/oauth2redirect

2. You need to use ccd admin user ideally rather than idam super admin for this activity.
   So, create a role like "ccd-admin" under service ccd-api-gateway on idam web and create a admin user with that role using bin/idam-create-caseworker.sh script.
   This role should have assigned role permissions for all other roles you want to assign to users. This can be done using "manage role" option on idam admin web console.
