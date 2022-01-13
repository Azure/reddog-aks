mkdir -p outputs
export RG_NAME=$1
export LOCATION=$2
export SUFFIX=$3

start_time=$(date +%s)

# show all params
echo '****************************************************'
echo 'Starting Red Dog on AKS deployment'
echo ''
echo 'Parameters:'
echo 'SUBSCRIPTION: ' $SUBSCRIPTION_ID
echo 'TENANT: ' $TENANT_ID
echo 'LOCATION: ' $LOCATION
echo 'RG_NAME: ' $RG_NAME
echo 'LOGFILE_NAME: ' $LOGFILE_NAME
echo '****************************************************'
echo ''

# Check for Azure login
echo 'Checking to ensure logged into Azure CLI'
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

# update az CLI to install extensions automatically
az config set extension.use_dynamic_install=yes_without_prompt

# setup az CLI features
echo 'Configuring extensions and features for az CLI'
az feature register --namespace Microsoft.ContainerService --name AKS-ExtensionManager
az provider register --namespace Microsoft.Kubernetes --consent-to-permissions
az provider register --namespace Microsoft.ContainerService --consent-to-permissions
az provider register --namespace Microsoft.KubernetesConfiguration --consent-to-permissions
az extension add -n k8s-configuration
az extension add -n k8s-extension
az extension update -n k8s-configuration
az extension update -n k8s-extension

# create RG
echo "Creating Azure Resource Group"
az group create --name $RG_NAME --location $LOCATION

# create SSH keys
echo 'Generating SSH keys (will overwrite existing)'
ssh-keygen -f ~/.ssh/aks-reddog -N '' <<< y  

export SSH_PUB_KEY="$(cat ~/.ssh/aks-reddog.pub)"

# get current user
export CURRENT_USER_ID=$(az ad signed-in-user show -o json | jq -r .objectId)
echo 'RG Name: ' $RG_NAME
echo 'Current user: ' $CURRENT_USER_ID

# Bicep deployment
echo ''
echo '****************************************************'
echo 'Starting Bicep deployment of resources'
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

echo ''
echo '****************************************************'
echo 'Base infra deployed. Starting config/app deployment'
echo '****************************************************'    

# Save deployment outputs
az deployment group show -g $RG_NAME -n aks-reddog -o json --query properties.outputs > "./outputs/$RG_NAME-bicep-outputs.json"

# Connect to AKS and create namespace, redis
echo ''
echo '****************************************************'
echo 'Connect to AKS and create namespace, secrets'
echo '****************************************************'
AKS_NAME=$(cat ./outputs/$RG_NAME-bicep-outputs.json | jq -r .aksName.value)
echo 'AKS Cluster Name: ' $AKS_NAME
az aks get-credentials -n $AKS_NAME -g $RG_NAME --overwrite-existing

echo 'Create namespaces'
kubectl create ns reddog
kubectl create ns redis

echo 'Deploying Redis Helm chart' # https://bitnami.com/stack/redis/helm
export REDIS_PASSWD='w@lkingth3d0g'
helm repo add azure-marketplace https://marketplace.azurecr.io/helm/v1/repo
helm install redis-release azure-marketplace/redis \
    --namespace redis \
    --set auth.password=$REDIS_PASSWD \
    --set replica.replicaCount=2

kubectl create secret generic redis-password --from-literal=redis-password=$REDIS_PASSWD -n reddog    

# Initialize KV  
echo 'Create SP for KV and setup permissions'
export KV_NAME=$(cat ./outputs/$RG_NAME-bicep-outputs.json | jq -r .keyvaultName.value)
echo 'Key Vault: ' $KV_NAME
az ad sp create-for-rbac \
        --name "http://sp-$RG_NAME.microsoft.com" \
        --only-show-errors \
        --create-cert \
        --cert $RG_NAME-cert \
        --keyvault $KV_NAME \
        --years 1

