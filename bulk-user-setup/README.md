# The bulk user creation script

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

| Header       | Mandatory                | Description                                                         |
|--------------|--------------------------|---------------------------------------------------------------------|
| operation    | **Yes**                  | `add` or `delete` or `updateName` or `find`                         |
| email        | **Yes**                  | Email address of the user.                                          |
| firstName    | **Depends on operation** | First name of the user.                                             |
| lastName     | **Depends on operation** | Last name of the user.                                              |
| roles        | **Depends on operation** | A pipe delimited list of roles for the user to be added or removed. |
| status       | (output)                 | Status of operation, e.g. `SUCCESS`, `HTTP-404`, etc.               |
| idamResponse | (output)                 | JSON response from API.                                             |
| timestamp    | (output)                 | Time of API call for user record.                                   |

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

1. Create a new client using [idam admin web interface](http://localhost:8082)

    * Client-id / label to  =>  "ccd-bulk-user-register"
    * Client description to  =>   "CCD bulk user register"
    * Client secret => anything
    * Scope => "create-user manage-user"
    * Redirect-uri => https://create-bulk-user-test/oauth2redirect

2. You need to use ccd admin user ideally rather than idam super admin for this activity.
   So, create a role like "ccd-admin" under service ccd-api-gateway on idam web and create a admin user with that role using bin/idam-create-caseworker.sh script.
   This role should have assigned role permissions for all other roles you want to assign to users. This can be done using "manage role" option on idam admin web console.
