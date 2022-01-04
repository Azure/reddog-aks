export LOCATION="eastus"

ssh-keygen -f ~/.ssh/aks-reddog -N '' <<< y  

SSH_PUB_KEY="$(cat ~/.ssh/aks-reddog.pub)"
export SSH_PUB_KEY

az deployment sub create \
  -f ./deploy/bicep/main.bicep \
  -l $LOCATION \
  -n aks-reddog \
  --parameters prefix="briar" \
  --parameters adminPublicKey="$SSH_PUB_KEY"
