# Containers explained

The various container config used in the CCD docker project is mostly located within the [compose](/compose/) folder

## [Backend.yml](/compose/backend.yml)

### ccd-user-profile-api

UI preferences for Core Case Data users.

See: https://github.com/hmcts/ccd-user-profile-api

### ccd-definition-store-api

Store holding the case type definitions, which are a case's states, events and schema as well as its display configuration for rendering in CCD's UI.

See: https://github.com/hmcts/ccd-data-store-api

### ccd-data-store-api

Store where the versioned instances of cases are recorded.

See: https://github.com/hmcts/ccd-data-store-api

### am-role-assignment-service

This SpringBoot application covers the implementation of the Role Assignment Service, 
which manages the assignment of roles with attributes to actors, 
to support both ccd access control and work allocation requirements.

See: https://github.com/hmcts/am-role-assignment-service

### service-auth-provider-api

This microservice is used to authenticate services across HMCTS.

See: https://github.com/hmcts/service-auth-provider-app

### ccd-shared-database

A local postgres database used by ccd services

See: [Dockerfile](../database/Dockerfile)

### idam-healthcheck

A local healthcheck proxy container used to handle container dependency when switching between
the idam-simulator and the SIDAM-api containers

See: [Dockerfile](../idam-health/Dockerfile)

### ccd-test-stubs-service

Service to facilitate testing of external http calls using wiremock. 
It returns canned responses for requests matching the predefined criteria.
Currently used for exposing a set of default callbacks that can be invoked for testing purposes

See: https://github.com/hmcts/ccd-test-stubs-service


## [Frontend.yml](/compose/frontend.yml)

### ccd-api-gateway

Secured API Gateway integrating with IDAM

See: https://github.com/hmcts/ccd-api-gateway

### ccd-admin-web

Web application for administration of Case Definition data (initially for importing definitions).

See: https://github.com/hmcts/ccd-admin-web

## [Idam-sim.yml](/compose/idam-sim.yml)

### rse-idam-simulator
This is a small spring-boot app that stubs only the endpoints of Idam Api required to request a Bearer Token and login.

Any call made by Idam Client are correctly handled by the Idam Simulator. The call from XUI for login and redirection is also handled.

See: https://github.com/hmcts/rse-idam-simulator/tree/master

[Back to readme](../README.md)