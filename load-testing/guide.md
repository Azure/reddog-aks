## Cloud Native Resiliency Workshop

#### Monitoring

> Grafana login: admin/admin (password must change)

#### Load Testing

ui: http://reddog19188.eastus.cloudapp.azure.com

order:
http://reddog19188.eastus.cloudapp.azure.com/order
http://reddog19188.eastus.cloudapp.azure.com/product

makeline:
http://reddog19188.eastus.cloudapp.azure.com/orders/denver

accounting:
http://reddog19188.eastus.cloudapp.azure.com/ordermetrics?StoreId=denver
http://reddog19188.eastus.cloudapp.azure.com/corp/Stores
http://reddog19188.eastus.cloudapp.azure.com/corp/SalesProfit/Total
http://reddog19188.eastus.cloudapp.azure.com/corp/SalesProfit/PerStore

```bash

# AKS
export AKSNAME=reddog-aks-19188
az aks get-credentials -g $AKSNAME -n $AKSNAME

# manual tests
curl -i http://reddog19188.eastus.cloudapp.azure.com/order -X POST -H 'Content-Type: application/json' -d '{
    "storeId": "Denver", "firstName": "Michael", "lastName": "Jordan","loyaltyId": "2323",
    "orderItems": [{"productId": 23,"quantity": 10},{"productId": 123,"quantity": 20},{"productId": 223,"quantity": 30}]}'

while true; do curl -i http://reddog19188.eastus.cloudapp.azure.com/corp/Stores && echo '' ; sleep 2; done

while true; do curl -i http://reddog19188.eastus.cloudapp.azure.com/order -X POST -H 'Content-Type: application/json' -d '{
  "storeId": "Denver", "firstName": "Brian", "lastName": "Redmond","loyaltyId": "999",
  "orderItems": [{"productId": 23,"quantity": 10},{"productId": 123,"quantity": 20},{"productId": 223,"quantity": 30}]}' && echo '' ; sleep 1; done

kubectl run -i --tty load-generator -n reddog --rm --image=busybox --restart=Never -- /bin/sh -c "while sleep 1; do wget -q -O- http://reddog19188.eastus.cloudapp.azure.com/ordermetrics?StoreId=denver; done"

# jmeter
/Users/brianredmond/source/apache-jmeter-5.4.3/bin/jmeter

/Users/brianredmond/source/apache-jmeter-5.4.3/bin/jmeter -n -t ./load-testing/load-test-jmeter.jmx -l ./load-testing/results.txt -e -o ./load-testing/output

# hpa
kubectl autoscale deployment order-service -n reddog --cpu-percent=10 --min=1 --max=10

kubectl scale deployment order-service --replicas=1

```

#### KEDA

```bash
helm repo add kedacore https://kedacore.github.io/charts
helm repo update

kubectl create namespace keda
helm install keda kedacore/keda --namespace keda

kubectl apply -f ./load-testing/keda-scaler-order.yaml

```