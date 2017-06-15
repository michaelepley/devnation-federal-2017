#!/bin/bash

# Configuration
. ./config.sh || { echo "FAILED: Could not configure" && exit 1 ; }

# Additional Configuration
# NONE

# See https://docs.openshift.com/enterprise/latest for general openshift docs

echo "Create a Devnation Federal 2017 demo environment"
echo "	--> make sure we are logged in"
oc whoami || oc login master.rhsademo.net -u ${OPENSHIFT_USER} -p ${OPENSHIFT_RHSADEMO_USER_PASSWORD_DEFAULT}
echo "	--> create a project for our work"
oc project ${OPENSHIFT_PROJECT} || oc new-project ${OPENSHIFT_PROJECT} ${OPENSHIFT_PROJECT_DESCRIPTION:+"--description"} ${OPENSHIFT_PROJECT_DESCRIPTION} ${OPENSHIFT_PROJECT_DISPLAY_NAME:+"--display-name"} ${OPENSHIFT_PROJECT_DISPLAY_NAME} || { echo "FAILED: could not create project" && exit 1 ; }

echo "========== STATUS QUO deployment =========="
echo "		--> press enter to continue" && read

echo "	--> Create the ${OPENSHIFT_APPLICATION_BACKEND_NAME} application from the mysql-ephemeral template"
oc get dc/mysql || oc new-app mysql-ephemeral --name=mysql -l app=${OPENSHIFT_APPLICATION_NAME},part=${OPENSHIFT_APPLICATION_BACKEND_NAME} --param=MYSQL_USER=myphp --param=MYSQL_PASSWORD=myphp --param=MYSQL_DATABASE=myphp || { echo "FAILED: Could find or create the ${OPENSHIFT_APPLICATION_BACKEND_NAME} for ${OPENSHIFT_APPLICATION_NAME}" && exit 1; }

echo "	--> Create ${OPENSHIFT_APPLICATION_FRONTEND_NAME} application from the php:5.6 template and application git repo"
oc get dc/php || oc new-app php:5.6~https://github.com/michaelepley/phpmysqldemo.git#devnation-master --name=php -l app=${OPENSHIFT_APPLICATION_NAME},part=${OPENSHIFT_APPLICATION_FRONTEND_NAME},demophase=statusquo -e MYSQL_SERVICE_HOST=mysql.${OPENSHIFT_PROJECT}.svc.cluster.local MYSQL_SERVICE_PORT=3306 -e MYSQL_SERVICE_DATABASE=myphp -e MYSQL_SERVICE_USERNAME=myphp -e MYSQL_SERVICE_PASSWORD=myphp || { echo "FAILED: Could find or create ${OPENSHIFT_APPLICATION_FRONTEND_NAME} for ${OPENSHIFT_APPLICATION_NAME}" && exit 1; }

echo "		--> configure the application with fairly minimal resources"
oc get dc/php && oc patch dc/php -p '{"spec" : { "template" : { "spec" : { "containers" : [ { "name" : "php", "resources" : { "limits" : { "cpu" : "400m" }, "requests" : { "cpu" : "200m" } } } ] } } } }' || { echo "FAILED: Could not patch application" && exit 1; }

echo "	--> Waiting for the ${OPENSHIFT_APPLICATION_FRONTEND_NAME} application to start....press any key to proceed"
while ! oc get pods | grep php | grep Running ; do echo -n "." && { read -t 1 -n 1 && break ; } && sleep 1s; done; echo ""

echo "	--> Expose the generic endpoint"
oc get route php || oc expose service php || { echo "FAILED: Could not verify route to application frontend" && exit 1; } || { echo "FAILED: Could patch frontend" && exit 1; }

echo "	--> Expose an endpoint for external users...start them with BLUE"
oc get route devnation-visitors || oc expose service php --name devnation-visitors -l app=${OPENSHIFT_APPLICATION_NAME} --hostname="devnation-visitors.apps.rhsademo.net"

#firefox php-${OPENSHIFT_PROJECT}.apps.rhsademo.net?refresh=10


echo "========== BLUE / GREEN deployment =========="
echo "		--> press enter to continue" && read

