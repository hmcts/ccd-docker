The script requires following bash utilities. Please install them depending on your OS.

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

The CSV input file must contain the following elements, including a header row.

| Header    | Description                                 |
|-----------|---------------------------------------------|
| email     | Email address of user                       |
| firstName | First name of user                          | 
| lastName  | Last name of user                           |
| roles     | A pipe delimited list of roles for the user |

> Note: The field headings are case sensitive but the order of the columns is not important.  Any additional columns will be ignored by the process.


**Local docker testing setup**

1. Create a new client using [idam admin web interface](http://localhost:8082)

    * Client-id / label to  =>  "ccd-bulk-user-register"
    * Client description to  =>   "CCD bulk user register"
    * Client secret => anything
    * Scope => "create-user"
    * Redirect-uri => https://create-bulk-user-test/oauth2redirect

2. You need to use ccd admin user ideally rather than idam super admin for this activity.
   So, create a role like "ccd-admin" under service ccd-api-gateway on idam web and create a admin user with that role using bin/idam-create-caseworker.sh script.
   This role should have assigned role permissions for all other roles you want to assign to users. This can be done using "manage role" option on idam admin web console.
