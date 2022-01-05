export LOCATION="eastus"
export PREFIX="briar"

echo '****************************************************'
echo "Starting Red Dog on AKS deployment"
echo '****************************************************'

# Check for Azure login
echo "Checking to ensure logged into Azure CLI"
AZURE_LOGIN=0 
# run a command against Azure to check if we are logged in already.
az group list -o table
# save the return code from above. Anything different than 0 means we need to login
AZURE_LOGIN=$?

if [[ ${AZURE_LOGIN} -ne 0 ]]; then
# not logged in. Initiate login process
    az login --use-device-code
    export AZURE_LOGIN
fi

export RG_NAME=$PREFIX-reddog-aks-$RANDOM
echo "RG Name: " $RG_NAME

# create RG
echo "Creating Azure Resource Group"
az group create --name $RG_NAME --location $LOCATION

# create SSH keys
echo "Generating SSH keys (will overwrite existing)"
ssh-keygen -f ~/.ssh/aks-reddog -N '' <<< y  

export SSH_PUB_KEY="$(cat ~/.ssh/aks-reddog.pub)"

# get current user
export CURRENT_USER_ID=$(az ad signed-in-user show -o json | jq -r .objectId)
echo "Current user: " $CURRENT_USER_ID

# Bicep deployment
echo '****************************************************'
echo "Starting Bicep deployment of resources"
echo '****************************************************'

az deployment group create \
    --name aks-reddog \
    --mode Incremental \
    --resource-group $RG_NAME \
    --template-file ./deploy/bicep/main.bicep \
    --parameters prefix=$PREFIX \
    --parameters adminUsername="azureuser" \
    --parameters adminPublicKey="$SSH_PUB_KEY" \
    --parameters currentUserId="$CURRENT_USER_ID"

echo '****************************************************'
echo "Base infra deployed. Starting config/app deployment"
echo '****************************************************'    

# Save deployment outputs
mkdir -p outputs
echo "Bicep deployment outputs:"
az deployment group show -g $RG_NAME -n aks-reddog -o json --query properties.outputs | tee "./outputs/$RG_NAME-bicep-outputs.json"

# https://github.com/Azure/reddog-hybrid-arc/blob/main/infra/common/utils.subr

# Initialize KV  
echo "Create SP for KV and setup permissions"
export KV_NAME=$(cat ./outputs/$RG_NAME-bicep-outputs.json | jq -r .keyvaultName.value)
echo "Key Vault: $KV_NAME"
az ad sp create-for-rbac \
        --name "http://sp-$RG_NAME.microsoft.com" \
        --create-cert \
        --cert $RG_NAME-cert \
        --keyvault $KV_NAME \
        --years 1

## Get SP APP ID
echo "Getting SP_APPID ..."
SP_INFO=$(az ad sp list -o json --display-name "http://sp-$RG_NAME.microsoft.com")
SP_APPID=$(echo $SP_INFO | jq -r .[].appId)       

## Get SP Object ID
echo "Getting SP_OBJECTID ..."
SP_OBJECTID=$(echo $SP_INFO | jq -r .[].objectId)

echo "AKV SP_APPID: $SP_APPID" 
echo "AKV SP_OBJECTID: $SP_OBJECTID"

# Assign SP to KV with GET permissions
az keyvault set-policy \
    --name $KV_NAME \
    --object-id $SP_OBJECTID \
    --secret-permissions get  \
    --certificate-permissions get

# Assign permissions to the current user
UPN=$(az ad signed-in-user show  -o json | jq -r '.userPrincipalName')
echo "User UPN: " $UPN

az keyvault set-policy \
    --name $KV_NAME \
    --secret-permissions get list set \
    --certificate-permissions create get list \
    --upn $UPN  

# Download .pfx for Dapr secret (later)
az keyvault secret download \
    --vault-name $KV_NAME \
    --name $RG_NAME-cert \
    --encoding base64 \
    --file ./kv-$RG_NAME-cert.pfx  

# Write keys to KV
echo '****************************************************'
echo "Writing all secrets to KeyVault"
echo '****************************************************'

    # storage account
    export STORAGE_NAME=$(cat ./outputs/$RG_NAME-bicep-outputs.json | jq -r .storageAccountName.value)
    echo "Storage Account: $STORAGE_NAME"
    export STORAGE_KEY=$(cat ./outputs/$RG_NAME-bicep-outputs.json | jq -r .storageAccountKey.value)
    echo "Storage Key: $STORAGE_KEY"

    # cosmosdb
    export COSMOS_URI=$(jq -r .cosmosUri.value ./outputs/$RG_NAME-bicep-outputs.json)
    echo "Cosmos URI: " $COSMOS_URI
    export COSMOS_ACCOUNT=$(jq -r .cosmosAccountName.value ./outputs/$RG_NAME-bicep-outputs.json)
    echo "Cosmos Account: " $COSMOS_ACCOUNT
    export COSMOS_PRIMARY_RW_KEY=$(az cosmosdb keys list -n $COSMOS_ACCOUNT  -g $RG_NAME -o json | jq -r '.primaryMasterKey')
    echo "CosmosDB Key: " $COSMOS_PRIMARY_RW_KEY

exit 0
# Connect to AKS and create namespace, secrets 
echo '****************************************************'
echo "Connect to AKS and create namespace, secrets"
echo '****************************************************'
AKS_NAME=$(cat ./outputs/$RG_NAME-bicep-outputs.json | jq -r .aksName.value)
echo "AKS Cluster Name: " $AKS_NAME
az aks get-credentials -n $AKS_NAME -g $RG_NAME
