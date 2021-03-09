# V11 postgres migration steps

##  Pull latest ccd docker
* Make sure all micro-services running the same branch, for instance: 'develop'
* Start ccd docker and make sure that the new container ccd-shared-database-v11 is up and running.
* Uncomment ccd-shared-database-v11 section in the backend.yml
````
  ccd-shared-database-v11:
    build: ../database-v11
    healthcheck:
      interval: 10s
      timeout: 10s
      retries: 10
    environment:
      DB_USERNAME:
      DB_PASSWORD:
      POSTGRES_HOST_AUTH_METHOD: trust
    ports:
      - 5055:5432
    volumes:
      - ccd-docker-ccd-shared-database-data-v11:/var/lib/postgresql/data
    networks:
      - ccd-network

````

##  Backup all DB containers
* Get your container id, for instance: a210d7e11a5b
```
docker ps | grep compose_ccd-shared-database_1
```
* Backup all Dbs in a dumpfile file
```
docker exec -it a210d7e11a5b  /usr/bin/pg_dumpall -U  postgres  > dumpfile
```
* Get the container id of the V11 DB for instance: **36a8eb5cccba**
```
docker ps | grep compose_ccd-shared-database_1-V11
````
* Copy the dumpfile to the V11 container DB
```
docker cp dumpfile 36a8eb5cccba:/home
```
* Import dumpfile in to your new DB V11
```
docker exec -it 36a8eb5cccba bash
```
* Change the permission of dumpfile file
```
chmod 777 /home/dumpfile
```
* Import the file and wait .....
```$xslt
su user
su - postgres
cd /home/
psql < dumpfile

```
* Check the db data
```$xslt
psql
SELECT datname FROM pg_database;
\dt
select * from event;

```

##  Settings for CCD docker
* Add CCD_POSTGRES_11 env var to your local terminal bash file
* Export CCD_POSTGRES_11=ccd-shared-database-v11 in your terminal 
```$xslt
 export CCD_POSTGRES_11=ccd-shared-database-v11
```
* Uncomment CCD_POSTGRES_11 in your .env file
````
#Postgres V11
CCD_POSTGRES_11=ccd-shared-database-v11
````

1) Open a new terminal, make sure that CCD_POSTGRES_11 var has been set.
2) Stop and start ccd docker again
3) Stop old DB container

* Get the old DB container id, for instance: a210d7e11a5b
```
docker ps | grep compose_ccd-shared-database
```

* Stop the container
```
docker stop a210d7e11a5b
```
* Comments ccd-shared-database section in the backend.yml

## Switch back to old DB
1) Unset CCD_POSTGRES_11 value from the terminal
2) Comment CCD_POSTGRES_11 in your .env file
```
#Postgres V11
#CCD_POSTGRES_11=ccd-shared-database-v11
````
* Uncomment ccd-shared-database (OLD DB) section in the backend.yml

1) Open a new terminal, make sure that CCD_POSTGRES_11 var has been unset.
2) Stop and start ccd docker again

