# Steps to migrate existing PostgreSQL database to latest version

## Backup old database. Migrate data to the new database. (Optional Step)

**The following steps describe the process of backing up the old DB in to the new DB. 
These steps can be ignored in the case of building a new environment from scratch**

* Get your old DB container id, for instance: a210d7e11a5b
```
docker ps | grep compose_ccd-shared-database_1
```
* Backup all DBs to a dumpfile file. Verify the dumpfile is stored in your current directory
```
docker exec -it a210d7e11a5b  /usr/bin/pg_dumpall -U  postgres  > dumpfile
```


## Pull latest ccd-docker (MANDATORY)
**Note:** If you want to keep your current database data, please go the step above, [Backup old database](#1--backup-old-database-migrate-data-to-the-new-database--optional-step-)
* Make sure images/volumes of microservices are deleted with the following. 
**This has to be in place to be able to _migrate_ postgres version.**
``` 
./ccd compose down -v
```
* Make sure all microservices are running the same branch, for instance: 'master'.
```
./ccd status
```
* Please ensure you've exported/updated the required environment variables using the script, [set-environment-variables.sh](../bin/set-environment-variables.sh)
* Start ccd-docker and make sure ccd-shared-database is up and running.
```
./ccd compose up -d
```

**Note:** Skip Step 3 and go to [Step 4](#settings-for-ccd-docker-mandatory) if you did not make a backup of your DB data


## Restore database from backup
* Get the container id of the new DB for instance: **36a8eb5cccba**
```
docker ps | grep compose_ccd-shared-database_1-new
````
* Copy the dumpfile from your directory to the new DB container
```
docker cp dumpfile 36a8eb5cccba:/home
```
* Open a shell into your new DB container
```
docker exec -it 36a8eb5cccba bash
```
* Change the permission of the dumpfile file
```
chmod 777 /home/dumpfile
```
* Import the dumpfile and wait .....
```$xslt
su - postgres
cd /home/
psql < dumpfile

```
* Check the new DB data
```$xslt
psql
SELECT datname FROM pg_database;
\dt
select * from event;

```


## Settings for ccd-docker (MANDATORY)

**The following steps should be done to define the microservices dependency to the new DB container**

Stop and restart the old DB container.
* Get the DB container id, for instance: 36a8eb5cccba.
```
docker ps | grep compose_ccd-shared-database
```

* Stop the container.
```
docker stop 36a8eb5cccba
```
* Restart using. 
```
./ccd compose up -d
```  

* In case you did not use the back-up from your old DB, you have to set up CCD users again, following the main guideline steps shown below: 
* [CCD Quick Start](../README.md#quick-start)

[Back to readme](../README.md)