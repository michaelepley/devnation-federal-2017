#!/bin/bash

# Configuration
. ./config.sh || { echo "FAILED: Could not configure" && exit 1 ; }

# Additional Configuration
# NONE

echo "clean up the demo environment"
echo "	--> make sure we are logged in"
oc whoami || oc login master.rhsademo.net -u ${OPENSHIFT_USER} -p ${OPENSHIFT_RHSADEMO_USER_PASSWORD_DEFAULT}

echo "	--> make sure we are using the correct project"
oc project ${OPENSHIFT_PROJECT} || { echo "WARNING: missing project -- nothing to do" && exit 1; }

echo "	--> deleting all openshift resources"
oc delete all --all
oc delete secret/mysql

echo "	--> deleting all local resources"
echo "		--> NOTE: nothing to do"

echo "	--> optionally delete the project"
echo "		--> delete the project ${OPENSHIFT_PROJECT} "

echo "Done"
