## Notes

```bash

az k8s-configuration flux create \
    --resource-group briar-reddog-aks-14921 \
    --cluster-name briar-reddog-aks-14921 \
    --cluster-type connectedClusters \
    --scope cluster \
    --name briar-reddog-aks-14921-dependencies --namespace flux-system \
    --url https://github.com/Azure/reddog-aks.git \
    --branch main \
    --kustomization name=dependencies path=./manifests/dependencies prune=true  

az k8s-configuration flux create \
    --resource-group briar-reddog-aks-4845 \
    --cluster-name briar-reddog-aks-4845 \
    --cluster-type connectedClusters \
    --scope cluster \
    --name briar-reddog-aks-4845 --namespace flux-system \
    --url https://github.com/Azure/reddog-aks.git \
    --branch main \
    --kustomization name=services path=./manifests/base prune=true  

az k8s-configuration flux list --resource-group briar-reddog-aks-14921 --cluster-name briar-reddog-aks-14921 --cluster-type connectedClusters

az k8s-configuration flux show --name briar-reddog-aks-14921-dependencies \
    --resource-group briar-reddog-aks-14921 \
    --cluster-name briar-reddog-aks-14921 \
    --cluster-type connectedClusters -o json

az k8s-configuration flux delete --name briar-reddog-aks-14921-dependencies \
    --resource-group briar-reddog-aks-14921 \
    --cluster-name briar-reddog-aks-14921 \
    --cluster-type connectedClusters




```