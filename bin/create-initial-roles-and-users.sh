#!/bin/bash

##This script will create the user roles.

parent_path=$( cd "$(dirname "${BASH_SOURCE[0]}")" ; pwd -P )
cd "$parent_path"

#Roles are being created in Definition store
./ccd-add-role.sh caseworker-autotest1 PUBLIC
./ccd-add-role.sh caseworker-autotest1-private PRIVATE
./ccd-add-role.sh caseworker-autotest1-senior RESTRICTED
./ccd-add-role.sh caseworker-autotest1-solicitor PRIVATE
./ccd-add-role.sh caseworker-autotest2 PUBLIC
./ccd-add-role.sh caseworker-autotest2-private PRIVATE
./ccd-add-role.sh caseworker-autotest2-senior RESTRICTED
./ccd-add-role.sh caseworker-autotest2-solicitor PRIVATE

#The following roles are needed for the Functional Test Automation
./ccd-add-role.sh caseworker-befta_jurisdiction_1 PUBLIC
./ccd-add-role.sh caseworker-befta_jurisdiction_2 PUBLIC
./ccd-add-role.sh caseworker-befta_jurisdiction_2-solicitor_1 PUBLIC
./ccd-add-role.sh caseworker-befta_jurisdiction_2-solicitor_2 PUBLIC
./ccd-add-role.sh caseworker-befta_jurisdiction_2-solicitor_3 PUBLIC
./ccd-add-role.sh caseworker-befta_jurisdiction_3 PUBLIC
./ccd-add-role.sh caseworker-befta_jurisdiction_3-solicitor PUBLIC
./ccd-add-role.sh caseworker-befta_master PUBLIC
./ccd-add-role.sh caseworker-befta_master-solicitor_1 PUBLIC
./ccd-add-role.sh caseworker-befta_master-solicitor_2 PUBLIC
./ccd-add-role.sh caseworker-befta_master-solicitor_3 PUBLIC
./ccd-add-role.sh caseworker-befta_master-junior PUBLIC
./ccd-add-role.sh caseworker-befta_master-manager PUBLIC
./ccd-add-role.sh caseworker-caa PUBLIC

#Case workers are being created in SIDAM
./idam-create-caseworker.sh ccd-import ccd.docker.default@hmcts.net Pa55word11 Default CCD_Docker
./idam-create-caseworker.sh caseworker,caseworker-autotest1,ccd-import auto.test.cnp@gmail.com Pa55word11 testsurname testfirstname
./idam-create-caseworker.sh caseworker,caseworker-autotest1,caseworker-autotest1-private auto.test.cnp+private@gmail.com Pa55word11
./idam-create-caseworker.sh caseworker,caseworker-autotest1,caseworker-autotest1-senior auto.test.cnp+senior@gmail.com Pa55word11
./idam-create-caseworker.sh caseworker,caseworker-autotest1,caseworker-autotest1-solicitor auto.test.cnp+solc@gmail.com Pa55word11
./idam-create-caseworker.sh caseworker,caseworker-autotest2 auto.test2.cnp@gmail.com Pa55word11
./idam-create-caseworker.sh caseworker,caseworker-autotest2,caseworker-autotest2-private auto.test2.cnp+private@gmail.com Pa55word11
./idam-create-caseworker.sh caseworker,caseworker-autotest2,caseworker-autotest2-senior auto.test2.cnp+senior@gmail.com Pa55word11
./idam-create-caseworker.sh caseworker,caseworker-autotest2,caseworker-autotest2-solicitor auto.test2.cnp+solc@gmail.com Pa55word11
./idam-create-caseworker.sh caseworker,caseworker-autotest1,caseworker-autotest2 auto.test12.cnp@gmail.com Pa55word11
./idam-create-caseworker.sh caseworker,caseworker-autotest1,caseworker-autotest1-private,caseworker-autotest2,caseworker-autotest2-private auto.test12.cnp+private@gmail.com Pa55word11
./idam-create-caseworker.sh caseworker,caseworker-autotest1,caseworker-autotest1-solicitor,caseworker-autotest2,caseworker-autotest2-solicitor auto.test12.cnp+solc@gmail.com Pa55word11
./idam-create-caseworker.sh caseworker,caseworker-autotest1,caseworker-autotest1-senior,caseworker-autotest2,caseworker-autotest2-senior auto.test12.cnp+senior@gmail.com Pa55word11
./idam-create-caseworker.sh caseworker,caseworker-autotest1,caseworker-autotest1-senior ccdimportdomain@gmail.com Pa55word11

#The following users are needed for the Functional Test Automation
./idam-create-caseworker.sh caseworker,caseworker-befta_jurisdiction_1 befta.caseworker.1@gmail.com Pa55word11
./idam-create-caseworker.sh caseworker,caseworker-befta_jurisdiction_2 befta.caseworker.2@gmail.com Pa55word11
./idam-create-caseworker.sh caseworker,caseworker-befta_jurisdiction_2,caseworker-befta_jurisdiction_2-solicitor_1 befta.caseworker.2.solicitor.1@gmail.com Pa55word11
./idam-create-caseworker.sh caseworker,caseworker-befta_jurisdiction_2,caseworker-befta_jurisdiction_2-solicitor_2 befta.caseworker.2.solicitor.2@gmail.com Pa55word11
./idam-create-caseworker.sh caseworker,caseworker-befta_jurisdiction_2,caseworker-befta_jurisdiction_2-solicitor_3 befta.caseworker.2.solicitor.3@gmail.com Pa55word11
./idam-create-caseworker.sh citizen befta.citizen.2@gmail.com Pa55word11
./idam-create-caseworker.sh caseworker,caseworker-befta_jurisdiction_3,caseworker-befta_jurisdiction_3-solicitor befta.solicitor.3@gmail.com Pa55word11
./idam-create-caseworker.sh citizen befta.citizen.3@gmail.com Pa55word11
./idam-create-caseworker.sh caseworker,caseworker-befta_jurisdiction_3 befta.caseworker.3@gmail.com Pa55word11
./idam-create-caseworker.sh caseworker,caseworker-befta_jurisdiction_1 befta.caseworker.1.noprofile@gmail.com Pa55word11 testsurname testfirstname
./idam-create-caseworker.sh caseworker,caseworker-befta_master master.caseworker@gmail.com Pa55word11 befta master
./idam-create-caseworker.sh caseworker,caseworker-befta_master,caseworker-befta_master-solicitor_1 master.solicitor.1@gmail.com Pa55word11 befta solc1
./idam-create-caseworker.sh caseworker,caseworker-befta_master,caseworker-befta_master-solicitor_2 master.solicitor.2@gmail.com Pa55word11 befta solc2
./idam-create-caseworker.sh caseworker,caseworker-befta_master,caseworker-befta_master-solicitor_3 master.solicitor.3@gmail.com Pa55word11 befta solc3
./idam-create-caseworker.sh caseworker,caseworker-caa,caseworker-befta_master,caseworker-befta_jurisdiction_1,caseworker-befta_jurisdiction_2 befta.caseworker.caa@gmail.com Pa55word11
./idam-create-caseworker.sh caseworker,caseworker-befta_master-solicitor befta_master.solicitor.becky@gmail.com Pa55word11 Solicington Becky
./idam-create-caseworker.sh caseworker,caseworker-befta_master-solicitor befta_master.solicitor.benjamin@gmail.com Pa55word11 Solicington Benjamin
