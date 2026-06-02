[CmdletBinding()]
param(
    [string]$SubscriptionId = "",
    [string]$ResourceGroupName = "rg-mai-model-demo",
    [string]$ResourceGroupLocation = "eastus2",
    [string]$Location = "",
    [string]$NamePrefix = "mai",
    [string]$DeploymentRunId = "",
    [string]$FoundryLocation = "eastus",
    [ValidateRange(1, 15)]
    [int]$MaiImage2Capacity = 15,
    [ValidateRange(1, 30)]
    [int]$MaiImage2eCapacity = 30,
    [string]$EnvPath = (Join-Path $PSScriptRoot "..\.env"),
    [switch]$SkipImageDeployments,
    [switch]$NoUniqueNaming,
    [switch]$Destroy
)

$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $true

if (-not [string]::IsNullOrWhiteSpace($Location)) {
    $ResourceGroupLocation = $Location
    $FoundryLocation = $Location
}

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

function Resolve-SelectedSubscription {
    param([string]$SubscriptionId)

    if (-not [string]::IsNullOrWhiteSpace($SubscriptionId)) {
        az account set --subscription $SubscriptionId --output none
    }

    $current = az account show --output json | ConvertFrom-Json
    if (-not $current) {
        throw "Could not resolve active Azure subscription. Run 'az account show' and retry."
    }

    return $current
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

function Get-SafeNamePrefix {
    param(
        [Parameter(Mandatory)][string]$BasePrefix,
        [Parameter(Mandatory)][string]$RunId,
        [switch]$DisableUniqueNaming
    )

    $normalized = ($BasePrefix.ToLowerInvariant() -replace '[^a-z0-9]', '')
    if ([string]::IsNullOrWhiteSpace($normalized)) {
        throw "NamePrefix must contain at least one alphanumeric character after normalization."
    }

    if ($DisableUniqueNaming) {
        return $normalized.Substring(0, [Math]::Min(10, $normalized.Length))
    }

    $normalizedRunId = ($RunId.ToLowerInvariant() -replace '[^a-z0-9]', '')
    if ([string]::IsNullOrWhiteSpace($normalizedRunId)) {
        throw "DeploymentRunId must contain at least one alphanumeric character after normalization."
    }

    $suffix = $normalizedRunId.Substring(0, [Math]::Min(4, $normalizedRunId.Length))
    if ($suffix.Length -lt 4) {
        $suffix = $suffix.PadRight(4, '0')
    }

    $baseMax = 10 - $suffix.Length
    $base = $normalized.Substring(0, [Math]::Min($baseMax, $normalized.Length))
    return "$base$suffix"
}

function Get-DeletedCognitiveAccountsForResourceGroup {
    param(
        [Parameter(Mandatory)][string]$SubscriptionId,
        [Parameter(Mandatory)][string]$ResourceGroupName
    )

    $deletedJson = az cognitiveservices account list-deleted `
        --subscription $SubscriptionId `
        --output json

    if (-not $deletedJson) {
        return @()
    }

    $allDeleted = $deletedJson | ConvertFrom-Json
    $escapedRg = [regex]::Escape($ResourceGroupName)
    return @(
        $allDeleted | Where-Object {
            ($_.resourceGroup -and $_.resourceGroup -ieq $ResourceGroupName) -or
            ($_.id -match "/resourceGroups/$escapedRg/")
        }
    )
}

function Purge-DeletedCognitiveAccountsForResourceGroup {
    param(
        [Parameter(Mandatory)][string]$SubscriptionId,
        [Parameter(Mandatory)][string]$ResourceGroupName,
        [int]$MaxPasses = 8,
        [int]$DelaySeconds = 15,
        [switch]$ThrowOnRemaining
    )

    for ($pass = 1; $pass -le $MaxPasses; $pass++) {
        $deletedAccounts = Get-DeletedCognitiveAccountsForResourceGroup `
            -SubscriptionId $SubscriptionId `
            -ResourceGroupName $ResourceGroupName

        if (-not $deletedAccounts -or $deletedAccounts.Count -eq 0) {
            if ($pass -eq 1) {
                Write-Host "No soft-deleted Cognitive Services accounts found for resource group '$ResourceGroupName'."
            }
            return
        }

        Write-Host "Purge pass $pass/$MaxPasses for soft-deleted Cognitive Services accounts in '$ResourceGroupName'..."
        foreach ($account in $deletedAccounts) {
            try {
                Write-Host "  Purging deleted account '$($account.name)' in location '$($account.location)'..."
                az cognitiveservices account purge `
                    --subscription $SubscriptionId `
                    --resource-group $ResourceGroupName `
                    --name $account.name `
                    --location $account.location `
                    --output none
            }
            catch {
                Write-Warning "Failed to purge deleted account '$($account.name)': $($_.Exception.Message)"
            }
        }

        if ($pass -lt $MaxPasses) {
            Start-Sleep -Seconds $DelaySeconds
        }
    }

    $remaining = Get-DeletedCognitiveAccountsForResourceGroup `
        -SubscriptionId $SubscriptionId `
        -ResourceGroupName $ResourceGroupName

    if ($remaining.Count -gt 0) {
        $remainingNames = ($remaining | ForEach-Object { $_.name }) -join ", "
        $message = "Soft-deleted Cognitive Services accounts still remain for '$ResourceGroupName': $remainingNames"
        if ($ThrowOnRemaining) {
            throw $message
        }
        Write-Warning $message
    }
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

$selectedSubscription = Resolve-SelectedSubscription -SubscriptionId $SubscriptionId

Write-Host "Using subscription: $($selectedSubscription.name) ($($selectedSubscription.id))"

Ensure-ResourceProvider -Namespace "Microsoft.CognitiveServices"

if ($Destroy) {
    Write-Host "Destroy mode enabled for resource group '$ResourceGroupName'."
    $groupExists = az group exists --subscription $selectedSubscription.id --name $ResourceGroupName
    if ($groupExists -eq "true") {
        Write-Host "Deleting resource group '$ResourceGroupName'..."
        az group delete `
            --subscription $selectedSubscription.id `
            --name $ResourceGroupName `
            --yes `
            --no-wait `
            --output none

        $maxPolls = 120
        for ($i = 1; $i -le $maxPolls; $i++) {
            Start-Sleep -Seconds 15
            $stillExists = az group exists --subscription $selectedSubscription.id --name $ResourceGroupName
            if ($stillExists -eq "false") {
                Write-Host "Resource group '$ResourceGroupName' deleted."
                break
            }
            if ($i -eq $maxPolls) {
                throw "Timed out waiting for resource group '$ResourceGroupName' deletion."
            }
        }
    }
    else {
        Write-Host "Resource group '$ResourceGroupName' does not exist. Continuing to purge soft-deleted accounts."
    }

    Purge-DeletedCognitiveAccountsForResourceGroup `
        -SubscriptionId $selectedSubscription.id `
        -ResourceGroupName $ResourceGroupName `
        -MaxPasses 12 `
        -DelaySeconds 15 `
        -ThrowOnRemaining

    Write-Host "Destroy completed for '$ResourceGroupName'."
    return
}

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
    --subscription $selectedSubscription.id `
    --output none

$autoRunId = [Guid]::NewGuid().ToString("N").Substring(0, 6)
$runId = if ([string]::IsNullOrWhiteSpace($DeploymentRunId)) { $autoRunId } else { $DeploymentRunId }
$effectiveNamePrefix = Get-SafeNamePrefix -BasePrefix $NamePrefix -RunId $runId -DisableUniqueNaming:$NoUniqueNaming
Write-Host "Using deployment run ID: $runId"
Write-Host "Using namePrefix for this run: $effectiveNamePrefix"

if ($NoUniqueNaming) {
    Write-Host "NoUniqueNaming is enabled. Running strict pre-deployment purge for '$ResourceGroupName'..."
    Purge-DeletedCognitiveAccountsForResourceGroup `
        -SubscriptionId $selectedSubscription.id `
        -ResourceGroupName $ResourceGroupName `
        -MaxPasses 12 `
        -DelaySeconds 15 `
        -ThrowOnRemaining
}
else {
    Write-Host "Unique naming enabled. Pre-deployment purge is skipped."
}

$deploymentName = "mai-foundry-" + (Get-Date -Format "yyyyMMddHHmmss") + "-$($runId.Substring(0, [Math]::Min(4, $runId.Length)))"

$maxDeploymentAttempts = 3
$outputsJson = $null
$lastDeploymentError = $null
$finalDeploymentName = $deploymentName

for ($attempt = 1; $attempt -le $maxDeploymentAttempts; $attempt++) {
    $attemptDeploymentName = if ($attempt -eq 1) { $deploymentName } else { "$deploymentName-r$attempt" }
    Write-Host "Starting ARM deployment (attempt $attempt/$maxDeploymentAttempts): $attemptDeploymentName"

    try {
        $outputsJson = az deployment group create `
            --name $attemptDeploymentName `
            --subscription $selectedSubscription.id `
            --resource-group $ResourceGroupName `
            --template-file (Join-Path $PSScriptRoot "main.bicep") `
            --parameters namePrefix=$effectiveNamePrefix `
                         deployerPrincipalId=$deployerPrincipalId `
                         foundryLocation=$FoundryLocation `
                         maiImage2Capacity=$MaiImage2Capacity `
                         maiImage2eCapacity=$MaiImage2eCapacity `
                         deployImageModels=$([bool](-not $SkipImageDeployments.IsPresent)) `
            --query "properties.outputs" `
            --output json

        $finalDeploymentName = $attemptDeploymentName
        $lastDeploymentError = $null
        break
    }
    catch {
        $lastDeploymentError = $_
        $errorText = $_.Exception.Message
        $isIfMatchTransient = ($errorText -match "IfMatchPreconditionFailed") -or ($errorText -match "If-Match")

        if ($isIfMatchTransient -and $attempt -lt $maxDeploymentAttempts) {
            $delaySeconds = 10 * $attempt
            Write-Warning "Deployment hit transient If-Match precondition failure. Retrying in $delaySeconds seconds..."
            Start-Sleep -Seconds $delaySeconds
            continue
        }

        throw
    }
}

if ($lastDeploymentError) {
    throw $lastDeploymentError
}

$deploymentName = $finalDeploymentName

if (-not $outputsJson) {
    throw "Deployment completed without outputs."
}

$outputs = $outputsJson | ConvertFrom-Json

$foundryAccountName = $outputs.foundryAccountName.value
$foundryAccountId = $outputs.foundryAccountId.value
$foundryAccountId = if ([string]::IsNullOrWhiteSpace($foundryAccountId)) {
    az cognitiveservices account show `
        --subscription $selectedSubscription.id `
        --resource-group $ResourceGroupName `
        --name $foundryAccountName `
        --query "id" `
        --output tsv
}
else {
    $foundryAccountId
}
if ([string]::IsNullOrWhiteSpace($foundryAccountId)) {
    throw "Could not resolve Foundry account resource ID. AZURE_FOUNDRY_RESOURCE_ID cannot be populated."
}
$foundryEndpoint = $outputs.foundryEndpoint.value
$foundryProjectName = $outputs.foundryProjectName.value
$foundryProjectEndpoint = $outputs.foundryProjectEndpoint.value
$maiImage2Deployment = $outputs.maiImage2Deployment.value
$maiImage2eDeployment = $outputs.maiImage2eDeployment.value
$foundryModelEndpoint = if ($foundryEndpoint.EndsWith("/")) { $foundryEndpoint } else { "$foundryEndpoint/" }

$foundryApiKey = Try-GetCognitiveKey -ResourceGroupName $ResourceGroupName -AccountName $foundryAccountName
$useEntraAuth = [bool]([string]::IsNullOrWhiteSpace($foundryApiKey))

$normalizedFoundryEndpoint = if ($foundryEndpoint.EndsWith("/")) { $foundryEndpoint } else { "$foundryEndpoint/" }

$envContent = @"
# Auto-generated by infra/Deploy-MaiFoundry.ps1
# Subscription: $($selectedSubscription.name) ($($selectedSubscription.id))
# Resource group: $ResourceGroupName
# Deployment: $deploymentName

# MAI-Transcribe-1.5 (Foundry endpoint; no standalone SpeechServices resource)
MAI_TRANSCRIBE_15_KEY=$foundryApiKey
MAI_TRANSCRIBE_15_REGION=$FoundryLocation
MAI_TRANSCRIBE_15_ENDPOINT=$foundryModelEndpoint
TRANSCRIBE_LOCAL_AUDIO_DIR=C:\Flutter\azure-transcription\demodata

# MAI-Voice-2 / MAI-Voice-1 (Foundry endpoint)
MAI_VOICE_2_KEY=$foundryApiKey
MAI_VOICE_2_REGION=$FoundryLocation
MAI_VOICE_2_ENDPOINT=$foundryModelEndpoint
MAI_VOICE_2_RESOURCE_ID=$foundryAccountId
MAI_VOICE_NAME=en-us-Grant:MAI-Voice-1

AZURE_FOUNDRY_ENDPOINT=$normalizedFoundryEndpoint
AZURE_FOUNDRY_API_KEY=$foundryApiKey
AZURE_FOUNDRY_RESOURCE_ID=$foundryAccountId
MAI_IMAGE_2_DEPLOYMENT_NAME=$maiImage2Deployment
MAI_IMAGE_2E_DEPLOYMENT_NAME=$maiImage2eDeployment
MAI_IMAGE_2_CAPACITY=$MaiImage2Capacity
MAI_IMAGE_2E_CAPACITY=$MaiImage2eCapacity

FOUNDRY_PROJECT_NAME=$foundryProjectName
FOUNDRY_PROJECT_ENDPOINT=$foundryProjectEndpoint
AZURE_SUBSCRIPTION_ID=$($selectedSubscription.id)
AZURE_RESOURCE_GROUP=$ResourceGroupName
AZURE_FOUNDRY_ACCOUNT=$foundryAccountName

USE_ENTRA_AUTH=$($useEntraAuth.ToString().ToLowerInvariant())
# Optional service principal auth (uncomment only when you really use SP credentials):
# AZURE_TENANT_ID=
# AZURE_CLIENT_ID=
# AZURE_CLIENT_SECRET=
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
Write-Host "Voice/transcribe endpoints are mapped to the Foundry account endpoint (no standalone Speech service provisioned)."
Write-Host "Environment file written: $EnvPath"
Write-Host "Deployment environment snapshot: $deploymentEnvPath"
