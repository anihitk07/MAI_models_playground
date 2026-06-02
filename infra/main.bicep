targetScope = 'resourceGroup'

@description('Resource naming prefix (letters and numbers).')
@minLength(2)
@maxLength(10)
param namePrefix string = 'mai'

@description('Optional principal object ID to grant data-plane access roles on the Foundry account (voice/transcribe/image).')
param deployerPrincipalId string = ''

@description('Foundry account location.')
param foundryLocation string = 'eastus'

@description('Optional explicit Foundry account name. Leave empty to auto-generate.')
param foundryAccountName string = ''

@description('Optional explicit Foundry project name. Leave empty to auto-generate.')
param foundryProjectName string = ''

@description('Deploy MAI image model deployments on Foundry account.')
param deployImageModels bool = true

@description('Image model deployment name for MAI-Image-2.')
param maiImage2DeploymentName string = 'mai-image-2'

@description('Image model deployment name for MAI-Image-2e.')
param maiImage2eDeploymentName string = 'mai-image-2e'

@description('Model format used for MAI image deployments.')
param imageModelFormat string = 'Microsoft'

@description('Model catalog name for MAI-Image-2.')
param maiImage2ModelName string = 'MAI-Image-2'

@description('Model catalog name for MAI-Image-2e.')
param maiImage2eModelName string = 'MAI-Image-2e'

@description('Optional model version for MAI-Image-2.')
param maiImage2ModelVersion string = '2026-02-20'

@description('Optional model version for MAI-Image-2e.')
param maiImage2eModelVersion string = '2026-04-09'

@description('Deployment SKU for MAI-Image-2.')
param maiImage2SkuName string = 'GlobalStandard'

@description('Deployment SKU for MAI-Image-2e.')
param maiImage2eSkuName string = 'GlobalStandard'

@description('Capacity for MAI-Image-2 deployment.')
@minValue(1)
@maxValue(15)
param maiImage2Capacity int = 15

@description('Capacity for MAI-Image-2e deployment.')
@minValue(1)
@maxValue(30)
param maiImage2eCapacity int = 30

var prefix = toLower(replace(namePrefix, '-', ''))
var suffix = substring(uniqueString(subscription().subscriptionId, resourceGroup().id), 0, 6)
var resolvedFoundryAccountName = empty(foundryAccountName) ? 'aif${prefix}${suffix}' : toLower(foundryAccountName)
var resolvedFoundryProjectName = empty(foundryProjectName) ? 'mai-project-${suffix}' : toLower(foundryProjectName)

module foundryAccount './modules/foundry-account.bicep' = {
  name: 'foundryAccount'
  params: {
    accountName: resolvedFoundryAccountName
    location: foundryLocation
    deployerPrincipalId: deployerPrincipalId
  }
}

module foundryProject './modules/foundry-project.bicep' = {
  name: 'foundryProject'
  params: {
    accountName: foundryAccount.outputs.accountName
    projectName: resolvedFoundryProjectName
    location: foundryLocation
    displayName: 'MAI Models Project'
    projectDescription: 'Project used for MAI Image, Voice, and Transcribe demos.'
  }
}

module image2Deployment './modules/model-deployment.bicep' = if (deployImageModels) {
  name: 'image2Deployment'
  params: {
    accountName: foundryAccount.outputs.accountName
    deploymentName: maiImage2DeploymentName
    modelName: maiImage2ModelName
    modelFormat: imageModelFormat
    modelVersion: maiImage2ModelVersion
    skuName: maiImage2SkuName
    capacity: maiImage2Capacity
  }
}

module image2eDeployment './modules/model-deployment.bicep' = if (deployImageModels) {
  name: 'image2eDeployment'
  params: {
    accountName: foundryAccount.outputs.accountName
    deploymentName: maiImage2eDeploymentName
    modelName: maiImage2eModelName
    modelFormat: imageModelFormat
    modelVersion: maiImage2eModelVersion
    skuName: maiImage2eSkuName
    capacity: maiImage2eCapacity
  }
  dependsOn: [
    image2Deployment
  ]
}

output foundryAccountName string = foundryAccount.outputs.accountName
output foundryAccountId string = foundryAccount.outputs.accountId
output foundryEndpoint string = foundryAccount.outputs.endpoint
output foundryProjectName string = foundryProject.outputs.projectName
output foundryProjectEndpoint string = foundryProject.outputs.projectEndpoint
output maiImage2Deployment string = deployImageModels ? image2Deployment!.outputs.deploymentName : ''
output maiImage2eDeployment string = deployImageModels ? image2eDeployment!.outputs.deploymentName : ''
