export LOCATION="eastus"
export PREFIX="briar1234"

echo '****************************************************'
echo "Starting Red Dog on AKS deployment"
echo '****************************************************'

export RG_NAME=$PREFIX-reddog-aks-$LOCATION
echo "RG Name: " $RG_NAME

# create RG
echo "Creating Azure Resource Group"
az group create --name $RG_NAME --location $LOCATION

# create SSH keys
ssh-keygen -f ~/.ssh/aks-reddog -N '' <<< y  

export SSH_PUB_KEY="$(cat ~/.ssh/aks-reddog.pub)"
echo "SSH keys generated (will overwrite existing)"

# get current user
export CURRENT_USER_ID=$(az ad signed-in-user show -o json | jq -r .objectId)
echo "Current user: " $CURRENT_USER_ID

# Bicep deployment
echo "Starting Bicep deployment of resources"
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
az deployment group show -g $RG_NAME -n aks-reddog -o json --query properties.outputs | tee "./outputs/$RG_NAME-bicep-outputs.json"

# Initialize KV 
export KV_NAME=$(cat ./outputs/$RG_NAME-bicep-outputs.json | jq -r .keyvaultName.value)
echo "Key Vault: $KV_NAME"
echo "Create SP for KV use..."
