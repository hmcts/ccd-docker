#ORG
INSERT INTO dbrefdata.organisation (id,name,status,sra_regulated,company_number,last_updated,created,organisation_identifier,company_url,sra_id,status_message,date_approved) VALUES
('aaaaaaaa-e48e-4e24-a1e8-2c2e6d55fe1f','SolicitorOrg1','ACTIVE',false,'W99999W','2019-08-16 15:00:41.418','2019-08-16 14:56:47.227','W98ZZ5W',NULL,'SRA1234562134',NULL,NULL);

#UserProfile
{"uuid":"8dc4e595-9be0-3abb-bf7d-06387e80cc78"}Creating user befta.caseworker.1@gmail.com
INSERT INTO dbuserprofile.user_profile
(id, idam_id, email_address, first_name, last_name, language_preference, email_comms_consent, email_comms_consent_ts, postal_comms_consent, postal_comms_consent_ts, user_category, user_type, extended_attributes, idam_status, created, last_updated)
VALUES(0, '<IDAM_ID_FOR_THIS_USER>', 'befta.caseworker.1@gmail.com', 'befta', 'caseworker', 'EN'::character varying, true, '2023-11-24 15:20:48.548', true, '2023-11-24 15:20:48.548', 'PROFESSIONAL', 'EXTERNAL', '{"roles": ["caseworker","caseworker-befta_jurisdiction_1"]}', 'ACTIVE'::character varying, '2023-11-24 15:20:48.548', '2023-11-24 15:20:48.548');
--
{"uuid":"fc490c98-3821-312f-95ff-ee9fc2859c0c"}Creating user befta.org.1@gmail.com
INSERT INTO dbuserprofile.user_profile
(id, idam_id, email_address, first_name, last_name, language_preference, email_comms_consent, email_comms_consent_ts, postal_comms_consent, postal_comms_consent_ts, user_category, user_type, extended_attributes, idam_status, created, last_updated)
VALUES(1, '<IDAM_ID_FOR_THIS_USER>', 'befta.org.1@gmail.com', 'befta', 'org', 'EN'::character varying, true, '2023-11-24 15:20:48.548', true, '2023-11-24 15:20:48.548', 'PROFESSIONAL', 'EXTERNAL', '{"roles": ["caseworker","caseworker-befta_jurisdiction_1"]}', 'ACTIVE'::character varying, '2023-11-24 15:20:48.548', '2023-11-24 15:20:48.548');

#ProfUser
INSERT INTO dbrefdata.professional_user
(id, first_name, last_name, email_address, organisation_id, last_updated, created, user_identifier, deleted)
VALUES('ffffffff-c278-4166-834a-46e64c2e306f', 'befta', 'caseworker', 'befta.caseworker.1@gmail.com', '<ORG_ID>', '2023-11-24 15:20:48.548', '2023-11-24 15:20:48.548', '<IDAM_ID_FOR_THIS_USER>', null);
--
INSERT INTO dbrefdata.professional_user
(id, first_name, last_name, email_address, organisation_id, last_updated, created, user_identifier, deleted)
VALUES('2fd032f8-20ba-413e-a1fb-65aed26a3a9a', 'befta', 'org', 'befta.org.1@gmail.com', '<ORG_ID>', '2023-11-24 15:20:48.548', '2023-11-24 15:20:48.548', '<IDAM_ID_FOR_THIS_USER>', null);
