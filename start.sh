mkdir -p outputs

# get params from config.json file
export CONFIG="$(cat config.json | jq -r .)"

export SUBSCRIPTION_ID="$(echo $CONFIG | jq -r '.subscription_id')"
export TENANT_ID="$(echo $CONFIG | jq -r '.tenant_id')"
export LOCATION="$(echo $CONFIG | jq -r '.location')"
export PREFIX="$(echo $CONFIG | jq -r '.prefix')"

# set initial variables
export SUFFIX=$RANDOM
export RG_NAME=$PREFIX-aks-reddog-$SUFFIX
export LOGFILE_NAME="./outputs/${RG_NAME}.log"

./walk-the-dog.sh $RG_NAME $LOCATION $SUFFIX 2>&1 | tee -a $LOGFILE_NAME