## Get SP APP ID
echo 'Getting SP_APPID ...'
SP_INFO=$(az ad sp list -o json --display-name "http://sp-$RG_NAME.microsoft.com")
SP_APPID=$(echo $SP_INFO | jq -r .[].appId)  
echo 'AKV SP_APPID: ' $SP_APPID

## Get SP Object ID
echo 'Getting SP_OBJECTID ...'
SP_OBJECTID=$(echo $SP_INFO | jq -r .[].objectId)
echo 'AKV SP_OBJECTID: ' $SP_OBJECTID

# Assign SP to KV with GET permissions
az keyvault set-policy \
    --name $KV_NAME \
    --object-id $SP_OBJECTID \
    --secret-permissions get  \
    --certificate-permissions get

# Assign permissions to the current user
UPN=$(az ad signed-in-user show  -o json | jq -r '.userPrincipalName')
echo 'User UPN: ' $UPN

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

# Create K8s secret for above pfx (used by Dapr)
# kubectl create secret generic -n reddog reddog.secretstore --from-file=secretstore-cert=./kv-$RG_NAME-cert.pfx --from-literal=vaultName=$KV_NAME
kubectl create secret generic reddog.secretstore \
    --namespace reddog \
    --from-file=secretstore-cert=./kv-$RG_NAME-cert.pfx \
    --from-literal=vaultName=$KV_NAME \
    --from-literal=spnClientId=$SP_APPID \
    --from-literal=spnTenantId=$TENANT_ID

# Write keys to KV
echo ''
echo '****************************************************'
echo 'Writing all secrets to KeyVault'
echo '****************************************************'

    # storage account
    export STORAGE_NAME=$(cat ./outputs/$RG_NAME-bicep-outputs.json | jq -r .storageAccountName.value)
    echo 'Storage Account: ' $STORAGE_NAME
    export STORAGE_KEY=$(cat ./outputs/$RG_NAME-bicep-outputs.json | jq -r .storageAccountKey.value)
    
    az keyvault secret set --vault-name $KV_NAME --name blob-storage-key --value $STORAGE_KEY
    echo 'KeyVault secret created: storage-key'

    # cosmosdb
    # export COSMOS_URI=$(jq -r .cosmosUri.value ./outputs/$RG_NAME-bicep-outputs.json)
    # echo "Cosmos URI: " $COSMOS_URI
    # export COSMOS_ACCOUNT=$(jq -r .cosmosAccountName.value ./outputs/$RG_NAME-bicep-outputs.json)
    # echo "Cosmos Account: " $COSMOS_ACCOUNT
    # export COSMOS_PRIMARY_RW_KEY=$(az cosmosdb keys list -n $COSMOS_ACCOUNT  -g $RG_NAME -o json | jq -r '.primaryMasterKey')
    
    # az keyvault secret set --vault-name $KV_NAME --name cosmos-primary-rw-key --value $COSMOS_PRIMARY_RW_KEY
    # echo "KeyVault secret created: cosmos-primary-rw-key"

    # service bus
    export SB_NAME=$(jq -r .serviceBusName.value ./outputs/$RG_NAME-bicep-outputs.json)
    export SB_CONNECT_STRING=$(jq -r .serviceBusConnectString.value ./outputs/$RG_NAME-bicep-outputs.json)

    az keyvault secret set --vault-name $KV_NAME --name sb-root-connectionstring --value $SB_CONNECT_STRING
    echo 'KeyVault secret created: sb-root-connectionstring'

    # Azure SQL
    export SQL_SERVER=$(jq -r .sqlServerName.value ./outputs/$RG_NAME-bicep-outputs.json)
    export SQL_ADMIN_USER_NAME=$(jq -r .sqlAdmin.value ./outputs/$RG_NAME-bicep-outputs.json)
    export SQL_ADMIN_PASSWD=$(jq -r .sqlPassword.value ./outputs/$RG_NAME-bicep-outputs.json)
    
    export REDDOG_SQL_CONNECTION_STRING="Server=tcp:${SQL_SERVER}.database.windows.net,1433;Database=reddog;User ID=${SQL_ADMIN_USER_NAME};Password=${SQL_ADMIN_PASSWD};Encrypt=true;Connection Timeout=30;"
    
    az keyvault secret set --vault-name $KV_NAME --name reddog-sql --value "${REDDOG_SQL_CONNECTION_STRING}"
    echo 'KeyVault secret created: reddog-sql'

    # Redis
    # export REDIS_HOST=$(jq -r .redisHost.value ./outputs/$RG_NAME-bicep-outputs.json)
    # export REDIS_PORT=$(jq -r .redisSslPort.value ./outputs/$RG_NAME-bicep-outputs.json)
    # export REDIS_FQDN="${REDIS_HOST}:${REDIS_PORT}"
    # export REDIS_PASSWORD=$(jq -r .redisPassword.value ./outputs/$RG_NAME-bicep-outputs.json)

    # az keyvault secret set --vault-name $KV_NAME --name redis-server --value $REDIS_FQDN
    # echo "KeyVault secret created: redis-server"
    az keyvault secret set --vault-name $KV_NAME --name redis-password --value $REDIS_PASSWD
    echo 'KeyVault secret created: redis-password'

