export LOCATION="eastus"
export PREFIX="briar"
export SUFFIX=$RANDOM
export RG_NAME=$PREFIX-reddog-aks-$SUFFIX
export LOGFILE_NAME="./logs/${RG_NAME}.log"

./deploy-everything.sh $RG_NAME $LOCATION $SUFFIX 2>&1 | tee -a $LOGFILE_NAME