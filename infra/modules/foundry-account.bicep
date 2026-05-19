targetScope = 'resourceGroup'

@description('Name of the Azure AI Foundry account (AIServices).')
param accountName string

@description('Azure region for the Foundry account.')
param location string

@description('Whether project creation is allowed for this account.')
param allowProjectManagement bool = true

@description('Optional principal object ID to receive Cognitive Services User role on this account.')
param deployerPrincipalId string = ''

@description('Public network access mode.')
@allowed([
  'Enabled'
  'Disabled'
])
param publicNetworkAccess string = 'Enabled'

resource account 'Microsoft.CognitiveServices/accounts@2025-04-01-preview' = {
  name: accountName
  location: location
  kind: 'AIServices'
  sku: {
    name: 'S0'
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    customSubDomainName: accountName
    allowProjectManagement: allowProjectManagement
    publicNetworkAccess: publicNetworkAccess
  }
}

resource foundryCognitiveServicesUserRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(deployerPrincipalId)) {
  name: guid(account.id, deployerPrincipalId, 'CognitiveServicesUser')
  scope: account
  properties: {
    principalId: deployerPrincipalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'a97b65f3-24c7-4388-baec-2e87135dc908')
  }
}

output accountId string = account.id
output accountName string = account.name
output endpoint string = account.properties.endpoint
