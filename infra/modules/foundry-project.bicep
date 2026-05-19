targetScope = 'resourceGroup'

@description('Name of the Foundry account that will host this project.')
param accountName string

@description('Foundry project name.')
param projectName string

@description('Azure region for the project.')
param location string

@description('Display name shown in Foundry.')
param displayName string = 'MAI Models Project'

@description('Project description.')
param projectDescription string = 'Project for MAI model demos.'

resource account 'Microsoft.CognitiveServices/accounts@2025-04-01-preview' existing = {
  name: accountName
}

resource project 'Microsoft.CognitiveServices/accounts/projects@2025-04-01-preview' = {
  parent: account
  name: projectName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    displayName: displayName
    description: projectDescription
  }
}

output projectName string = project.name
output projectManagedIdentityPrincipalId string = project.identity.principalId
output projectEndpoint string = 'https://${accountName}.services.ai.azure.com/api/projects/${project.name}'
