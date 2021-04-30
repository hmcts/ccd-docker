# Postgres v11 Prerequisites steps

##  1 Activate Postgres v11

**This has to be done to be able to create the new postgres V11 DB container.**

* Uncomment the ccd-shared-database-v11 section in the backend.yml.

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

##  2 Settings for ccd-docker

**The following steps should be done to define the micro-services dependencies to the new V11 DB container**

* Open backend.yml file and uncomment the dependency to ccd-shared-database-v11 for 'definition-store' and 'data-store'.  
```$xslt
#Uncomment this line to enable ccd-shared-database with Postgres version 11
      ccd-shared-database-v11:
        condition: service_started
```
* Comment the dependency to ccd-shared-database for 'definition-store' and 'data-store'.

```$xslt
#      ccd-shared-database:
#        condition: service_started
```
* Open message-publisher.yml file and uncomment the dependency to ccd-shared-database-v11.  
```$xslt
#Uncomment this line to enable ccd-shared-database with Postgres version 11
      ccd-shared-database-v11:
        condition: service_started
```
* Comment the dependency to ccd-shared-database on the message-publisher.yml file.
```$xslt
#      ccd-shared-database:
#        condition: service_started
```

* Add CCD_POSTGRES_11 env var to your local terminal bash file.

* Export CCD_POSTGRES_11=ccd-shared-database-v11 in your terminal. 
```$xslt
 export CCD_POSTGRES_11=ccd-shared-database-v11
```
* Uncomment CCD_POSTGRES_11 in your .env file.
````
#Postgres V11
CCD_POSTGRES_11=ccd-shared-database-v11
````

* Open a new terminal, make sure that CCD_POSTGRES_11 environment variable has been set.
```
env | grep CCD_POSTGRES_11
```
* Comment the old DB container ccd-shared-database section in backend.yml.
````
  #  ccd-shared-database:
  #    build: ../database
  #    healthcheck:
  #      interval: 10s
  #      timeout: 10s
  #      retries: 10
  #    environment:
  #      DB_USERNAME:
  #      DB_PASSWORD:
  #      POSTGRES_HOST_AUTH_METHOD: trust
  #    ports:
  #      - 5050:5432
  #    volumes:
  #      - ccd-docker-ccd-shared-database-data:/var/lib/postgresql/data
  #    networks:
  #      - ccd-network

````

