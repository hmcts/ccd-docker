#!/bin/bash
##This script will create the user roles.

parent_path=$( cd "$(dirname "${BASH_SOURCE[0]}")" ; pwd -P )
cd "$parent_path"

../bin/idam-create-caseworker.sh caseworker,caseworker-autotest1 auto.test.cnp@gmail.com password

../bin/ccd-add-role.sh caseworker-autotest1 PUBLIC
../bin/idam-create-caseworker.sh caseworker,caseworker-autotest1,caseworker-autotest1-private auto.test.cnp+private@gmail.com password
../bin/ccd-add-role.sh caseworker-autotest1-private PRIVATE
../bin/idam-create-caseworker.sh caseworker,caseworker-autotest1,caseworker-autotest1-senior auto.test.cnp+senior@gmail.com password
../bin/ccd-add-role.sh caseworker-autotest1-senior RESTRICTED
../bin/idam-create-caseworker.sh caseworker,caseworker-autotest1,caseworker-autotest1-solicitor auto.test.cnp+solc@gmail.com password
../bin/ccd-add-role.sh caseworker-autotest1-solicitor PRIVATE

../bin/idam-create-caseworker.sh caseworker,caseworker-autotest2 auto.test2.cnp@gmail.com password
../bin/ccd-add-role.sh caseworker-autotest2 PUBLIC
../bin/idam-create-caseworker.sh caseworker,caseworker-autotest2,caseworker-autotest2-private auto.test2.cnp+private@gmail.com password
../bin/ccd-add-role.sh caseworker-autotest2-private PRIVATE
../bin/idam-create-caseworker.sh caseworker,caseworker-autotest2,caseworker-autotest2-senior auto.test2.cnp+senior@gmail.com password
../bin/ccd-add-role.sh caseworker-autotest2-senior RESTRICTED
../bin/idam-create-caseworker.sh caseworker,caseworker-autotest2,caseworker-autotest2-solicitor auto.test2.cnp+solc@gmail.com password
../bin/ccd-add-role.sh caseworker-autotest2-solicitor PRIVATE

../bin/idam-create-caseworker.sh caseworker,caseworker-autotest1,caseworker-autotest2 auto.test12.cnp@gmail.com password
../bin/idam-create-caseworker.sh caseworker,caseworker-autotest1,caseworker-autotest1-private,caseworker-autotest2,caseworker-autotest2-private auto.test12.cnp+private@gmail.com password
../bin/idam-create-caseworker.sh caseworker,caseworker-autotest1,caseworker-autotest1-solicitor,caseworker-autotest2,caseworker-autotest2-solicitor auto.test12.cnp+solc@gmail.com password
../bin/idam-create-caseworker.sh caseworker,caseworker-autotest1,caseworker-autotest1-senior,caseworker-autotest2,caseworker-autotest2-senior auto.test12.cnp+senior@gmail.com password