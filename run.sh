export LOCATION="eastus"

ssh-keygen -f ~/.ssh/aks-reddog -N '' <<< y  

az deployment sub create \
  -f ./deploy/bicep/main.bicep \
  -l $LOCATION \
  -n aks-reddog \
  --parameters prefix="briar" \
  --parameters adminPublicKey="~/.ssh/aks-reddog.pub"
