targetScope = 'subscription'

// Naming convention requirements
param prefix string
var name = '${prefix}-aksredddog'

param location string = deployment().location
param uniqueSeed string = '${subscription().subscriptionId}-${deployment().name}'
param resourceGroupName string = '${prefix}-${uniqueString(uniqueSeed)}'
param serviceBusNamespaceName string = resourceGroupName
param redisName string = resourceGroupName
param cosmosAccountName string = resourceGroupName
param cosmosDatabaseName string = 'reddog'
param cosmosCollectionName string = 'loyalty'
param storageAccountName string = replace(resourceGroupName, '-', '')
param blobContainerName string = 'receipts'
param sqlServerName string = resourceGroupName
param sqlDatabaseName string = 'reddog'
param sqlAdminLogin string = 'reddog'
param sqlAdminLoginPassword string = 'w@lkingth3d0g'
param adminUsername string = 'azureuser'
param adminPublicKey string

module resourceGroupModule 'modules/resource-group.bicep' = {
  name: '${deployment().name}--resourceGroup'
  scope: subscription()
  params: {
    location: location
    resourceGroupName: resourceGroupName
  }
}

module aks 'modules/aks.bicep' = {
  name: 'aks-deployment'
  scope: resourceGroup(resourceGroupName)
  params: {
    clusterName: name
    location: location
    dnsPrefix: name
    linuxAdminUsername: adminUsername
    sshRSAPublicKey: adminPublicKey
  }  
}

// module serviceBusModule 'modules/servicebus.bicep' = {
//   name: '${deployment().name}--servicebus'
//   scope: resourceGroup(resourceGroupName)
//   dependsOn: [
//     resourceGroupModule
//   ]
//   params: {
//     serviceBusNamespaceName: serviceBusNamespaceName
//     location: location
//   }
// }

// module redisModule 'modules/redis.bicep' = {
//   name: '${deployment().name}--redis'
//   scope: resourceGroup(resourceGroupName)
//   dependsOn: [
//     resourceGroupModule
//   ]
//   params: {
//     redisName: redisName
//     location: location
//   }
// }

// module cosmosModule 'modules/cosmos.bicep' = {
//   name: '${deployment().name}--cosmos'
//   scope: resourceGroup(resourceGroupName)
//   dependsOn: [
//     resourceGroupModule
//   ]
//   params: {
//     cosmosAccountName: cosmosAccountName
//     cosmosDatabaseName: cosmosDatabaseName
//     cosmosCollectionName: cosmosCollectionName
//     location: location
//   }
// }

// module storageModule 'modules/storage.bicep' = {
//   name: '${deployment().name}--storage'
//   scope: resourceGroup(resourceGroupName)
//   dependsOn: [
//     resourceGroupModule
//   ]
//   params: {
//     storageAccountName: storageAccountName
//     blobContainerName: blobContainerName
//     location: location
//   }
// }

// module sqlServerModule 'modules/sqlserver.bicep' = {
//   name: '${deployment().name}--sqlserver'
//   scope: resourceGroup(resourceGroupName)
//   dependsOn: [
//     resourceGroupModule
//   ]
//   params: {
//     sqlServerName: sqlServerName
//     sqlDatabaseName: sqlDatabaseName
//     sqlAdminLogin: sqlAdminLogin
//     sqlAdminLoginPassword: sqlAdminLoginPassword
//     location: location
//   }
// }
