#!/usr/bin/env bash

set -eu

dir=$(dirname ${0})

${dir}/utils/idam-add-role.sh "caseworker"
${dir}/utils/idam-add-role.sh "caseworker-caa"
${dir}/utils/idam-add-role.sh "pui-caa"

${dir}/utils/idam-add-role.sh "caseworker-autotest1"
${dir}/utils/idam-add-role.sh "caseworker-autotest1-private"
${dir}/utils/idam-add-role.sh "caseworker-autotest1-senior"
${dir}/utils/idam-add-role.sh "caseworker-autotest1-solicitor"
${dir}/utils/idam-add-role.sh "caseworker-autotest2"
${dir}/utils/idam-add-role.sh "caseworker-autotest2-private"
${dir}/utils/idam-add-role.sh "caseworker-autotest2-senior"
${dir}/utils/idam-add-role.sh "caseworker-autotest2-solicitor"

#The following roles are needed for the Functional Test Automation
${dir}/utils/idam-add-role.sh "caseworker-befta_jurisdiction_1"
${dir}/utils/idam-add-role.sh "caseworker-befta_jurisdiction_2"
${dir}/utils/idam-add-role.sh "caseworker-befta_jurisdiction_2-solicitor_1"
${dir}/utils/idam-add-role.sh "caseworker-befta_jurisdiction_2-solicitor_2"
${dir}/utils/idam-add-role.sh "caseworker-befta_jurisdiction_2-solicitor_3"
${dir}/utils/idam-add-role.sh "caseworker-befta_jurisdiction_3"
${dir}/utils/idam-add-role.sh "caseworker-befta_jurisdiction_3-solicitor"
${dir}/utils/idam-add-role.sh "caseworker-befta_master"
${dir}/utils/idam-add-role.sh "caseworker-befta_master-solicitor"
${dir}/utils/idam-add-role.sh "caseworker-befta_master-solicitor_1"
${dir}/utils/idam-add-role.sh "caseworker-befta_master-solicitor_2"
${dir}/utils/idam-add-role.sh "caseworker-befta_master-solicitor_3"
${dir}/utils/idam-add-role.sh "caseworker-befta_master-junior"
${dir}/utils/idam-add-role.sh "caseworker-befta_master-manager"
${dir}/utils/idam-add-role.sh "ccd-import"