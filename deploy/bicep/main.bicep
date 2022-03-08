// Params
param uniqueServiceName string
param serviceBusNamespaceName string = resourceGroup().name
// param redisName string = resourceGroup().name
param cosmosAccountName string = resourceGroup().name
param cosmosDatabaseName string = 'reddog'
param cosmosCollectionName string = 'reddogstate'
param storageAccountName string = replace(resourceGroup().name, '-', '')
param blobContainerName string = 'receipts'
param sqlServerName string = resourceGroup().name
param sqlDatabaseName string = 'reddog'
param sqlAdminLogin string = 'reddog'
param sqlAdminLoginPassword string = 'w@lkingth3d0g'
param currentUserId string
param adminUsername string = 'azureuser'
param adminPublicKey string

//
// Top Level Resources
//

module keyvault 'modules/keyvault.bicep' = {
  name: 'keyvault'
  params: {
    kvName: uniqueServiceName
    accessPolicies: [
      {
        objectId: currentUserId
        tenantId: subscription().tenantId
        permissions: {
          certificates: [
            'get'
            'create'
          ]
        }
      }
    ]
  }
}

module logAnalytics 'modules/loganalytics.bicep' = {
  name: 'logAnalyticsWorkspace'
  params: {
    name: uniqueServiceName
  }
}

module aks 'modules/aks.bicep' = {
  name: 'aks-deployment'
  params: {
    name: resourceGroup().name
    adminUsername: adminUsername
    adminPublicKey: adminPublicKey
    logAnalyticsID: logAnalytics.outputs.workspaceId
  }
  
}

module serviceBus 'modules/servicebus.bicep' = {
  name: '${deployment().name}--servicebus'
  params: {
    serviceBusNamespaceName: serviceBusNamespaceName
    location: resourceGroup().location
  }
}

// module redis 'modules/redis.bicep' = {
//   name: '${deployment().name}--redis'
//   params: {
//     redisName: redisName
//     location: resourceGroup().location
//   }
// }

module cosmos 'modules/cosmos.bicep' = {
  name: '${deployment().name}--cosmos'
  params: {
    cosmosAccountName: cosmosAccountName
    cosmosDatabaseName: cosmosDatabaseName
    cosmosCollectionName: cosmosCollectionName
    location: resourceGroup().location
  }
}

module storage 'modules/storage.bicep' = {
  name: '${deployment().name}--storage'
  params: {
    storageAccountName: storageAccountName
    blobContainerName: blobContainerName
    location: resourceGroup().location
  }
}

module sqlServer 'modules/sqlserver.bicep' = {
  name: '${deployment().name}--sqlserver'
  params: {
    sqlServerName: sqlServerName
    sqlDatabaseName: sqlDatabaseName
    sqlAdminLogin: sqlAdminLogin
    sqlAdminLoginPassword: sqlAdminLoginPassword
    location: resourceGroup().location
  }
}

// Outputs
output keyvaultName string = keyvault.outputs.name
output aksName string = aks.outputs.name
output sqlServerName string = sqlServer.outputs.sqlServerName
output sqlAdmin string = sqlServer.outputs.sqlAdmin
output sqlPassword string = sqlServer.outputs.sqlPassword
output cosmosUri string = cosmos.outputs.cosmosUri
output cosmosAccountName string = cosmos.outputs.cosmosAccountName
output serviceBusName string = serviceBus.outputs.sbName
output serviceBusConnectString string = serviceBus.outputs.rootConnectionString
output storageAccountName string = storage.outputs.storageAccountName
output storageAccountKey string = storage.outputs.accessKey
output workspaceId string = logAnalytics.outputs.workspaceId
// output redisHost string = redis.outputs.redisHost
// output redisSslPort int = redis.outputs.redisSslPort
// output redisPassword string = redis.outputs.redisPassword