echo "	--> Create GREEN ${OPENSHIFT_APPLICATION_FRONTEND_NAME} application from the php:5.6 template and application git repo, GREEN branch"
oc get dc/green || oc new-app php:5.6~https://github.com/michaelepley/phpmysqldemo.git#devnation-green --name=green -l app=${OPENSHIFT_APPLICATION_NAME},part=${OPENSHIFT_APPLICATION_FRONTEND_NAME},color=green,demophase=bluegreen -e MYSQL_SERVICE_HOST=mysql.${OPENSHIFT_PROJECT}.svc.cluster.local MYSQL_SERVICE_PORT=3306 -e MYSQL_SERVICE_DATABASE=myphp -e MYSQL_SERVICE_USERNAME=myphp -e MYSQL_SERVICE_PASSWORD=myphp || { echo "FAILED: Could find or create GREEN deployment of ${OPENSHIFT_APPLICATION_FRONTEND_NAME} for ${OPENSHIFT_APPLICATION_NAME}" && exit 1; }
echo "		--> configure the application with fairly minimal resources"
oc get dc/green && oc patch dc/green -p '{"spec" : { "template" : { "spec" : { "containers" : [ { "name" : "green", "resources" : { "limits" : { "cpu" : "400m" }, "requests" : { "cpu" : "200m" } } } ] } } } }' || { echo "FAILED: Could not patch application" && exit 1; }

echo "	--> Create BLUE ${OPENSHIFT_APPLICATION_FRONTEND_NAME} application from the php:5.6 template and application git repo, BLUE branch"
oc get dc/blue  || oc new-app php:5.6~https://github.com/michaelepley/phpmysqldemo.git#devnation-blue  --name=blue  -l app=${OPENSHIFT_APPLICATION_NAME},part=${OPENSHIFT_APPLICATION_FRONTEND_NAME},color=blue,demophase=bluegreen -e MYSQL_SERVICE_HOST=mysql.${OPENSHIFT_PROJECT}.svc.cluster.local MYSQL_SERVICE_PORT=3306 -e MYSQL_SERVICE_DATABASE=myphp -e MYSQL_SERVICE_USERNAME=myphp -e MYSQL_SERVICE_PASSWORD=myphp || { echo "FAILED: Could find or create BLUE deployment of ${OPENSHIFT_APPLICATION_FRONTEND_NAME} for ${OPENSHIFT_APPLICATION_NAME}" && exit 1; }
echo "		--> configure the application with fairly minimal resources"
oc get dc/blue && oc patch dc/blue -p '{"spec" : { "template" : { "spec" : { "containers" : [ { "name" : "blue", "resources" : { "limits" : { "cpu" : "400m" }, "requests" : { "cpu" : "200m" } } } ] } } } }' || { echo "FAILED: Could not patch application" && exit 1; }

echo "	--> and for convenience, lets group the blue and green services"
oc get svc/blue && oc patch svc/blue -p '{"metadata" : { "annotations" : { "service.alpha.openshift.io/dependencies" : "[ { \"name\" : \"green\" , \"kind\" : \"Service\"  } ]" } } }' || { echo "FAILED: Could not patch application" && exit 1; }

echo "	--> Waiting for the blue nad green applications to start....press any key to proceed"
while ! oc get pods | grep blue | grep Running ; do echo -n "." && { read -t 1 -n 1 && break ; } && sleep 1s; done; echo ""
while ! oc get pods | grep green | grep Running ; do echo -n "." && { read -t 1 -n 1 && break ; } && sleep 1s; done; echo ""

echo "	--> Let's start everyone at blue"
oc patch route/devnation-visitors -p '{"spec" : { "to" : { "name" : "blue"} } }'

echo "	--> switch visitors from BLUE to GREEN"
echo "		--> press enter to continue" && read
oc patch route/devnation-visitors -p '{"spec" : { "to" : { "name" : "green"} } }'

echo "	--> revert that... visitors back to BLUE"
echo "		--> press enter to continue" && read
oc patch route/devnation-visitors -p '{"spec" : { "to" : { "name" : "blue"} } }'

echo "	--> Finally, switch visitors back to GREEN and leave them there "
echo "		--> press enter to continue" && read
oc patch route/devnation-visitors -p '{"spec" : { "to" : { "name" : "green"} } }'

