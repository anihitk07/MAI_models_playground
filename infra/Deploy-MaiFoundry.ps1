[CmdletBinding()]
param(
    [string]$ResourceGroupName = "rg-mai-model-demo",
    [string]$ResourceGroupLocation = "eastus2",
    [string]$NamePrefix = "mai",
    [string]$FoundryLocation = "eastus",
    [string]$TranscribeSpeechLocation = "eastus",
    [string]$VoiceSpeechLocation = "swedencentral",
    [string]$EnvPath = (Join-Path $PSScriptRoot "..\.env"),
    [switch]$SkipImageDeployments
)

$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $true

function Require-Command {
    param([Parameter(Mandatory)][string]$CommandName)
    if (-not (Get-Command $CommandName -ErrorAction SilentlyContinue)) {
        throw "Required command '$CommandName' was not found in PATH."
    }
}

function Ensure-AzLogin {
    $accountJson = az account show --output json 2>$null
    if (-not $accountJson) {
        throw "Azure CLI is not authenticated. Run 'az login' and retry."
    }
}

function Select-PreferredSubscription {
    param(
        [Parameter(Mandatory)][string[]]$PreferredNames
    )

    $subscriptions = az account list --output json | ConvertFrom-Json
    if (-not $subscriptions) {
        throw "No Azure subscriptions available for the current identity."
    }

    foreach ($preferredName in $PreferredNames) {
        $candidate = $subscriptions | Where-Object { $_.name -eq $preferredName } | Select-Object -First 1
        if ($null -ne $candidate) {
            az account set --subscription $candidate.id | Out-Null
            return $candidate
        }
    }

    $defaultSub = $subscriptions | Where-Object { $_.isDefault -eq $true } | Select-Object -First 1
    if ($null -eq $defaultSub) {
        $defaultSub = $subscriptions | Select-Object -First 1
    }

    az account set --subscription $defaultSub.id | Out-Null
    return $defaultSub
}

function Ensure-ResourceProvider {
    param([Parameter(Mandatory)][string]$Namespace)

    $state = az provider show --namespace $Namespace --query registrationState --output tsv 2>$null
    if ($state -ne "Registered") {
        az provider register --namespace $Namespace --wait --output none
    }
}

function Resolve-CurrentPrincipalObjectId {
    try {
        $userId = az ad signed-in-user show --query id --output tsv 2>$null
        if ($userId) {
            return $userId
        }
    }
    catch {
    }

    try {
        $accountType = az account show --query user.type --output tsv
        $accountName = az account show --query user.name --output tsv
        if ($accountType -eq "servicePrincipal" -and $accountName) {
            $spObjectId = az ad sp show --id $accountName --query id --output tsv 2>$null
            if ($spObjectId) {
                return $spObjectId
            }
        }
    }
    catch {
    }

    return ""
}

function Try-GetCognitiveKey {
    param(
        [Parameter(Mandatory)][string]$ResourceGroupName,
        [Parameter(Mandatory)][string]$AccountName
    )

    try {
        return az cognitiveservices account keys list `
            --resource-group $ResourceGroupName `
            --name $AccountName `
            --query "key1" `
            --output tsv
    }
    catch {
        Write-Warning "Could not read keys for '$AccountName' (likely disableLocalAuth policy). Entra auth will be used."
        return ""
    }
}

Require-Command -CommandName "az"
Ensure-AzLogin

$selectedSubscription = Select-PreferredSubscription -PreferredNames @(
    "MCAPS-Hybrid-aganguly",
    "Microsoft AIRS"
)

Write-Host "Using subscription: $($selectedSubscription.name) ($($selectedSubscription.id))"

Ensure-ResourceProvider -Namespace "Microsoft.CognitiveServices"

$deployerPrincipalId = Resolve-CurrentPrincipalObjectId
if ($deployerPrincipalId) {
    Write-Host "Resolved principal object ID: $deployerPrincipalId"
}
else {
    Write-Warning "Could not resolve current principal object ID. RBAC role assignments in Bicep will be skipped."
}

az group create `
    --name $ResourceGroupName `
    --location $ResourceGroupLocation `
    --output none

$deploymentName = "mai-foundry-" + (Get-Date -Format "yyyyMMddHHmmss")

$outputsJson = az deployment group create `
    --name $deploymentName `
    --resource-group $ResourceGroupName `
    --template-file (Join-Path $PSScriptRoot "main.bicep") `
    --parameters namePrefix=$NamePrefix `
                 deployerPrincipalId=$deployerPrincipalId `
                 foundryLocation=$FoundryLocation `
                 transcribeSpeechLocation=$TranscribeSpeechLocation `
                 voiceSpeechLocation=$VoiceSpeechLocation `
                 deployImageModels=$([bool](-not $SkipImageDeployments.IsPresent)) `
    --query "properties.outputs" `
    --output json

if (-not $outputsJson) {
    throw "Deployment completed without outputs."
}

$outputs = $outputsJson | ConvertFrom-Json

