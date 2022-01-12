## Notes

```bash

# service principal cleanup
az ad sp list --show-mine -o table

az ad sp list --show-mine -o json --query "[?contains(displayName, 'azure-cli')]"

az ad sp list --show-mine -o json --query "[?contains(displayName, 'reddog')]" | jq -r '.[] | .appId' | xargs -P 4 -n 12 -I % az ad sp delete --id %

# flux v2
export AKSNAME=briar-reddog-aks-6015

az k8s-configuration flux create \
    --resource-group $AKSNAME \
    --cluster-name $AKSNAME \
    --cluster-type connectedClusters \
    --scope cluster \
    --name $AKSNAME-apps --namespace flux-system \
    --url https://github.com/Azure/reddog-aks.git \
    --branch main \
    --kustomization name=services path=./manifests/base prune=true  

az k8s-configuration flux list --resource-group $AKSNAME \
    --cluster-name $AKSNAME --cluster-type connectedClusters

az k8s-configuration flux show --name $AKSNAME \
    --resource-group $AKSNAME \
    --cluster-name $AKSNAME \
    --cluster-type connectedClusters -o json

az k8s-configuration flux delete --name $AKSNAME-apps \
    --resource-group $AKSNAME \
    --cluster-name $AKSNAME \
    --yes \
    --cluster-type connectedClusters

# Create K8s secret for above pfx (used by Dapr)
kubectl create secret generic reddog.secretstore \
    --namespace reddog \
    --from-file=secretstore-cert=./kv-$RG_NAME-cert.pfx \
    --from-literal=vaultName=$KV_NAME \
    --from-literal=spnClientId=$SP_APPID \
    --from-literal=spnTenantId=$TENANT_ID

kubectl create secret generic reddog.secretstore \
    --namespace reddog \
    --from-file=secretstore-cert=./kv-briar-reddog-aks-6015-cert.pfx \
    --from-literal=vaultName='briar-reddog-kv-no3e' \
    --from-literal=spnClientId='3abc5ac9-afd4-4115-a9a5-44c6603217fa' \
    --from-literal=spnTenantId='72f988bf-86f1-41af-91ab-2d7cd011db47'



```