### V11 postgres migration steps

##  Pull latest ccd docker
* Synch all micro-services with the same branch version for instance: develop
* Start ccd docker and make sure that the new container ccd-shared-database-v11 is up and running.

##  Backup all DB containers
* get your container id for instance: a210d7e11a5b
```
docker ps | grep compose_ccd-shared-database_1
```
* Backup all Dbs in a dumpfile file
```
docker exec -it a210d7e11a5b  /usr/bin/pg_dumpall -U  postgres  > dumpfile
```
* get your container id of the V11 DB for instance: 36a8eb5cccba
```
docker ps | grep compose_ccd-shared-database_1-V11
````
* copy the dumpfile to the V11 container DB
```
docker cp dumpfile 36a8eb5cccba:/home
```
* Import dumpfile in to your new DB V11
```
bash the container
docker exec -it 36a8eb5cccba bash

change permission to your dumpfile file
chmod 777 /home/dumpfile

su user
su - postgres
cd /home/

import the file and wait .....
psql < dumpfile

Check db data
psql
SELECT datname FROM pg_database;
\dt
select * from event;
````
##  Settings
*) add CCD_POSTGRES_11 in your bash fie
*) export CCD_POSTGRES_11=ccd-shared-database-v11
*) uncomment CCD_POSTGRES_11 in your .env file
````
#Postgres V11
CCD_POSTGRES_11=ccd-shared-database-v11
````

4) Open a new terminal, make sure that CCD_POSTGRES_11 has been set.
5) Stop and start ccd docker again
6) Stop old DB container

*) get your container id for instance: a210d7e11a5b
```
docker ps | grep compose_ccd-shared-database
```

*) stop the container
```
docker stop a210d7e11a5b
```

## Switch back to old DB
1) unset CCD_POSTGRES_11 value from the terminal
2) uncomment CCD_POSTGRES_11 in your .env file
```
#Postgres V11
#CCD_POSTGRES_11=ccd-shared-database-v11
````
3) Open a new terminal, make sure that CCD_POSTGRES_11 has been unset.
4) Stop and start ccd docker again

