CREATE TABLE ACCESS_CONTROL (
    access_control_id BIGSERIAL primary key
);

drop table ACCESS_CONTROL;

create table "AccessManagement" (
	"accessManagementId" serial primary key,
 	"resourceId" varchar(250) not null,
	"accessorId" varchar(100) not null
);

CREATE TYPE SECURITYCLASSIFICATION AS ENUM ('Public', 'Private', 'Restricted');

CREATE TABLE roles (
  role_name VARCHAR(100) PRIMARY KEY,
  role_type VARCHAR (50) NOT NULL,
  security_classification SECURITYCLASSIFICATION NOT NULL
);

CREATE TABLE services (
  service_name VARCHAR(100) PRIMARY KEY,
  service_description VARCHAR(250)
);

CREATE TABLE resources (
  service_name VARCHAR(100) NOT NULL,
  resource_type VARCHAR(100) NOT NULL,
  resource_name VARCHAR(100) NOT NULL,
  PRIMARY KEY (service_name, resource_type, resource_name),
  CONSTRAINT resources_service_name_fkey FOREIGN KEY (service_name)
    REFERENCES services (service_name)
    ON UPDATE NO ACTION ON DELETE NO ACTION
);

CREATE TABLE resource_attributes (
  service_name VARCHAR(100) NOT NULL,
  resource_type VARCHAR(100) NOT NULL,
  resource_name VARCHAR(100) NOT NULL,
  attribute VARCHAR(250) NOT NULL,
  default_security_classification SECURITYCLASSIFICATION NOT NULL,
  PRIMARY KEY (service_name, resource_type, resource_name, attribute),
  CONSTRAINT resource_attributes_resources_fkey FOREIGN KEY (service_name, resource_type, resource_name)
    REFERENCES resources (service_name, resource_type, resource_name)
    ON UPDATE NO ACTION ON DELETE NO ACTION
);

CREATE TABLE default_permissions_for_roles (
  service_name VARCHAR(100) NOT NULL,
  resource_type VARCHAR(100) NOT NULL,
  resource_name VARCHAR(100) NOT NULL,
  attribute VARCHAR(250) NOT NULL,
  role_name VARCHAR(100) NOT NULL,
  permissions SMALLINT NOT NULL DEFAULT 0,
  UNIQUE (service_name, resource_type, resource_name, attribute, role_name),
  CONSTRAINT default_permissions_for_roles_roleName_fkey FOREIGN KEY (role_name)
    REFERENCES roles (role_name)
    ON UPDATE NO ACTION ON DELETE NO ACTION,
  CONSTRAINT default_permissions_for_roles_resource_attributes_fkey FOREIGN KEY (service_name, resource_type, resource_name, attribute)
    REFERENCES resource_attributes (service_name, resource_type, resource_name, attribute)
    ON UPDATE NO ACTION ON DELETE NO ACTION
);

alter table "AccessManagement"
add permissions integer not null default 0;

ALTER TABLE "AccessManagement"
  RENAME TO access_management;

ALTER TABLE access_management
  RENAME COLUMN "accessManagementId" TO access_management_id;

ALTER TABLE access_management
  RENAME COLUMN "resourceId" TO resource_id;

ALTER TABLE access_management
  RENAME COLUMN "accessorId" TO accessor_id;

ALTER TABLE access_management
  ADD COLUMN access_type varchar(100) NOT NULL;

ALTER TABLE access_management
  ADD COLUMN service_name varchar(100) NOT NULL;

ALTER TABLE access_management
  ADD COLUMN resource_type varchar(100) NOT NULL;

ALTER TABLE access_management
  ADD COLUMN resource_name varchar(100) NOT NULL;

ALTER TABLE access_management
  ADD COLUMN attribute varchar(20) NOT NULL;

ALTER TABLE access_management
  ADD COLUMN security_classification varchar(100) NOT NULL;

ALTER TABLE access_management
  ADD CONSTRAINT access_management_resources_fkey FOREIGN KEY (service_name, resource_type, resource_name)
REFERENCES resources (service_name, resource_type, resource_name)
ON UPDATE NO ACTION ON DELETE NO ACTION;

ALTER TABLE access_management
  ADD CONSTRAINT access_management_unique UNIQUE (resource_id, accessor_id, access_type, attribute, resource_type, service_name, resource_name, security_classification);


INSERT INTO services VALUES ('Service 1', 'Test service');
INSERT INTO resources VALUES ('Service 1','Resource Type 1','resource');

ALTER TABLE access_management
  ALTER COLUMN attribute TYPE varchar(250);


CREATE TYPE ACCESS_TYPE AS enum ('ROLE_BASED', 'EXPLICIT');
CREATE TYPE ROLE_TYPE AS enum ('IDAM', 'RESOURCE');

ALTER TABLE roles
  ADD COLUMN access_management_type ACCESS_TYPE NOT NULL;

ALTER TABLE roles
  ALTER COLUMN role_type TYPE ROLE_TYPE USING role_type::ROLE_TYPE;

ALTER TYPE SECURITYCLASSIFICATION RENAME TO SECURITY_CLASSIFICATION;

ALTER TYPE SECURITY_CLASSIFICATION ADD VALUE 'PUBLIC';
ALTER TYPE SECURITY_CLASSIFICATION ADD VALUE 'PRIVATE';
ALTER TYPE SECURITY_CLASSIFICATION ADD VALUE 'RESTRICTED';


ALTER TYPE SECURITY_CLASSIFICATION ADD VALUE 'NONE';


CREATE TYPE ACCESSOR_TYPE AS enum ('USER', 'ROLE');

ALTER TABLE access_management
  DROP CONSTRAINT access_management_unique;

UPDATE access_management SET access_type = UPPER(access_type);

ALTER TABLE access_management
  RENAME COLUMN access_type TO accessor_type;

ALTER TABLE access_management
  ADD COLUMN relationship VARCHAR(100) NOT NULL;

ALTER TABLE access_management
  ADD CONSTRAINT relationship_fkey FOREIGN KEY (relationship)
    REFERENCES roles (role_name)
    ON UPDATE NO ACTION ON DELETE NO ACTION;

ALTER TABLE access_management
  ALTER COLUMN accessor_type TYPE ACCESSOR_TYPE USING accessor_type::ACCESSOR_TYPE;

ALTER TABLE access_management
  ADD CONSTRAINT access_management_unique UNIQUE (resource_id, accessor_id, accessor_type, attribute, resource_type, service_name, resource_name, relationship);

ALTER TABLE roles
  RENAME COLUMN access_management_type TO access_type;

ALTER TABLE access_management
  DROP COLUMN security_classification;
