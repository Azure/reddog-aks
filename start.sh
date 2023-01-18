#!/usr/bin/env bash 
set -eou pipefail 

source utils.sh

check_dependencies
mkdir -p outputs

# get params from config.json file
export CONFIG="$(cat config.json | jq -r .)"

export SUBSCRIPTION_ID="$(echo $CONFIG | jq -r '.subscription_id')"
export TENANT_ID="$(echo $CONFIG | jq -r '.tenant_id')"
export LOCATION="$(echo $CONFIG | jq -r '.location')"
export USERNAME="$(echo $CONFIG | jq -r '.username')"
export MONITORING="$(echo $CONFIG | jq -r '.monitoring')"
export STATE_STORE="$(echo $CONFIG | jq -r '.state_store')"
export USE_VIRTUAL_CUSTOMER="$(echo $CONFIG | jq -r '.use_virtual_customer')"

# set initial variables
export SUFFIX=$RANDOM
#export RG=$PREFIX-aks-reddog-$SUFFIX
export RG=reddog-aks-$SUFFIX
export LOGFILE_NAME="./outputs/${RG}.log"

./walk-the-dog.sh $RG $LOCATION $SUFFIX $USERNAME $MONITORING $STATE_STORE $USE_VIRTUAL_CUSTOMER 2>&1 | tee -a $LOGFILE_NAME
