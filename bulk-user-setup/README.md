Script requires following bash utilities. Please install them depending on your OS.

1. jq - Json Processor https://stedolan.github.io/jq

2. csvkit - https://formulae.brew.sh/formula/csvkit 

The CSV input file must contain the following elements, including a header row.

| Header    | Description           |
|-----------|-----------------------|
| email     | email adress of user  |
| firstName | First name of user    | 
| lastName  | Last name 0f user     |
| roles     | A pipe delimited list of roles for user |

> Note: The field headings are case sensitive but the order of the columns is not important.  Any additional columns will be ignored by the process.
