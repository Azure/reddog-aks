mkdir -p outputs
export RG_NAME=$1
export LOCATION=$2

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
    --only-show-errors \
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
echo "Bicep deployment outputs:"
az deployment group show -g $RG_NAME -n aks-reddog -o json --query properties.outputs > "./outputs/$RG_NAME-bicep-outputs.json"

# https://github.com/Azure/reddog-hybrid-arc/blob/main/infra/common/utils.subr

# Initialize KV  
echo "Create SP for KV and setup permissions"
export KV_NAME=$(cat ./outputs/$RG_NAME-bicep-outputs.json | jq -r .keyvaultName.value)
echo "Key Vault: $KV_NAME"
az ad sp create-for-rbac \
        --name "http://sp-$RG_NAME.microsoft.com" \
        --only-show-errors \
        --create-cert \
        --cert $RG_NAME-cert \
        --keyvault $KV_NAME \
        --years 1

## Get SP APP ID
echo "Getting SP_APPID ..."
SP_INFO=$(az ad sp list -o json --display-name "http://sp-$RG_NAME.microsoft.com")
SP_APPID=$(echo $SP_INFO | jq -r .[].appId)  
echo "AKV SP_APPID: $SP_APPID"      

## Get SP Object ID
echo "Getting SP_OBJECTID ..."
SP_OBJECTID=$(echo $SP_INFO | jq -r .[].objectId)
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
    
    az keyvault secret set --vault-name $KV_NAME --name storage-key --value $STORAGE_KEY
    echo "KeyVault secret created: storage-key"

    # cosmosdb
    export COSMOS_URI=$(jq -r .cosmosUri.value ./outputs/$RG_NAME-bicep-outputs.json)
    echo "Cosmos URI: " $COSMOS_URI
    export COSMOS_ACCOUNT=$(jq -r .cosmosAccountName.value ./outputs/$RG_NAME-bicep-outputs.json)
    echo "Cosmos Account: " $COSMOS_ACCOUNT
    export COSMOS_PRIMARY_RW_KEY=$(az cosmosdb keys list -n $COSMOS_ACCOUNT  -g $RG_NAME -o json | jq -r '.primaryMasterKey')
    
    az keyvault secret set --vault-name $KV_NAME --name cosmos-primary-rw-key --value $COSMOS_PRIMARY_RW_KEY
    echo "KeyVault secret created: cosmos-primary-rw-key"

    # service bus
    export SB_NAME=$(jq -r .serviceBusName.value ./outputs/$RG_NAME-bicep-outputs.json)
    export SB_CONNECT_STRING=$(jq -r .serviceBusConnectString.value ./outputs/$RG_NAME-bicep-outputs.json)

    az keyvault secret set --vault-name $KV_NAME --name sb-root-connectionstring --value $SB_CONNECT_STRING
    echo "KeyVault secret created: sb-root-connectionstring"

    # Azure SQL
    export SQL_SERVER=$(jq -r .sqlServerName.value ./outputs/$RG_NAME-bicep-outputs.json)
    export SQL_ADMIN_USER_NAME=$(jq -r .sqlAdmin.value ./outputs/$RG_NAME-bicep-outputs.json)
    export SQL_ADMIN_PASSWD=$(jq -r .sqlPassword.value ./outputs/$RG_NAME-bicep-outputs.json)
    
    export REDDOG_SQL_CONNECTION_STRING="Server=tcp:${SQL_SERVER}.database.windows.net,1433;Database=reddoghub;User ID=${SQL_ADMIN_USER_NAME};Password=${SQL_ADMIN_PASSWD};Encrypt=true;Connection Timeout=30;"
    
    az keyvault secret set --vault-name $KV_NAME --name reddog-sql --value "${REDDOG_SQL_CONNECTION_STRING}"
    echo "KeyVault secret created: reddog-sql"

    # Redis
    export REDIS_HOST=$(jq -r .redisHost.value ./outputs/$RG_NAME-bicep-outputs.json)
    export REDIS_PORT=$(jq -r .redisSslPort.value ./outputs/$RG_NAME-bicep-outputs.json)
    export REDIS_FQDN="${REDIS_HOST}:${REDIS_PORT}"
    export REDIS_PASSWORD=$(jq -r .redisPassword.value ./outputs/$RG_NAME-bicep-outputs.json)

    az keyvault secret set --vault-name $KV_NAME --name redis-server --value $REDIS_FQDN
    echo "KeyVault secret created: redis-server"
    az keyvault secret set --vault-name $KV_NAME --name redis-password --value $REDIS_PASSWORD
    echo "KeyVault secret created: redis-password"

# Connect to AKS and create namespace, secrets 
echo '****************************************************'
echo "Connect to AKS and create namespace, secrets"
echo '****************************************************'
AKS_NAME=$(cat ./outputs/$RG_NAME-bicep-outputs.json | jq -r .aksName.value)
echo "AKS Cluster Name: " $AKS_NAME
az aks get-credentials -n $AKS_NAME -g $RG_NAME --overwrite-existing

echo 'Create reddog namespace'
kubectl create ns reddog
kubectl create secret generic -n reddog reddog.secretstore --from-file=secretstore-cert=./kv-$RG_NAME-cert.pfx --from-literal=vaultName=$KV_NAME
