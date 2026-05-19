targetScope = 'resourceGroup'

@description('Name of the Foundry account hosting the deployment.')
param accountName string

@description('Deployment name.')
param deploymentName string

@description('Model name from catalog.')
param modelName string

@description('Model format (for example: OpenAI).')
param modelFormat string = 'OpenAI'

@description('Optional model version from catalog.')
param modelVersion string = ''

@description('Deployment SKU.')
param skuName string = 'GlobalStandard'

@description('SKU capacity for deployment.')
@minValue(1)
param capacity int = 1

resource account 'Microsoft.CognitiveServices/accounts@2025-04-01-preview' existing = {
  name: accountName
}

resource deployment 'Microsoft.CognitiveServices/accounts/deployments@2025-04-01-preview' = {
  parent: account
  name: deploymentName
  sku: {
    name: skuName
    capacity: capacity
  }
  properties: {
    model: empty(modelVersion)
      ? {
          format: modelFormat
          name: modelName
        }
      : {
          format: modelFormat
          name: modelName
          version: modelVersion
        }
  }
}

output deploymentName string = deployment.name
