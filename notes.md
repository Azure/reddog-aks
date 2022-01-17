## Notes

```bash

# service principal cleanup
az ad sp list --show-mine -o table

az ad sp list --show-mine -o json --query "[?contains(displayName, 'azure-cli')]"

az ad sp list --show-mine -o json --query "[?contains(displayName, 'reddog')]" | jq -r '.[] | .appId' | xargs -P 4 -n 12 -I % az ad sp delete --id %

# testing
export AKSNAME=briar-reddog-aks-10869
az aks get-credentials -g $AKSNAME -n $AKSNAME

kubectl get service/reddog-branch-ui -n reddog -o jsonpath='{.status.loadBalancer.ingress.ip}'

# flux v2
az k8s-configuration flux create \
    --resource-group $AKSNAME \
    --cluster-name $AKSNAME \
    --cluster-type managedClusters \
    --scope cluster \
    --name $AKSNAME-dep --namespace flux-system \
    --url https://github.com/Azure/reddog-aks.git \
    --branch main \
    --kustomization name=dependencies path=./manifests/dependencies prune=true 

az k8s-configuration flux create \
    --resource-group $AKSNAME \
    --cluster-name $AKSNAME \
    --cluster-type managedClusters \
    --scope cluster \
    --name $AKSNAME-apps --namespace flux-system \
    --url https://github.com/Azure/reddog-aks.git \
    --branch main \
    --kustomization name=services path=./manifests/base prune=true  

az k8s-configuration flux list --resource-group $AKSNAME \
    --cluster-name $AKSNAME --cluster-type managedClusters

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

#### Traefik

https://github.com/traefik/traefik-helm-chart

helm repo add traefik https://helm.traefik.io/traefik
helm repo update 

kubectl create ns traefik

helm install traefik traefik/traefik --namespace traefik --set pilot.enabled=true

helm install traefik traefik/traefik --namespace traefik --set deployment.annotations[0].service.beta.kubernetes.io/azure-dns-label-name=reddog

helm install traefik traefik/traefik --namespace traefik --set deployment.annotations."service\.beta\.kubernetes\.io/azure-dns-label-name"=reddog

helm install traefik traefik/traefik --namespace traefik --set deployment.podAnnotations."service\.beta\.kubernetes\.io/azure-dns-label-name"=reddog

helm install ingress-nginx ingress-nginx/ingress-nginx -n dapr-workshop --set controller.service.annotations."service\.beta\.kubernetes\.io/azure-dns-label-name"=$UNIQUE_SUFFIX 

helm uninstall traefik -n traefik


helm install stable/nginx-ingress --set controller.service.annotations."cloud\.google\.com\/load-balancer\-type"=Internal



kubectl get pods --selector "app.kubernetes.io/name=traefik" --output=name -n traefik

kubectl port-forward -n traefik $(kubectl get pods -n traefik --selector "app.kubernetes.io/name=traefik" --output=name) 9000:9000

http://localhost:9000/dashboard/#/

http://brianredmond.io/dashboard/#/

http://reddog-ui.brianredmond.io




#### DNS


Name:                     traefik
Namespace:                traefik
Labels:                   app.kubernetes.io/instance=traefik
                          app.kubernetes.io/managed-by=Helm
                          app.kubernetes.io/name=traefik
                          helm.sh/chart=traefik-10.9.1
Annotations:              meta.helm.sh/release-name: traefik
                          meta.helm.sh/release-namespace: traefik
                          service.beta.kubernetes.io/azure-dns-label-name: reddog

https://github.com/Azure/AKS/issues/611

https://docs.microsoft.com/en-us/azure/aks/static-ip#apply-a-dns-label-to-the-service

                         