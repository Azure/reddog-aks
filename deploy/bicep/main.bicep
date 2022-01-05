// Naming convention requirements
param prefix string

// Network Settings
param vnetPrefix string = '10.0.0.0/16'
param aksSubnetInfo object = {
  name: 'AksSubnet'
  properties: { 
    addressPrefix: '10.0.4.0/22'
    privateEndpointNetworkPolicies: 'Disabled'
  }
}
param jumpboxSubnetInfo object = {
  name: 'JumpboxSubnet'
  properties: {
    addressPrefix: '10.0.255.240/28'
  }
}

// Linux Config
param adminUsername string = 'azureuser'
param adminPublicKey string

// Additional Params
param serviceBusNamespaceName string = resourceGroup().name
param redisName string = resourceGroup().name
param cosmosAccountName string = resourceGroup().name
param cosmosDatabaseName string = 'reddog'
param cosmosCollectionName string = 'loyalty'
param storageAccountName string = replace(resourceGroup().name, '-', '')
param blobContainerName string = 'receipts'
param sqlServerName string = resourceGroup().name
param sqlDatabaseName string = 'reddog'
param sqlAdminLogin string = 'reddog'
param sqlAdminLoginPassword string = 'w@lkingth3d0g'
param currentUserId string

var name = '${prefix}-reddog'

//
// Top Level Resources
//

resource vnet 'Microsoft.Network/virtualNetworks@2020-08-01' = {
  name: '${prefix}-hub-vnet'
  location: resourceGroup().location
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetPrefix
      ]
    }
    subnets: [
      aksSubnetInfo
      jumpboxSubnetInfo
    ]
  } 
}

module keyvault 'modules/keyvault.bicep' = {
  name: 'keyvault'
  params: {
    prefix: name
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

module aks 'modules/aks.bicep' = {
  name: 'aks-deployment'
  params: {
    name: format('{0}-aks',name)
    adminUsername: adminUsername
    adminPublicKey: adminPublicKey
    subnetId: '${vnet.id}/subnets/${aksSubnetInfo.name}'
  }
  
}

module serviceBus 'modules/servicebus.bicep' = {
  name: '${deployment().name}--servicebus'
  params: {
    serviceBusNamespaceName: serviceBusNamespaceName
    location: resourceGroup().location
  }
}

module redis 'modules/redis.bicep' = {
  name: '${deployment().name}--redis'
  params: {
    redisName: redisName
    location: resourceGroup().location
  }
}

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
output redisHost string = redis.outputs.redisHost
output redisSslPort int = redis.outputs.redisSslPort
output redisPassword string = redis.outputs.redisPassword