$foundryAccountName = $outputs.foundryAccountName.value
$foundryEndpoint = $outputs.foundryEndpoint.value
$foundryProjectName = $outputs.foundryProjectName.value
$foundryProjectEndpoint = $outputs.foundryProjectEndpoint.value
$transcribeSpeechAccountName = $outputs.transcribeSpeechAccountName.value
$transcribeSpeechRegion = $outputs.transcribeSpeechRegion.value
$voiceSpeechAccountName = $outputs.voiceSpeechAccountName.value
$voiceSpeechRegion = $outputs.voiceSpeechRegion.value
$maiImage2Deployment = $outputs.maiImage2Deployment.value
$maiImage2eDeployment = $outputs.maiImage2eDeployment.value
$transcribeSpeechEndpoint = "https://$transcribeSpeechAccountName.cognitiveservices.azure.com/"
$voiceSpeechEndpoint = "https://$voiceSpeechAccountName.cognitiveservices.azure.com/"

$foundryApiKey = Try-GetCognitiveKey -ResourceGroupName $ResourceGroupName -AccountName $foundryAccountName
$transcribeSpeechKey = Try-GetCognitiveKey -ResourceGroupName $ResourceGroupName -AccountName $transcribeSpeechAccountName
$voiceSpeechKey = Try-GetCognitiveKey -ResourceGroupName $ResourceGroupName -AccountName $voiceSpeechAccountName
$useEntraAuth = [bool]([string]::IsNullOrWhiteSpace($foundryApiKey) -or [string]::IsNullOrWhiteSpace($transcribeSpeechKey) -or [string]::IsNullOrWhiteSpace($voiceSpeechKey))

$normalizedFoundryEndpoint = if ($foundryEndpoint.EndsWith("/")) { $foundryEndpoint } else { "$foundryEndpoint/" }

$envContent = @"
# Auto-generated by infra/Deploy-MaiFoundry.ps1
# Subscription: $($selectedSubscription.name) ($($selectedSubscription.id))
# Resource group: $ResourceGroupName
# Deployment: $deploymentName

TRANSCRIBE_SPEECH_KEY=$transcribeSpeechKey
TRANSCRIBE_SPEECH_REGION=$transcribeSpeechRegion
TRANSCRIBE_SPEECH_ENDPOINT=$transcribeSpeechEndpoint
TRANSCRIBE_LOCAL_AUDIO_DIR=C:\Flutter\azure-transcription\demodata

VOICE_SPEECH_KEY=$voiceSpeechKey
VOICE_SPEECH_REGION=$voiceSpeechRegion
VOICE_SPEECH_ENDPOINT=$voiceSpeechEndpoint
MAI_VOICE_NAME=en-us-Grant:MAI-Voice-1

AZURE_FOUNDRY_ENDPOINT=$normalizedFoundryEndpoint
AZURE_FOUNDRY_API_KEY=$foundryApiKey
MAI_IMAGE_2_DEPLOYMENT_NAME=$maiImage2Deployment
MAI_IMAGE_2E_DEPLOYMENT_NAME=$maiImage2eDeployment

FOUNDRY_PROJECT_NAME=$foundryProjectName
FOUNDRY_PROJECT_ENDPOINT=$foundryProjectEndpoint
AZURE_SUBSCRIPTION_ID=$($selectedSubscription.id)
AZURE_RESOURCE_GROUP=$ResourceGroupName
AZURE_FOUNDRY_ACCOUNT=$foundryAccountName
TRANSCRIBE_SPEECH_ACCOUNT=$transcribeSpeechAccountName
VOICE_SPEECH_ACCOUNT=$voiceSpeechAccountName

USE_ENTRA_AUTH=$($useEntraAuth.ToString().ToLowerInvariant())
AZURE_TENANT_ID=
AZURE_CLIENT_ID=
AZURE_CLIENT_SECRET=
"@

$envDirectory = Split-Path -Path $EnvPath -Parent
if ($envDirectory -and -not (Test-Path $envDirectory)) {
    New-Item -Path $envDirectory -ItemType Directory -Force | Out-Null
}

Set-Content -Path $EnvPath -Value $envContent -Encoding UTF8

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$deploymentEnvPath = Join-Path $projectRoot "deployment.env"
Set-Content -Path $deploymentEnvPath -Value $envContent -Encoding UTF8

$legacyDeploymentEnvPath = Join-Path $PSScriptRoot "deployment.env"
if (Test-Path $legacyDeploymentEnvPath) {
    Remove-Item -Path $legacyDeploymentEnvPath -Force
}

Write-Host "Deployment complete."
Write-Host "Foundry account: $foundryAccountName"
Write-Host "Foundry project: $foundryProjectName"
Write-Host "Transcribe Speech account: $transcribeSpeechAccountName"
Write-Host "Voice Speech account: $voiceSpeechAccountName"
Write-Host "Environment file written: $EnvPath"
Write-Host "Deployment environment snapshot: $deploymentEnvPath"
