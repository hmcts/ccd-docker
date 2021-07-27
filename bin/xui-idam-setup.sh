#!/usr/bin/env bash

if [ -f .env ]
then
  export $(cat .env | sed 's/#.*//g' | xargs)
fi

IDAM_URI="http://localhost:5000"

REDIRECTS=("http://localhost:3455/oauth2/callback" "https://div-pfe-aat.service.core-compute-aat.internal/authenticated" "http://localhost:3000/oauth2/callback")
REDIRECTS_STR=$(printf "\"%s\"," "${REDIRECTS[@]}")
REDIRECT_URI="[${REDIRECTS_STR%?}]"

#DIV_CLIENT_ID="divorce"
XUI_CLIENT_ID="xui_webapp"

#DIV_CLIENT_SECRET="ccd_gateway_secret"
XUI_CLIENT_SECRET="xui_webapp_secrect"

#ROLES_ARR=("citizen" "claimant" "ccd-import" "caseworker-divorce" "caseworker" "caseworker-divorce-courtadmin_beta" "caseworker-divorce-systemupdate" "caseworker-divorce-superuser" "caseworker-divorce-pcqextractor" "caseworker-divorce-courtadmin-la" "caseworker-divorce-bulkscan" "caseworker-divorce-courtadmin" "caseworker-divorce-solicitor" "caseworker-caa" "payment")
#ROLES_STR=$(printf "\"%s\"," "${ROLES_ARR[@]}")
#ROLES="[${ROLES_STR%?}]"

XUI_ROLES_ARR=("XUI-Admin" "XUI-SuperUser" "caseworker" "caseworker-divorce" "caseworker-divorce-courtadmin_beta" "caseworker-divorce-superuser" "caseworker-divorce-courtadmin-la" "caseworker-divorce-courtadmin" "caseworker-divorce-solicitor" "caseworker-caa" "payment")
XUI_ROLES_STR=$(printf "\"%s\"," "${XUI_ROLES_ARR[@]}")
XUI_ROLES="[${XUI_ROLES_STR%?}]"

AUTH_TOKEN=$(curl -s -H 'Content-Type: application/x-www-form-urlencoded' -XPOST "${IDAM_URI}/loginUser?username=idamOwner@hmcts.net&password=Ref0rmIsFun" | docker run --rm --interactive stedolan/jq -r .api_auth_token)
HEADERS=(-H "Authorization: AdminApiAuthToken ${AUTH_TOKEN}" -H "Content-Type: application/json")

#echo "Setup divorce client"
## Create a client
#curl -s -o /dev/null -XPOST "${HEADERS[@]}" ${IDAM_URI}/services \
# -d '{ "activationRedirectUrl": "", "allowedRoles": '"${ROLES}"', "description": "'${DIV_CLIENT_ID}'", "label": "'${DIV_CLIENT_ID}'", "oauth2ClientId": "'${DIV_CLIENT_ID}'", "oauth2ClientSecret": "'${DIV_CLIENT_SECRET}'", "oauth2RedirectUris": '${REDIRECT_URI}', "oauth2Scope": "openid profile roles", "onboardingEndpoint": "string", "onboardingRoles": '"${ROLES}"', "selfRegistrationAllowed": true}'

echo "Setup xui client"
# Create a client
curl -s -o /dev/null -XPOST "${HEADERS[@]}" ${IDAM_URI}/services \
 -d '{ "activationRedirectUrl": "", "allowedRoles": '"${XUI_ROLES}"', "description": "'${XUI_CLIENT_ID}'", "label": "'${XUI_CLIENT_ID}'", "oauth2ClientId": "'${XUI_CLIENT_ID}'", "oauth2ClientSecret": "'${XUI_CLIENT_SECRET}'", "oauth2RedirectUris": '${REDIRECT_URI}', "oauth2Scope": "profile openid roles manage-user create-user", "onboardingEndpoint": "string", "onboardingRoles": '"${XUI_ROLES}"', "selfRegistrationAllowed": true}'


#echo "Setup divorce roles"
## Create roles in idam
#for role in "${ROLES_ARR[@]}"; do
#  curl -s -o /dev/null -XPOST ${IDAM_URI}/roles "${HEADERS[@]}" \
#    -d '{"id": "'${role}'","name": "'${role}'","description": "'${role}'","assignableRoles": [],"conflictingRoles": []}'
#done

echo "Setup xui roles"
# Create roles in idam
for role in "${XUI_ROLES_ARR[@]}"; do
  curl -s -o /dev/null -XPOST ${IDAM_URI}/roles "${HEADERS[@]}" \
    -d '{"id": "'${role}'","name": "'${role}'","description": "'${role}'","assignableRoles": [],"conflictingRoles": []}'
done

#echo "Setup divorce client roles"
## Assign all the roles to the client
#curl -s -o /dev/null -XPUT "${HEADERS[@]}" ${IDAM_URI}/services/${DIV_CLIENT_ID}/roles -d "${ROLES}"

echo "Setup xui client roles"
# Assign all the roles to the client
curl -s -o /dev/null -XPUT "${HEADERS[@]}" ${IDAM_URI}/services/${XUI_CLIENT_ID}/roles -d "${XUI_ROLES}"

#echo "Creating idam users"
#./bin/idam-create-user.sh citizen,claimant $IDAM_CITIZEN_USERNAME $IDAM_CITIZEN_PASSWORD citizens
#./bin/idam-create-user.sh caseworker,caseworker-divorce,caseworker-divorce-courtadmin_beta,caseworker-divorce-systemupdate,caseworker-divorce-courtadmin,caseworker-divorce-bulkscan,caseworker-divorce-superuser,caseworker-divorce-courtadmin-la $IDAM_CASEWORKER_USERNAME $IDAM_CASEWORKER_PASSWORD caseworker
#./bin/idam-create-user.sh caseworker,caseworker-divorce,caseworker-divorce-courtadmin_beta $IDAM_TEST_CASEWORKER_USERNAME $IDAM_TEST_CASEWORKER_PASSWORD caseworker
#./bin/idam-create-user.sh caseworker,caseworker-divorce,caseworker-divorce-solicitor,caseworker-divorce-superuser $IDAM_TEST_SOLICITOR_USERNAME $IDAM_TEST_SOLICITOR_PASSWORD caseworker
#./bin/idam-create-user.sh ccd-import $CCD_DEFINITION_IMPORTER_USERNAME $CCD_DEFINITION_IMPORTER_PASSWORD Default
echo "Idam setup complete"