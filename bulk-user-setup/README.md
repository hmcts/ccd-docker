The script requires following bash utilities. Please install them depending on your OS.

1. jq - Json Processor https://stedolan.github.io/jq

2. csvkit - collection of CSV tools https://formulae.brew.sh/formula/csvkit 

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
