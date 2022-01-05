export LOCATION="eastus"
export PREFIX="briar"
export RG_NAME=$PREFIX-reddog-aks-$RANDOM
export LOGFILE_NAME="./logs/${RG_NAME}.log"

./deploy-everything.sh $RG_NAME $LOCATION 2>&1 | tee -a $LOGFILE_NAME