echo "========== A / B deployment =========="
echo "	--> press enter to continue" && read
echo "		--> Set the A/B endpoint to direct some users to the green application, some to the blue"
oc set route-backends devnation-visitors blue=50 green=50
echo "		--> Or heavily favor one applicaton or the other"
echo "		--> press enter to continue" && read
oc set route-backends devnation-visitors blue=90 green=10
echo "		--> press enter to continue" && read
oc set route-backends devnation-visitors blue=10 green=90
echo "		--> press enter to continue" && read
echo "		--> Or gradually shift traffic from one application to the other"
oc set route-backends devnation-visitors green=10 blue=90 && sleep 2s
oc set route-backends devnation-visitors green=20 blue=80 && sleep 2s
oc set route-backends devnation-visitors green=30 blue=70 && sleep 2s
oc set route-backends devnation-visitors green=40 blue=60 && sleep 2s
oc set route-backends devnation-visitors green=50 blue=50 && sleep 2s
oc set route-backends devnation-visitors green=60 blue=40 && sleep 2s
oc set route-backends devnation-visitors green=70 blue=30 && sleep 2s
oc set route-backends devnation-visitors green=80 blue=20 && sleep 2s
oc set route-backends devnation-visitors green=90 blue=10 && sleep 2s
oc set route-backends devnation-visitors green=100 blue=0




echo "========== Canary deployment =========="
echo "	--> press enter to continue" && read
echo "	--> clean up old resources we don't need anymore..."
oc delete all -l color=blue
oc delete all -l color=green
oc delete all -l demophase=bluegreen
echo "	--> First, lets restore the default application for all visitors"
oc get route devnation-visitors || oc expose service php --name devnation-visitors -l app=${OPENSHIFT_APPLICATION_NAME} --hostname="devnation-visitors.apps.rhsademo.net"
oc set route-backends devnation-visitors php=100

echo "	--> Create ${OPENSHIFT_APPLICATION_FRONTEND_NAME} application from the php:5.6 template and application git repo, CANARY branch"
oc get dc/canary || oc new-app php:5.6~https://github.com/michaelepley/phpmysqldemo.git#devnation-canary-notok --name=canary -l app=${OPENSHIFT_APPLICATION_NAME},part=${OPENSHIFT_APPLICATION_FRONTEND_NAME},demophase=canary -e MYSQL_SERVICE_HOST=mysql.${OPENSHIFT_PROJECT}.svc.cluster.local MYSQL_SERVICE_PORT=3306 -e MYSQL_SERVICE_DATABASE=myphp -e MYSQL_SERVICE_USERNAME=myphp -e MYSQL_SERVICE_PASSWORD=myphp || { echo "FAILED: Could find or create ${OPENSHIFT_APPLICATION_FRONTEND_NAME} for ${OPENSHIFT_APPLICATION_NAME}" && exit 1; }
echo "	--> configure the application with fairly minimal resources"
oc get dc/canary && oc patch dc/canary -p '{"spec" : { "template" : { "spec" : { "containers" : [ { "name" : "canary", "resources" : { "limits" : { "cpu" : "400m" }, "requests" : { "cpu" : "200m" } } } ] } } } }' || { echo "FAILED: Could not patch application" && exit 1; }
echo "	--> and for convenience, lets group it with the original service"
oc get svc/php && oc patch svc/php -p '{"metadata" : { "annotations" : { "service.alpha.openshift.io/dependencies" : "[ { \"name\" : \"canary\" , \"kind\" : \"Service\"  } ]" } } }' || { echo "FAILED: Could not patch application" && exit 1; }
echo "	--> Waiting for the ${OPENSHIFT_APPLICATION_FRONTEND_NAME} application to start....press any key to proceed"
while ! oc get pods | grep canary | grep Running ; do echo -n "." && { read -t 1 -n 1 && break ; } && sleep 1s; done; echo ""

echo "	--> press enter to continue" && read
echo "	--> Now, we'll start routing traffic to the canary deployment, on its own endpoint"
oc get route canary || oc expose service canary || { echo "FAILED: Could not verify route to canaray application frontend" && exit 1; } || { echo "FAILED: Could patch frontend" && exit 1; }

echo "	--> And, we'll start diverting a small amount of traffic to the canary deployment, on its own endpoint"
oc set route-backends devnation-visitors php=90 canary=10

echo "	--> Set some probes to detect if our canary deployment fails"
oc set probe dc/canary --liveness --readiness --get-url=http://:8080/healthcheck --failure-threshold=4 --timeout-seconds=4

