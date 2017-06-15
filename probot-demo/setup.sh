#!/bin/bash

# Configuration
. ./config.sh || { echo "FAILED: Could not configure" && exit 1 ; }

# Additional Configuration
# NONE

# See https://docs.openshift.com/enterprise/latest for general openshift docs

echo "Create a Devnation Federal 2017 demo environment"
echo "	--> make sure we are logged in"
echo "	--> create a project for our work"
oc project ${OPENSHIFT_PROJECT} || oc new-project ${OPENSHIFT_PROJECT} ${OPENSHIFT_PROJECT_DESCRIPTION:+"--description"} ${OPENSHIFT_PROJECT_DESCRIPTION} ${OPENSHIFT_PROJECT_DISPLAY_NAME:+"--display-name"} ${OPENSHIFT_PROJECT_DISPLAY_NAME} || { echo "FAILED: could not create project" && exit 1 ; }

oc whoami || oc login master.rhsademo.net -u ${OPENSHIFT_USER} -p ${OPENSHIFT_RHSADEMO_USER_PASSWORD_DEFAULT}
echo "========== STATUS QUO deployment =========="

echo "	--> Create the ${OPENSHIFT_APPLICATION_BACKEND_NAME} application from the mysql-ephemeral template"
oc get dc/mysql || oc new-app mysql-ephemeral --name=mysql -l app=${OPENSHIFT_APPLICATION_NAME},part=${OPENSHIFT_APPLICATION_BACKEND_NAME} --param=MYSQL_USER=myphp --param=MYSQL_PASSWORD=myphp --param=MYSQL_DATABASE=myphp || { echo "FAILED: Could find or create the ${OPENSHIFT_APPLICATION_BACKEND_NAME} for ${OPENSHIFT_APPLICATION_NAME}" && exit 1; }

echo "	--> Create ${OPENSHIFT_APPLICATION_FRONTEND_NAME} application from the php:5.6 template and application git repo"
oc get dc/php || oc new-app php:5.6~https://github.com/michaelepley/phpmysqldemo.git#devnation-probot --name=php -l app=${OPENSHIFT_APPLICATION_NAME},part=${OPENSHIFT_APPLICATION_FRONTEND_NAME},demophase=statusquo -e MYSQL_SERVICE_HOST=mysql.${OPENSHIFT_PROJECT}.svc.cluster.local MYSQL_SERVICE_PORT=3306 -e MYSQL_SERVICE_DATABASE=myphp -e MYSQL_SERVICE_USERNAME=myphp -e MYSQL_SERVICE_PASSWORD=myphp || { echo "FAILED: Could find or create ${OPENSHIFT_APPLICATION_FRONTEND_NAME} for ${OPENSHIFT_APPLICATION_NAME}" && exit 1; }

echo "		--> configure the application with fairly minimal resources"
oc get dc/php && oc patch dc/php -p '{"spec" : { "template" : { "spec" : { "containers" : [ { "name" : "php", "resources" : { "limits" : { "cpu" : "400m" }, "requests" : { "cpu" : "200m" } } } ] } } } }' || { echo "FAILED: Could not patch application" && exit 1; }

echo "		--> configure the application with liveness and readiness checks"
oc set probe dc/php --liveness --readiness --get-url=http://:8080/ --failure-threshold=4 --timeout-seconds=4

echo "	--> Waiting for the ${OPENSHIFT_APPLICATION_FRONTEND_NAME} application to start....press any key to proceed"
while ! oc get pods | grep php | grep Running ; do echo -n "." && { read -t 1 -n 1 && break ; } && sleep 1s; done; echo ""

echo "	--> Expose the generic endpoint"
oc get route php || oc expose service php || { echo "FAILED: Could not verify route to application frontend" && exit 1; } || { echo "FAILED: Could patch frontend" && exit 1; }

echo "	--> Expose an endpoint for external users...start them with the default app"
oc get route devnation-visitors || oc expose service php --name devnation-visitors -l app=${OPENSHIFT_APPLICATION_NAME} --hostname="devnation-visitors.apps.rhsademo.net"

echo "	--> and for convenience, lets group the frontend and backend"
oc get svc/php && oc patch svc/php -p '{"metadata" : { "annotations" : { "service.alpha.openshift.io/dependencies" : "[ { \"name\" : \"mysql\" , \"kind\" : \"Service\"  } ]" } } }' || { echo "FAILED: Could not patch application" && exit 1; }

#firefox php-${OPENSHIFT_PROJECT}.apps.rhsademo.net?refresh=10

echo "	--> extracting the object definitions"

oc get bc/php -o json > ocp-myphp-php-build.json
oc get dc/php -o json > ocp-myphp-php-deploy.json
oc get svc/php -o json > ocp-myphp-php-service.json
oc get is/php -o json > ocp-myphp-php-imagestream.json
oc get route/devnation-visitors -o json > ocp-myphp-php-route.json

echo "	--> load the probot application with these objects & start it"
echo "	--> then, file a pull request against the repository"

echo "Done"
