#!/bin/bash

# Configuration

[ -v CONFIGURATION_COMPLETE ] && echo "Configuration already complete, skipping" && { return  >/dev/null 2>&1 || exit ; } 

OPENSHIFT_USER=mepley
: ${OPENSHIFT_RHSADEMO_USER_PASSWORD_DEFAULT?"Set the environment variable OPENSHIFT_RHSADEMO_USER_PASSWORD_DEFAULT and retry"}

OPENSHIFT_PROJECT=${OPENSHIFT_USER}-devnation-federal-2017

OPENSHIFT_PRIMARY_MASTER=master.rhsademo.net
OPENSHIFT_PRIMARY_APPS=apps.rhsademo.net
OPENSHIFT_APPLICATION_NAME=myphp
OPENSHIFT_APPLICATION_FRONTEND_NAME=frontend
OPENSHIFT_APPLICATION_BACKEND_NAME=backend

GITHUB_USER_PRIMARY=michaelepley
SCRIPT_ENCRYPTION_KEY=${OPENSHIFT_RHSADEMO_USER_PASSWORD_DEFAULT}

[[ -v GITHUB_AUTHORIZATION_TOKEN_OPENSHIFT_DEMO_PLAINTEXT ]] || [[ -v GITHUB_AUTHORIZATION_TOKEN_OPENSHIFT_DEMO_CIPHERTEXT ]] || { echo "FAILED: GITHUB_AUTHORIZATION_TOKEN_OPENSHIFT_DEMO_PLAINTEXT must be set and match a valid GitHub.com Oauth2 personal access token with the following roles:" ; }
#GITHUB_AUTHORIZATION_TOKEN_OPENSHIFT_DEMO_PLAINTEXT=`echo ${GITHUB_AUTHORIZATION_TOKEN_OPENSHIFT_DEMO_CIPHERTEXT} | openssl enc -d -a | openssl enc -d -aes-256-cbc -k ${SCRIPT_ENCRYPTION_KEY} `
[[ -v GITHUB_AUTHORIZATION_TOKEN_OPENSHIFT_DEMO_PLAINTEXT ]] && echo "--> it is recommended to use an encrypted token; you may encrypt and store the token using the following: " && echo ' GITHUB_AUTHORIZATION_TOKEN_OPENSHIFT_DEMO_CIPHERTEXT=`echo ${GITHUB_AUTHORIZATION_TOKEN_OPENSHIFT_DEMO_PLAINTEXT} | openssl enc -e -aes-256-cbc -k ${SCRIPT_ENCRYPTION_KEY} | openssl enc -e -a`'
: ${GITHUB_AUTHORIZATION_TOKEN_OPENSHIFT_DEMO_PLAINTEXT:-`echo ${GITHUB_AUTHORIZATION_TOKEN_OPENSHIFT_DEMO_CIPHERTEXT} | openssl enc -d -a | openssl enc -d -aes-256-cbc -k ${SCRIPT_ENCRYPTION_KEY}`} || { echo "FAILED: Could not validate the github token" && exit 1; }

echo "_______Configuration_________"
echo "OPENSHIFT_USER                            = ${OPENSHIFT_USER}"
echo "OPENSHIFT_PROJECT                         = ${OPENSHIFT_PROJECT}"

echo "OPENSHIFT_PRIMARY_MASTER                  = ${OPENSHIFT_PRIMARY_MASTER}"
echo "OPENSHIFT_PRIMARY_APPS                    = ${OPENSHIFT_PRIMARY_APPS}"
echo "OPENSHIFT_APPLICATION_NAME                = ${OPENSHIFT_APPLICATION_NAME}"
echo "OPENSHIFT_APPLICATION_FRONTEND_NAME       = ${OPENSHIFT_APPLICATION_FRONTEND_NAME}"
echo "OPENSHIFT_APPLICATION_BACKEND_NAME        = ${OPENSHIFT_APPLICATION_BACKEND_NAME}"
echo "_____________________________"

CONFIGURATION_COMPLETE=true