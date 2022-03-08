param name string
param adminUsername string
param adminPublicKey string
param nodeCount int = 5
param vmSize string = 'Standard_D4_v3'

resource aks 'Microsoft.ContainerService/managedClusters@2021-05-01' = {
  name: name
  location: resourceGroup().location  
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    dnsPrefix: name
    linuxProfile: {
      adminUsername: adminUsername
      ssh: {
        publicKeys: [
          {
            keyData: adminPublicKey
          }
        ]
      }
    }    
    enableRBAC: true
    agentPoolProfiles: [
      {
        name: 'agentpool1'
        count: nodeCount
        vmSize: vmSize
        //osDiskSizeGB: 30
        //osDiskType: 'Ephemeral'
        osType: 'Linux'
        mode: 'System'
      }
    ]
  }
}

output name string = aks.name
