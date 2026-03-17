# psql / libpq
One of the requirements for running the scripts is haivng 

## For Mac: 
Make sure you have homebrew installed
```bash
 command -v psql
 ```
 If it **ISN'T** installed then install it using the instrucitons here https://brew.sh/
_____


Update Homebrew and install `libpq` to provide the `psql` command 
```bash
brew update
brew install libpq
```
___
Then to add a systemlink to your /bin directory you need to run
```bash
brew link --force libpq
```
___
After this you can restart your terminal and verify that the `psql` command is there now using
```bash
 command -v psql
 ```

## For Linux systems:
```bash
sudo apt update
sudo apt install postgresql postgresql-contrib
```

## For Windows 
We recommend using the installer from PostgreSQL.org. : https://www.postgresql.org/download/windows/