# Configure AKS Flux v2 GitOps - dependencies and apps
echo ''
echo '****************************************************'
echo 'Configure AKS Flux v2 GitOps - dependencies and apps'
echo '****************************************************'
export AKS_NAME=$(jq -r .aksName.value ./outputs/$RG_NAME-bicep-outputs.json)

#az connectedk8s connect -g $RG_NAME -n$AKS_NAME --distribution aks
#echo "AKS cluster Arc enabled"

echo ''
echo 'Configuring GitOps Red Dog dependencies deployment'

az k8s-configuration flux create \
    --resource-group $RG_NAME \
    --cluster-name $AKS_NAME \
    --cluster-type managedClusters \
    --scope cluster \
    --name $AKS_NAME-dep --namespace flux-system \
    --url https://github.com/Azure/reddog-aks.git \
    --branch main \
    --kustomization name=dependencies path=./manifests/dependencies prune=true  

# Azure SQL server must set firewall to allow azure services
export AZURE_SQL_SERVER=$(jq -r .sqlServerName.value ./outputs/$RG_NAME-bicep-outputs.json)
echo ''
echo 'Allow Azure Services to access Azure SQL (Firewall)'
az sql server firewall-rule create \
    --resource-group $RG_NAME \
    --server $AZURE_SQL_SERVER \
    --name AllowAzureServices \
    --start-ip-address 0.0.0.0 \
    --end-ip-address 0.0.0.0

# Zipkin
echo ''
echo 'Installing Zipkin for Dapr'
kubectl create ns zipkin
kubectl create deployment zipkin -n zipkin --image openzipkin/zipkin
kubectl expose deployment zipkin -n zipkin --type LoadBalancer --port 9411   

# Wait for dapr to start
echo ''
echo 'waiting 60 seconds for Dapr to fully start'
sleep 60

echo ''
echo 'Configuring GitOps Red Dog apps deployment'

az k8s-configuration flux create \
    --resource-group $RG_NAME \
    --cluster-name $AKS_NAME \
    --cluster-type managedClusters \
    --scope cluster \
    --name $AKS_NAME-apps --namespace flux-system \
    --url https://github.com/Azure/reddog-aks.git \
    --branch main \
    --kustomization name=services path=./manifests/base prune=true  

# elapsed time with second resolution
end_time=$(date +%s)
elapsed=$(( end_time - start_time ))
eval "echo Script elapsed time: $(date -ud "@$elapsed" +'$((%s/3600/24)) days %H hours %M minutes %S seconds')"