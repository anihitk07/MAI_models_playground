targetScope = 'resourceGroup'

@description('Name of the Azure Speech resource.')
param accountName string

@description('Azure region for the Speech resource.')
param location string

@description('Optional principal object ID to receive Cognitive Services Speech User and Cognitive Services User roles on this account.')
param deployerPrincipalId string = ''

@description('Public network access mode.')
@allowed([
  'Enabled'
  'Disabled'
])
param publicNetworkAccess string = 'Enabled'

resource speechAccount 'Microsoft.CognitiveServices/accounts@2025-04-01-preview' = {
  name: accountName
  location: location
  kind: 'SpeechServices'
  sku: {
    name: 'S0'
  }
  properties: {
    customSubDomainName: accountName
    publicNetworkAccess: publicNetworkAccess
  }
}

resource speechUserRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(deployerPrincipalId)) {
  name: guid(speechAccount.id, deployerPrincipalId, 'SpeechUser')
  scope: speechAccount
  properties: {
    principalId: deployerPrincipalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'f2dc8367-1007-4938-bd23-fe263f013447')
  }
}

resource cognitiveUserRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(deployerPrincipalId)) {
  name: guid(speechAccount.id, deployerPrincipalId, 'CognitiveServicesUser')
  scope: speechAccount
  properties: {
    principalId: deployerPrincipalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'a97b65f3-24c7-4388-baec-2e87135dc908')
  }
}

output accountName string = speechAccount.name
output endpoint string = speechAccount.properties.endpoint
output location string = speechAccount.location