echo "	--> validating access to github"
{ curl -s -o /dev/null -w "%{http_code}" -i 'https://api.github.com/repos/michaelepley/phpmysqldemo' -H "Accept: application/vnd.github.v3+json" -H "Authorization: token ${GITHUB_AUTHORIZATION_TOKEN_OPENSHIFT_DEMO_PLAINTEXT:-`echo ${GITHUB_AUTHORIZATION_TOKEN_OPENSHIFT_DEMO_CIPHERTEXT} | openssl enc -d -a | openssl enc -d -aes-256-cbc -k ${SCRIPT_ENCRYPTION_KEY}`}" && echo ""; } || { echo "FAILED: cannot validate access to github" && exit 1; }
#echo "	--> checking existing webhooks"
#curl -s 'https://api.github.com/repos/michaelepley/phpmysqldemo/hooks' -H "Accept: application/vnd.github.v3+json" -H "Authorization: token ${GITHUB_AUTHORIZATION_TOKEN_OPENSHIFT_DEMO_PLAINTEXT:-`echo ${GITHUB_AUTHORIZATION_TOKEN_OPENSHIFT_DEMO_CIPHERTEXT} | openssl enc -d -a | openssl enc -d -aes-256-cbc -k ${SCRIPT_ENCRYPTION_KEY}`}" | jq '.[].id'
echo "	--> get canary application github webhook url"
{ oc get bc/canary && OPENSHIFT_APPLICATION_PHP_WEBHOOK_GITHUB=`oc describe bc/canary | grep github | grep webhooks | awk '{printf $2}'`; } || { echo "FAILED: Could not get metadata about the canary build" && exit 1; }
echo "	--> delete any old webhooks to the phpmysqldemo github project"
for OPENSHIFT_APPLICATION_PHP_WEBHOOK_GITHUB_ID in $(curl -s -X GET 'https://api.github.com/repos/michaelepley/phpmysqldemo/hooks' -H "Accept: application/vnd.github.v3+json" -H "Authorization: token ${GITHUB_AUTHORIZATION_TOKEN_OPENSHIFT_DEMO_PLAINTEXT:-`echo ${GITHUB_AUTHORIZATION_TOKEN_OPENSHIFT_DEMO_CIPHERTEXT} | openssl enc -d -a | openssl enc -d -aes-256-cbc -k ${SCRIPT_ENCRYPTION_KEY}`}" | jq '.[].id') ; do 
	curl -i -X DELETE -H "Accept: application/vnd.github.v3+json" -H "Authorization: token ${GITHUB_AUTHORIZATION_TOKEN_OPENSHIFT_DEMO_PLAINTEXT:-`echo ${GITHUB_AUTHORIZATION_TOKEN_OPENSHIFT_DEMO_CIPHERTEXT} | openssl enc -d -a | openssl enc -d -aes-256-cbc -k ${SCRIPT_ENCRYPTION_KEY}`}" 'https://api.github.com/repos/michaelepley/phpmysqldemo/hooks/'${OPENSHIFT_APPLICATION_PHP_WEBHOOK_GITHUB_ID} 
done

echo "	--> add new webhook to the phpmysqldemo github project"
OPENSHIFT_APPLICATION_PHP_WEBHOOK_GITHUB_CONFIG=$(cat <<EOF_OPENSHIFT_APPLICATION_PHP_WEBHOOK_GITHUB_CONFIG
{
  "name": "web",
  "active": true,
  "events": [
    "push"
  ],
  "config": {
    "url": "${OPENSHIFT_APPLICATION_PHP_WEBHOOK_GITHUB}",
    "insecure_ssl": true,
    "content_type": "json"
  }
}
EOF_OPENSHIFT_APPLICATION_PHP_WEBHOOK_GITHUB_CONFIG
)

echo "		--> webhook configuration is: " && echo ${OPENSHIFT_APPLICATION_PHP_WEBHOOK_GITHUB_CONFIG}
#debug with 'nc -l localhost 8000 &' and adding '--proxy localhost:8000' to curl
echo ${OPENSHIFT_APPLICATION_PHP_WEBHOOK_GITHUB_CONFIG} | curl  -i -X POST -H "Accept: application/vnd.github.v3+json" -H "Authorization: token ${GITHUB_AUTHORIZATION_TOKEN_OPENSHIFT_DEMO_PLAINTEXT:-`echo ${GITHUB_AUTHORIZATION_TOKEN_OPENSHIFT_DEMO_CIPHERTEXT} | openssl enc -d -a | openssl enc -d -aes-256-cbc -k ${SCRIPT_ENCRYPTION_KEY}`}" -H "Content-Type: application/json" -d @/dev/stdin 'https://api.github.com/repos/michaelepley/phpmysqldemo/hooks' 

echo "	--> Make sure all our triggers are active"
oc set triggers bc/canary --auto=true && oc set triggers dc/canary --auto=true
echo "	--> Modify the git repo, devnation-canary-notok branch to fix this"


echo "Done"
