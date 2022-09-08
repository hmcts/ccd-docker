# Postgres v11 migration steps

##  1 Pull latest ccd-docker (Mandatory)

**This has to be in place to be able to create the new postgres V11 DB container.**

* Make sure all micro-services are running the same branch, for instance: 'develop'.

* Start ccd-docker and make sure the new container ccd-shared-database-v11 is up and running.
```
./ccd compose up -d
```

**Note:** If you do not need your current DB data and want to destroy your data, please skip **Step 2** and continue with **Step 3** instructions to create the v11 DB.



## 2  Backup old database. Migrate data to the new database. (Optional step)

**The following steps describe the process of backing up the old DB in to the new DB.
These steps can be ignored in the case of building a new environment from scratch**

* Get your old DB container id, for instance: a210d7e11a5b
```
docker ps | grep compose_ccd-shared-database_1
```
* Backup all DBs in a dumpfile file
```
docker exec -it a210d7e11a5b  /usr/bin/pg_dumpall -U  postgres  > dumpfile
```
* Get the container id of the v11 DB for instance: **36a8eb5cccba**
```
docker ps | grep compose_ccd-shared-database_1-V11
````
* Copy the dumpfile to the v11 DB container
```
docker cp dumpfile 36a8eb5cccba:/home
```
* Open a shell into your v11 DB container
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
* Check the v11 DB data
```$xslt
psql
SELECT datname FROM pg_database;
\dt
select * from event;

```


##  3 Settings for ccd-docker (Mandatory)

**The following steps should be done to define the micro-services dependency to the new V11 DB container**

```
1) Stop and re-start the ccd-docker.
   
   Steps to stop the old DB container.

* Get the old DB container id, for instance: a210d7e11a5b.
```
docker ps | grep compose_ccd-shared-database
```

* Stop the container.
```
docker stop a210d7e11a5b
```
* Restart the ccd-docker container. 
```
./ccd compose up -d
```  

* In case you decide to not use the back up from old DB (Optional Step 2), you have to set up CCD users again, following the main guideline 
steps shown below: 
* CCD Quick Start
```
./bin/add-idam-clients.sh
./bin/add-idam-roles.sh
./bin/add-users.sh
./bin/add-ccd-roles.sh
```



