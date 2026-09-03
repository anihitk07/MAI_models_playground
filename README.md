# MAI Models on Microsoft Foundry

## Introduction

Microsoft AI (MAI) has released a family of world-class multimodal AI models, now available through **Microsoft Foundry**. These are the same models that power Microsoft's own products — Copilot, Bing, PowerPoint, and Azure Speech — and are now accessible to every developer:

| Generation | Model | Type | What it does |
|---|---|---|---|
| **GA / Public preview** | **MAI-Transcribe-1** | Speech-to-Text | Enterprise-grade transcription across 25 languages |
| | **MAI-Voice-1** | Text-to-Speech | High-fidelity, expressive speech synthesis |
| | **MAI-Image-2** / **MAI-Image-2e** | Text-to-Image | Photorealistic image generation, #3 on Arena.ai |
| **Latest wave** | **MAI-Transcribe-1.5** | Speech-to-Text | 43 languages, 200-keyword entity biasing, up to 5.7× faster long-form inference |
| | **MAI-Voice-2-Preview** | Text-to-Speech | Multilingual prompted TTS across 15 languages / 18 locales, expressive control |
| | **MAI-Image-2.5** | Text-to-Image | Higher fidelity image generation and editing (private preview) |

> 💡 **Try before you code:** All three models are available in the [MAI Playground](https://playground.microsoft.ai) (US only) — no account required for initial experimentation.

---

## Learning objectives

After completing this module, you'll be able to:

- ✅ Set up credentials for every MAI model using a single auto-generated `deployment.env`
- ✅ Transcribe audio files using MAI-Transcribe-1 (LLM Speech API) and MAI-Transcribe-1.5 (Foundry fast/LLM/batch + entity biasing)
- ✅ Generate expressive speech using MAI-Voice-1 (REST + Speech SDK) and MAI-Voice-2-Preview (Foundry Speech SDK with Entra `aad#<resource-id>#<token>` flow)
- ✅ Generate photorealistic images using MAI-Image-2 / MAI-Image-2e and MAI-Image-2.5 via the Foundry API
- ✅ Calculate and optimize costs for each model

---

## Prerequisites

- An **Azure subscription** ([create one free](https://azure.microsoft.com/free))
- A **Microsoft Foundry project** ([create a project](https://learn.microsoft.com/azure/foundry/how-to/create-projects))
- Python 3.10 or later
- Basic familiarity with REST APIs and Python

---

## Project structure

```
MAI_Model_demo/
├── deployment.env               ← Auto-generated credentials for notebooks (never commit)
├── requirements.txt             ← Python dependencies
├── notebooks/
│   ├── 01_MAI_Transcribe_1.ipynb       ← MAI-Transcribe-1 speech-to-text
│   ├── 02_MAI_Voice_1.ipynb            ← MAI-Voice-1 text-to-speech
│   ├── 03_MAI_Image_2.ipynb            ← MAI-Image-2 text-to-image
│   ├── 04_MAI_Image_2_Foundry.ipynb    ← MAI-Image-2 via Foundry endpoint (keyless)
│   ├── 05_MAI_Transcribe_1_5.ipynb     ← MAI-Transcribe-1.5 (Foundry integration)
│   ├── 06_MAI_Voice_2.ipynb            ← MAI-Voice-2-Preview (Foundry integration)
│   ├── 07_MAI_Image_2_5.ipynb          ← MAI-Image-2.5 (private preview)
│   └── model-releases/                 ← Vendored capsules from microsoft-foundry/model-releases
│       ├── mai-image-2.5/              ← Baseline image generation + editing
│       ├── mai-image-2.5-flash/        ← Production-throughput batch generation
│       ├── mai-image-2.5-pro/          ← Portrait quality, signage/text rendering
│       ├── mai-transcribe-1.5/         ← Multilingual transcription + noise-robustness benchmark
│       └── multi-model-scenarios/      ← Cross-model walkthroughs (e.g. Image family comparison)
├── mai-foundry-demos/                   ← Vendored Streamlit app (ppiova/mai-foundry-demos)
│                                          Thinking-1, Image-2.5, Transcribe-1.5, Voice-2 demos
├── images/                              ← Generated image outputs (gitignored)
├── audio/                               ← Generated audio outputs (gitignored)
├── infra/
│   ├── main.bicep                       ← Foundry + MAI deployment template
│   ├── main.parameters.json             ← Sample deployment parameters
│   ├── Deploy-MaiFoundry.ps1            ← End-to-end deploy + deployment.env script
│   └── modules/                         ← Reusable Bicep modules
└── README.md                            ← This document
```

---

## Unit 1: Environment Setup

### Option A: Deploy infra with Bicep (recommended)

This repo includes an `infra` deployment path (inspired by Foundry Bicep patterns from `corticalstack/awesome-foundry-nextgen`) to provision:

- Azure AI Foundry account (`AIServices`) + Foundry project
- MAI image deployments (`MAI-Image-2`, `MAI-Image-2e`)
- Shared Foundry Cognitive Services endpoint for MAI-Transcribe-1 and MAI-Voice-1 samples
- Auto-generated environment file at repo root: `deployment.env`

#### Prerequisites

```powershell
az login
az account show
```

#### Quickstart

```powershell
pwsh .\infra\Deploy-MaiFoundry.ps1
```

By default, each deployment run now gets a unique naming token (prefix suffix) to avoid Cognitive Services name collisions across regions and old runs.
The script uses your current Azure CLI subscription context unless you pass `-SubscriptionId`.
Use `-Location <azure-region>` to set both the resource group location and Foundry location in one parameter.
Image deployment capacity defaults are now **MAI-Image-2 = 15** and **MAI-Image-2e = 30**.

#### Common deployment options

```powershell
# Deploy to a specific resource group
pwsh .\infra\Deploy-MaiFoundry.ps1 `
  -SubscriptionId <subscription-id-or-name> `
  -ResourceGroupName rg-mai-model-demo-eastus `
  -Location swedencentral

# Or set locations independently
pwsh .\infra\Deploy-MaiFoundry.ps1 `
  -SubscriptionId <subscription-id-or-name> `
  -ResourceGroupName rg-mai-model-demo-eastus `
  -ResourceGroupLocation eastus `
  -FoundryLocation swedencentral

# Skip MAI image deployments when quota is unavailable
pwsh .\infra\Deploy-MaiFoundry.ps1 -SkipImageDeployments

# Override image capacities (defaults: 15 for MAI-Image-2, 30 for MAI-Image-2e)
pwsh .\infra\Deploy-MaiFoundry.ps1 `
  -MaiImage2Capacity 15 `
  -MaiImage2eCapacity 30

# Optional: provide your own run token (otherwise one is auto-generated)
pwsh .\infra\Deploy-MaiFoundry.ps1 -DeploymentRunId demo01

# Reuse non-unique names (not recommended): script runs strict pre-purge first
pwsh .\infra\Deploy-MaiFoundry.ps1 `
  -SubscriptionId <subscription-id-or-name> `
  -ResourceGroupName rg-mai-model-demo-eastus `
  -NoUniqueNaming

# Destroy resource group + purge soft-deleted Cognitive Services accounts for that group
pwsh .\infra\Deploy-MaiFoundry.ps1 `
  -SubscriptionId <subscription-id-or-name> `
  -ResourceGroupName rg-mai-model-demo-eastus `
  -Destroy
```

#### Name collision and soft-delete handling

`Deploy-MaiFoundry.ps1` now handles common Cognitive Services naming failures:

- **`InvalidResourceLocation` / name already exists in another region**  
  Prevented by default via unique per-run naming.
- **`CustomDomainInUse`**  
  Mitigated by unique naming and purge support.
- **`FlagMustBeSetForRestore` (soft-deleted account exists)**  
  `-Destroy` deletes the resource group and force-purges soft-deleted Cognitive accounts for that group.  
  `-NoUniqueNaming` triggers strict pre-deployment purge so the run fails fast if purge cannot complete.
- **`IfMatchPreconditionFailed` during nested model deployment updates**  
  The script automatically retries deployment up to 3 times with short backoff.

#### Post-deployment outputs

After completion, verify generated file:

```powershell
Get-Item .\deployment.env
```

Validate model deployments:

```powershell
az cognitiveservices account deployment list `
  -g <resource-group> `
  -n <foundry-account-name> `
  -o table
```

### Install dependencies

```bash
pip install -r requirements.txt
```

The `requirements.txt` includes:

```
azure-cognitiveservices-speech>=1.40.0  # MAI-Transcribe-1 & MAI-Voice-1
azure-identity>=1.17.0                  # Entra ID / managed identity auth
requests>=2.32.0                        # REST API calls
python-dotenv>=1.0.0                    # deployment.env loading
Pillow>=10.0.0                          # Image display and manipulation
ipython>=8.0.0
ipywidgets>=8.0.0
```

### Configure your credentials

The deployment script generates `deployment.env` at the repository root.  
If you are configuring manually, create/edit `deployment.env` directly with these values:

```ini
# Default auth mode for all notebooks
USE_ENTRA_AUTH=true

# Foundry account (used by speech + image notebooks)
AZURE_FOUNDRY_ENDPOINT=https://<foundry-account>.cognitiveservices.azure.com/
AZURE_FOUNDRY_API_KEY=
AZURE_FOUNDRY_RESOURCE_ID=/subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.CognitiveServices/accounts/<foundry-account>

# MAI-Transcribe-1.5 / MAI-Voice-2 (Foundry endpoint, no standalone Speech service)
MAI_TRANSCRIBE_15_KEY=
MAI_TRANSCRIBE_15_REGION=eastus
MAI_TRANSCRIBE_15_ENDPOINT=https://<foundry-account>.cognitiveservices.azure.com/
MAI_VOICE_2_KEY=
MAI_VOICE_2_REGION=eastus
MAI_VOICE_2_ENDPOINT=https://<foundry-account>.cognitiveservices.azure.com/
MAI_VOICE_2_RESOURCE_ID=/subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.CognitiveServices/accounts/<foundry-account>
MAI_VOICE_NAME=en-us-Grant:MAI-Voice-1

# MAI-Image-2 / MAI-Image-2e
MAI_IMAGE_2_DEPLOYMENT_NAME=mai-image-2
MAI_IMAGE_2E_DEPLOYMENT_NAME=mai-image-2e
```

When `USE_ENTRA_AUTH=true` (default), notebooks use `DefaultAzureCredential` and Bearer tokens.  
When `USE_ENTRA_AUTH=false`, notebooks fall back to API keys from the same `deployment.env` file.
If you use terminal auth (`az login`), keep `AZURE_TENANT_ID`, `AZURE_CLIENT_ID`, and `AZURE_CLIENT_SECRET` unset unless you intentionally use a service principal.

> ⚠️ **Security:** Never commit `deployment.env` (it contains real environment values/secrets).

### Load credentials in Python

```python
from dotenv import load_dotenv
import os
from azure.identity import DefaultAzureCredential, get_bearer_token_provider

load_dotenv("deployment.env", override=True)

USE_ENTRA_AUTH = os.getenv("USE_ENTRA_AUTH", "true").lower() == "true"

token_provider = None
if USE_ENTRA_AUTH:
    # Avoid EnvironmentCredential selecting empty SPN values from deployment.env
    for env_var in ("AZURE_TENANT_ID", "AZURE_CLIENT_ID", "AZURE_CLIENT_SECRET"):
        if os.getenv(env_var) == "":
            os.environ.pop(env_var, None)
    token_provider = get_bearer_token_provider(
        DefaultAzureCredential(),
        "https://cognitiveservices.azure.com/.default"
    )
```

---

## Unit 2: MAI-Transcribe-1 — Speech-to-Text

### Overview

| Attribute | Detail |
|---|---|
| **Architecture** | Autoregressive + LLM-enhanced |
| **Languages** | 25 (Arabic, Chinese, Czech, Danish, Dutch, English, Finnish, French, German, Hindi, Hungarian, Indonesian, Italian, Japanese, Korean, Norwegian, Polish, Portuguese, Romanian, Russian, Spanish, Swedish, Thai, Turkish, Vietnamese) |
| **Input formats** | WAV · MP3 · FLAC |
| **File size limit** | ≤ 70 MB (with `mai-transcribe-1` model) |
| **API** | Fast Transcription API, version `2025-10-15` |
| **Supported regions** | East US · West US |
| **Pricing** | **$0.36 per audio hour** |

### Key achievements

- **#1 on FLEURS benchmark** for 11 of the top-25 global languages
- Outperforms **Whisper-large-v3** on all 25 languages
- Outperforms **Gemini 2.1 Flash** on 11 of 14 measured languages
- Approximately **50% lower GPU cost** than leading alternatives

### Powers these Microsoft products

Copilot Voice Mode transcriptions · Copilot dictation feature · Azure Speech

### API endpoint

- **Entra token auth (recommended):**  
  `POST https://<foundry-account>.cognitiveservices.azure.com/speechtotext/transcriptions:transcribe?api-version=2025-10-15`
- **API key auth:**  
  `POST https://<foundry-account>.cognitiveservices.azure.com/speechtotext/transcriptions:transcribe?api-version=2025-10-15`

### Code: Basic transcription

```python
import os, json, requests
from dotenv import load_dotenv
from azure.identity import DefaultAzureCredential, get_bearer_token_provider

load_dotenv("deployment.env", override=True)
SPEECH_KEY = (
    os.getenv("TRANSCRIBE_SPEECH_KEY")
    or os.getenv("AZURE_SPEECH_KEY")
    or os.getenv("AZURE_FOUNDRY_API_KEY")
    or os.getenv("SPEECH_KEY")
)
SPEECH_REGION = os.getenv("TRANSCRIBE_SPEECH_REGION") or os.getenv("SPEECH_REGION", "eastus")
SPEECH_ENDPOINT = (
    os.getenv("TRANSCRIBE_SPEECH_ENDPOINT")
    or os.getenv("AZURE_SPEECH_ENDPOINT")
    or os.getenv("AZURE_FOUNDRY_ENDPOINT")
)
USE_ENTRA_AUTH = os.getenv("USE_ENTRA_AUTH", "true").lower() == "true"

token_provider = get_bearer_token_provider(
    DefaultAzureCredential(),
    "https://cognitiveservices.azure.com/.default"
) if USE_ENTRA_AUTH else None

def build_auth_headers():
    if USE_ENTRA_AUTH:
        return {"Authorization": f"Bearer {token_provider()}"}
    return {"Ocp-Apim-Subscription-Key": SPEECH_KEY}

assert SPEECH_ENDPOINT, "Set AZURE_FOUNDRY_ENDPOINT or TRANSCRIBE_SPEECH_ENDPOINT"
TRANSCRIBE_URL = (
    f"{SPEECH_ENDPOINT.rstrip('/')}"
    "/speechtotext/transcriptions:transcribe"
    "?api-version=2025-10-15"
)

definition = {
    "locales": ["en-US"],
    "diarization": {
        "enabled": True,
        "maxSpeakers": 2
    },
    "enhancedMode": {
        "enabled": True,
        "task": "transcribe"
    }
}

with open("audio.wav", "rb") as audio:
    response = requests.post(
        TRANSCRIBE_URL,
        headers=build_auth_headers(),
        files={
            "audio":      ("audio.wav", audio, "audio/wav"),
            "definition": (None, json.dumps(definition)),
        },
    )

response.raise_for_status()
result = response.json()

for phrase in result["combinedPhrases"]:
    print(phrase["text"])
```


### Use cases

| Use case | Scenario |
|---|---|
| **Conversational AI** | Real-time transcription for IVR, virtual assistants, call-center agent assist |
| **Live Captioning** | Real-time captions for events, enterprise meetings, digital communications |
| **Media & Subtitling** | Automate video subtitling, dialogue indexing, media archiving |
| **Education** | Transcribe lectures, e-learning modules, certification programs |
| **Customer Insights** | Convert focus groups and support calls into structured analytics data |

---

## Unit 3: MAI-Voice-1 — Text-to-Speech

### Overview

| Attribute | Detail |
|---|---|
| **Model type** | Text-to-Speech (TTS) |
| **Speed** | 60 seconds of audio in < 1 second on a single GPU |
| **Languages** | English (10+ coming soon) |
| **Input** | Plain text · SSML (emotion/tone control per turn) |
| **Output** | MP3 · WAV · Opus · FLAC |
| **Voice features** | Curated voice library · Voice prompting (clone from 10s audio clip) |
| **API** | Azure Speech REST API · Speech SDK |
| **Supported regions** | Central US · Japan West · Sweden Central |
| **Pricing** | **$22 per 1M characters** |

### Powers these Microsoft products

Copilot Audio Expressions · Copilot podcast feature

### REST API endpoint

- **Entra token auth (recommended):**  
  `POST https://<foundry-account>.cognitiveservices.azure.com/tts/cognitiveservices/v1`
- **API key auth:**  
  `POST https://<foundry-account>.cognitiveservices.azure.com/tts/cognitiveservices/v1`

### Code: Basic text-to-speech (REST)

```python
import os, requests
from dotenv import load_dotenv
from azure.identity import DefaultAzureCredential, get_bearer_token_provider

load_dotenv("deployment.env", override=True)
SPEECH_KEY = (
    os.getenv("VOICE_SPEECH_KEY")
    or os.getenv("AZURE_SPEECH_KEY")
    or os.getenv("AZURE_FOUNDRY_API_KEY")
    or os.getenv("SPEECH_KEY")
)
SPEECH_REGION = os.getenv("VOICE_SPEECH_REGION") or os.getenv("SPEECH_REGION", "eastus")
SPEECH_ENDPOINT = (
    os.getenv("VOICE_SPEECH_ENDPOINT")
    or os.getenv("AZURE_SPEECH_ENDPOINT")
    or os.getenv("AZURE_FOUNDRY_ENDPOINT")
)
FOUNDRY_RESOURCE_ID = os.getenv("AZURE_FOUNDRY_RESOURCE_ID")
USE_ENTRA_AUTH = os.getenv("USE_ENTRA_AUTH", "true").lower() == "true"
VOICE_NAME    = os.getenv("MAI_VOICE_NAME", "en-us-Grant:MAI-Voice-1")
if USE_ENTRA_AUTH:
    assert FOUNDRY_RESOURCE_ID, "Set AZURE_FOUNDRY_RESOURCE_ID for Speech SDK Entra auth"

token_provider = get_bearer_token_provider(
    DefaultAzureCredential(),
    "https://cognitiveservices.azure.com/.default"
) if USE_ENTRA_AUTH else None

def build_tts_headers():
    headers = {
        "Content-Type": "application/ssml+xml",
        "X-Microsoft-OutputFormat": "audio-24khz-160kbitrate-mono-mp3",
        "User-Agent": "MAI-Voice-Demo",
    }
    if USE_ENTRA_AUTH:
        headers["Authorization"] = f"Bearer {token_provider()}"
    else:
        headers["Ocp-Apim-Subscription-Key"] = SPEECH_KEY
    return headers

assert SPEECH_ENDPOINT, "Set AZURE_FOUNDRY_ENDPOINT or VOICE_SPEECH_ENDPOINT"
TTS_ENDPOINT = f"{SPEECH_ENDPOINT.rstrip('/')}/tts/cognitiveservices/v1"

ssml = f"""<speak version='1.0' xml:lang='en-US'>
  <voice xml:lang='en-US' name='{VOICE_NAME}'>
    Hello! I am MAI-Voice-1, a high-fidelity speech generation model.
  </voice>
</speak>"""

response = requests.post(
    TTS_ENDPOINT,
    headers=build_tts_headers(),
    data=ssml.encode("utf-8"),
)
response.raise_for_status()

with open("output.mp3", "wb") as f:
    f.write(response.content)
print("Saved: output.mp3")
```

### Code: SSML with emotion control

```python
ssml = f"""<speak version='1.0'
              xmlns='http://www.w3.org/2001/10/synthesis'
              xmlns:mstts='http://www.w3.org/2001/mstts'
              xml:lang='en-US'>
  <voice name='{VOICE_NAME}'>
    <mstts:express-as style='excited'>
      We're thrilled to announce MAI-Voice-1 is now available!
    </mstts:express-as>
    <break time='500ms'/>
    <mstts:express-as style='calm'>
      It delivers 60 seconds of audio in under one second.
    </mstts:express-as>
  </voice>
</speak>"""
```

### Code: Azure Speech SDK

```python
import azure.cognitiveservices.speech as speechsdk
from urllib.parse import urlparse

if USE_ENTRA_AUTH:
    # Foundry playground pattern: endpoint + aad#{resourceId}#{token}
    parsed = urlparse(SPEECH_ENDPOINT.rstrip("/"))
    base_endpoint = f"{parsed.scheme}://{parsed.netloc}"
    speech_config = speechsdk.SpeechConfig(endpoint=base_endpoint)
    speech_config.authorization_token = f"aad#{FOUNDRY_RESOURCE_ID}#{token_provider()}"
else:
    speech_config = speechsdk.SpeechConfig(subscription=SPEECH_KEY, region=SPEECH_REGION)
speech_config.speech_synthesis_voice_name = VOICE_NAME

audio_config = speechsdk.audio.AudioOutputConfig(filename="output.wav")
synthesizer  = speechsdk.SpeechSynthesizer(speech_config=speech_config, audio_config=audio_config)

result = synthesizer.speak_text_async("Hello from MAI-Voice-1!").get()
if result.reason == speechsdk.ResultReason.SynthesizingAudioCompleted:
    print("✅ Speech synthesized successfully")
```

### Voice prompting (Personal Voice)

MAI-Voice-1 supports cloning any voice from a **10-second audio sample**, powered by Azure Speech Personal Voice:

1. Obtain approval from Microsoft ([apply here](https://learn.microsoft.com/azure/ai-services/speech-service/personal-voice-overview))
2. Create a speaker profile with your consented audio sample
3. Reference the profile in SSML:

```xml
<voice name='DragonLatestNeural'>
  <mstts:ttsembedding speakerProfileId='your-speaker-profile-id'/>
  Your synthesized text here.
</voice>
```

### Use cases

| Use case | Scenario |
|---|---|
| **Virtual Assistants** | Power conversational agents with a branded voice |
| **Media & Entertainment** | Audiobooks, podcasts, game characters, AR/VR experiences |
| **Accessibility** | Audio narration for visually impaired users |
| **IVR Systems** | Dynamic, natural call center and phone interaction voices |
| **Education** | Character and brand voices for online courses |
| **Marketing** | Consistent voice across product launches and campaigns |

---

## Unit 4: MAI-Image-2 — Text-to-Image

### Overview

| Attribute | MAI-Image-2 | MAI-Image-2e (Efficient) |
|---|---|---|
| **Model type** | Text-to-image (diffusion) | Text-to-image (diffusion, optimized) |
| **Arena.ai ranking** | #3 (image model families) | — |
| **Best for** | Highest fidelity, portraits, complex scenes | High-volume, real-time, production pipelines |
| **Speed vs MAI-Image-2** | Baseline | **22% faster** |
| **Efficiency vs MAI-Image-2** | Baseline | **4× more efficient** |
| **Input** | Text prompt (≤ 32,000 tokens) | Text prompt (≤ 32,000 tokens) |
| **Output** | PNG (base64) | PNG (base64) |
| **Dimensions** | Min 768×768, max pixel product 1,048,576 | Same |
| **API endpoint** | `{endpoint}/mai/v1/images/generations` | Same |
| **Regions** | WC US · E US · W US · W Europe · Sweden Central · South India | Same |
| **Text input pricing** | **$5 / 1M tokens** | **$5 / 1M tokens** |
| **Image output pricing** | **$33 / 1M image tokens** | ~75% lower (4× more efficient) |

### Powers these Microsoft products

Copilot image generation · Bing Image Creator · PowerPoint image generation

### Deployment

Deploy via the Foundry portal or Azure CLI:

```bash
az cognitiveservices account deployment create \
  --name <ACCOUNT_NAME> \
  --resource-group <RESOURCE_GROUP> \
  --deployment-name mai-image-2 \
  --model-name MAI-Image-2 \
  --model-format Microsoft \
  --model-version 2026-02-20 \
  --sku-name GlobalStandard \
  --sku-capacity 15
```

For MAI-Image-2e: replace `--model-name MAI-Image-2 --model-version 2026-02-20` with `--model-name MAI-Image-2e --model-version 2026-04-09` and use `--sku-capacity 30`.

### API endpoint

```
POST https://{resource-name}.services.ai.azure.com/mai/v1/images/generations
```

### Code: Generate an image

```python
import os, base64, requests
from dotenv import load_dotenv
from azure.identity import DefaultAzureCredential, get_bearer_token_provider

load_dotenv("deployment.env", override=True)
ENDPOINT        = os.getenv("AZURE_FOUNDRY_ENDPOINT")
API_KEY         = os.getenv("AZURE_FOUNDRY_API_KEY")
USE_ENTRA_AUTH  = os.getenv("USE_ENTRA_AUTH", "true").lower() == "true"
DEPLOYMENT_NAME = os.getenv("MAI_IMAGE_2_DEPLOYMENT_NAME", "mai-image-2")

token_provider = get_bearer_token_provider(
    DefaultAzureCredential(),
    "https://cognitiveservices.azure.com/.default"
) if USE_ENTRA_AUTH else None

headers = {"Content-Type": "application/json"}
if USE_ENTRA_AUTH:
    headers["Authorization"] = f"Bearer {token_provider()}"
else:
    headers["api-key"] = API_KEY

url = f"{ENDPOINT.rstrip('/')}/mai/v1/images/generations"

payload = {
    "model":  DEPLOYMENT_NAME,
    "prompt": "A photorealistic mountain lake at sunrise, golden hour lighting",
    "width":  1024,
    "height": 1024,
}

response = requests.post(
    url,
    headers=headers,
    json=payload,
)
response.raise_for_status()
result = response.json()

# Decode and save
image_b64 = result["data"][0]["b64_json"]
with open("output.png", "wb") as f:
    f.write(base64.b64decode(image_b64))
print("Saved: output.png")
```

### Dimension constraints

| Constraint | Requirement |
|---|---|
| Minimum width | 768 px |
| Minimum height | 768 px |
| Maximum total pixels | 1,048,576 (≈ 1024×1024) |
| Output format | PNG (always) |

Valid examples: 768×768, 1024×768, 1024×1024, 1365×768 (=1,048,320 ✅)

### Rate limits (RPM)

| Deployment Tier | MAI-Image-2 RPM | MAI-Image-2e RPM |
|---|---|---|
| Tier 1 | 9 | 18 |
| Tier 2 | 15 | 30 |
| Tier 3 | 30 | 60 |
| Tier 6 | 90 | 180 |

### Use cases

| Use case | Recommended model |
|---|---|
| **Final creative deliverables, portraits** | MAI-Image-2 |
| **Photorealistic scenes with complex text** | MAI-Image-2 |
| **Marketing creatives at scale** | MAI-Image-2e |
| **Product shots, batch pipelines** | MAI-Image-2e |
| **Real-time interactive workflows** | MAI-Image-2e |

---

## Unit 5: Latest wave — MAI-Transcribe-1.5, MAI-Voice-2-Preview, MAI-Image-2.5

The latest generation of MAI models ships under three Foundry-aligned recipes inside `notebooks/` (`05_MAI_Transcribe_1_5.ipynb`, `06_MAI_Voice_2.ipynb`, `07_MAI_Image_2_5.ipynb`).

### MAI-Transcribe-1.5 — Foundry speech-to-text (notebook 05)

| Attribute | Detail |
|---|---|
| **Languages** | **43** (25 from v1 + 18 new in v1.5) |
| **Long-form speedup** | Up to **5.7×** faster than MAI-Transcribe-1 |
| **Entity / keyword biasing** | Up to **200 keywords** via `phraseList.phrases` |
| **Language identification** | Automatic |
| **Diarization** | Not supported yet (planned) |
| **Input formats** | WAV · MP3 · FLAC, up to **300 MB / 2 hours** |
| **Serving regions** | Central US · Sweden Central · Southeast Asia |
| **Integration patterns covered** | Real-time SDK (microphone), fast multipart REST, LLM enhanced mode, batch submit |

### MAI-Voice-2-Preview — Foundry TTS (notebook 06)

| Attribute | Detail |
|---|---|
| **Languages / locales** | **15 languages · 18 locales** (Arabic, Chinese, English, French, German, Hindi, Indonesian, Italian, Japanese, Korean, Portuguese, Russian, Spanish, Thai, Vietnamese) |
| **Auth** | Speech SDK with Entra `aad#<resource-id>#<token>` (key-auth fallback supported) |
| **Output** | 24 kHz mono audio (MP3) |
| **Voice prompting** | 5–60 s audio prompts; gated personal voice flow |
| **Pricing reference** | **$22 / 1M characters** |
| **Serving regions** | East US · Sweden Central · Southeast Asia |

### MAI-Image-2.5 — next-gen image generation (notebook 07)

| Attribute | Detail |
|---|---|
| **Capabilities** | Higher-fidelity text-to-image generation **and** image editing |
| **Auth** | API key (private preview) |
| **Status** | Private preview — terms of access apply |
| **Notebook flow** | Text-to-image (width/height) + image-edit (`size`) + troubleshooting |

> 🔐 The Foundry-only deployment script (`infra/Deploy-MaiFoundry.ps1`) now wires `MAI_TRANSCRIBE_15_*`, `MAI_VOICE_2_*`, and `AZURE_FOUNDRY_RESOURCE_ID` into the generated `deployment.env` — no standalone Speech resource is provisioned.

### Vendored capsules — `notebooks/model-releases/`

In addition to the hand-authored notebooks above, this repo mirrors the official sample notebooks
published in [`microsoft-foundry/model-releases`](https://github.com/microsoft-foundry/model-releases/tree/main/models/microsoft-ai).
Each has been verified (valid notebook JSON, no embedded execution output, no broken links, no
confidential wording) before being committed here:

| Capsule | Notebook(s) | Highlights |
|---|---|---|
| [`mai-image-2.5/`](notebooks/model-releases/mai-image-2.5/) | `mai-image-2.5.ipynb` | Text-to-image generation, aspect ratios, image-to-image editing |
| [`mai-image-2.5-flash/`](notebooks/model-releases/mai-image-2.5-flash/) | `mai-image-2.5-flash.ipynb` | Batch generation, throughput measurement, concurrent requests |
| [`mai-image-2.5-pro/`](notebooks/model-releases/mai-image-2.5-pro/) | `mai-image-2.5-pro.ipynb` | Portrait quality, signage/text rendering, visual reasoning |
| [`mai-transcribe-1.5/`](notebooks/model-releases/mai-transcribe-1.5/) | `mai-transcribe-1.5.ipynb`, `mai-transcribe-1.5-noise-benchmark.ipynb` | Multilingual transcription, keyword biasing, WER/CER noise-robustness sweep |
| [`multi-model-scenarios/mai-image-family-walkthrough/`](notebooks/model-releases/multi-model-scenarios/mai-image-family-walkthrough/) | `mai-image-family-walkthrough.ipynb` | Compare MAI-Image-2.5 base / Flash / Pro on the same prompts |

> ℹ️ These vendored notebooks use the upstream repo's own env-var convention
> (`MICROSOFT_FOUNDRY_ENDPOINT`, `MICROSOFT_FOUNDRY_API_KEY`, `AZURE_MAI_*_DEPLOYMENT`) — documented in
> each capsule's `README.md` — which is independent of this repo's `deployment.env`.

---

## Unit 6: Pricing & Cost Optimization

### Pricing summary

| Model | Metric | Price |
|---|---|---|
| **MAI-Transcribe-1** | Per audio hour | **$0.36** |
| **MAI-Voice-1** | Per 1M characters | **$22.00** |
| **MAI-Image-2** | Per 1M text input tokens | **$5.00** |
| **MAI-Image-2** | Per 1M image output tokens | **$33.00** |
| **MAI-Image-2e** | Per 1M text input tokens | **$5.00** |
| **MAI-Image-2e** | Per 1M image output tokens | ~**$8.25** (4× cheaper) |

> 💡 See [Azure pricing page](https://azure.microsoft.com/pricing/details/cognitive-services/speech-services/) for exact and up-to-date MAI model pricing.

### Cost comparison: MAI-Transcribe-1 vs. alternatives

| Hours | MAI-Transcribe-1 ($0.36/hr) | Leading alternative (~$0.72/hr) | Saving |
|---|---|---|---|
| 1 | $0.36 | $0.72 | 50% |
| 100 | $36.00 | $72.00 | 50% |
| 1,000 | $360 | $720 | $360 |
| 10,000 | $3,600 | $7,200 | $3,600 |

### Cost calculator: MAI-Voice-1

```
Cost = (character_count / 1,000,000) × $22.00

Examples:
  3,000 char blog post  → $0.000066
  30,000 char chapter   → $0.00066
  500,000 char audiobook → $0.011
  1,000,000 chars/day    → $0.022/day = $8.03/year
```

### Cost calculator: MAI-Image-2

```
Text cost  = (prompt_tokens / 1,000,000) × $5.00
Image cost = (image_tokens  / 1,000,000) × $33.00

Typical 1024×1024 image (~1,056 image tokens):
  Text  (75 tokens): $0.000000375
  Image (1,056 tokens): $0.0000348
  Total per image: ~$0.0000352  (~$0.000035)

1,000 images:  ~$0.035
10,000 images: ~$0.35
100,000 images: ~$3.50
```

### Cost optimization tips

| Strategy | Tip |
|---|---|
| **MAI-Transcribe-1** | Batch short audio clips into longer files to minimize per-request overhead |
| **MAI-Voice-1** | Cache synthesized audio for frequently used phrases (greetings, menu items) |
| **MAI-Image-2** | Use MAI-Image-2e for volume workflows; reserve MAI-Image-2 for final/hero images |
| **All models** | Use Entra ID managed identity to avoid key rotation overhead in production |

---

## Unit 7: Authentication Best Practices

The notebooks in this repo now default to **Entra ID** (`DefaultAzureCredential`) and use API keys only when `USE_ENTRA_AUTH=false`.

### API key fallback

```python
headers = {
    "Ocp-Apim-Subscription-Key": os.getenv("VOICE_SPEECH_KEY"),  # Speech models
    # or
    "api-key": os.getenv("AZURE_FOUNDRY_API_KEY"),          # Image models
}
```

### Microsoft Entra ID auth (production — recommended)

```python
from azure.identity import DefaultAzureCredential, get_bearer_token_provider

token_provider = get_bearer_token_provider(
    DefaultAzureCredential(),
    "https://cognitiveservices.azure.com/.default"
)
token = token_provider()

headers = {"Authorization": f"Bearer {token}"}
```

> ✅ **Best practice:** Keep `USE_ENTRA_AUTH=true` for local dev and production. Store fallback API keys in Azure Key Vault, not in source control.

---

## Unit 8: Responsible AI

Microsoft developed these MAI models with responsible AI at the forefront:

### What Microsoft does

- Models are **rigorously red-teamed** before release
- **Built-in content safety** guardrails in Microsoft Foundry
- **Governance and compliance controls** for enterprise deployment
- All models comply with [Microsoft's Responsible AI Standard](https://www.microsoft.com/ai/responsible-ai)

### What you should do

| Recommendation | Details |
|---|---|
| **Transparency** | Disclose that audio is AI-generated when publishing; disclose AI-generated images |
| **Consent** | Voice cloning (Personal Voice) requires explicit speaker consent and Microsoft approval |
| **Content safety** | Configure Azure AI Content Safety for additional mitigations |
| **No harmful content** | Do not generate content that could mislead, harm, or violate privacy |
| **Copyright compliance** | Ensure generated images comply with applicable IP and copyright laws |
| **Data privacy** | Do not send PII in prompts unless required and properly governed |

### Out-of-scope uses

- **MAI-Transcribe-1:** Real-time transcription (coming soon), diarization with mai-transcribe-1 model parameter
- **MAI-Voice-1:** Voice cloning without explicit consent and Microsoft approval
- **MAI-Image-2:** Generation of harmful, misleading, sexual, violent, or privacy-violating content

---

## Unit 9: Error Handling & Troubleshooting

### Common errors

| Error | Cause | Fix |
|---|---|---|
| `401 Unauthorized` (Speech) | Token principal lacks `speechrest/transcriptions/action` OR endpoint/tenant mismatch | Assign **Cognitive Services Speech User** on the Foundry account and use `AZURE_FOUNDRY_ENDPOINT=https://<foundry-account>.cognitiveservices.azure.com` |
| `ValueError: client_id should be the id...` | Empty `AZURE_CLIENT_ID` / `AZURE_TENANT_ID` / `AZURE_CLIENT_SECRET` loaded from `deployment.env` | Remove those keys (or comment them) unless using service principal auth; then rerun notebook |
| `400 InvalidRequest` (`Enhanced mode with model is currently not supported yet`) | Endpoint doesn't currently accept `enhancedMode.model` | Remove `model` from `enhancedMode` (keep `enhancedMode.enabled/task`) and retry |
| `400 InvalidRequest` (`Enhanced mode is currently not supported yet`) | Endpoint doesn't currently accept `enhancedMode` for this API path/region | Retry with standard definition (no `enhancedMode`) |
| `SDK says success but file is 0 KB` | Speech SDK completed without audio bytes on this Foundry endpoint path | Use REST `/tts/cognitiveservices/v1` fallback (the notebook now does this automatically) |
| `404 Not Found` | Wrong deployment name or endpoint | Verify in Foundry portal > Deployments |
| `400 Bad Request` (Image) | Dimensions below minimum or pixel count exceeded | Ensure w,h ≥ 768 and w×h ≤ 1,048,576 |
| `400 Bad Request` (Speech) | Unsupported audio format or file too large | Use WAV/MP3/FLAC, ≤ 70 MB for mai-transcribe-1 |
| `429 Too Many Requests` | Rate limit exceeded | Implement exponential back-off; request quota increase |

### Retry pattern

```python
import time

def call_with_retry(fn, max_retries=3, base_delay=1.0):
    for attempt in range(max_retries):
        try:
            return fn()
        except requests.exceptions.HTTPError as e:
            if e.response.status_code == 429 and attempt < max_retries - 1:
                wait = base_delay * (2 ** attempt)
                print(f"Rate limited. Retrying in {wait}s...")
                time.sleep(wait)
            else:
                raise
```

---

## Summary

| | MAI-Transcribe-1 | MAI-Voice-1 | MAI-Image-2 |
|---|---|---|---|
| **Category** | Speech-to-Text | Text-to-Speech | Text-to-Image |
| **Notebook** | `notebooks/01_MAI_Transcribe_1.ipynb` | `notebooks/02_MAI_Voice_1.ipynb` | `notebooks/03_MAI_Image_2.ipynb` |
| **Pricing** | $0.36/hr | $22/1M chars | $5/1M text + $33/1M img tokens |
| **Key strength** | #1 FLEURS, 50% cheaper GPU | 60s audio in <1s | #3 Arena.ai, superior text rendering |
| **API style** | REST multipart | REST SSML / SDK | REST JSON |
| **Auth** | API key / Entra ID | API key / Entra ID | API key / Entra ID |
| **Deployment** | Azure Speech resource | Azure Speech resource | Foundry global standard deployment |

---

## mai-foundry-demos: a presentation-ready Streamlit app

`mai-foundry-demos/` vendors [ppiova/mai-foundry-demos](https://github.com/ppiova/mai-foundry-demos)
(tag `v1.1.1`) — a single Streamlit app that turns four MAI capabilities into short, story-driven
demos suited for a live 30–45 minute walkthrough rather than a notebook cell-by-cell read:

| Demo | Model(s) | What it shows |
|---|---|---|
| 🧠 Thinking · Decision Agent | MAI-Thinking-1 | Tool-using reasoning over a cloud estate / migration constraints, with streaming + tool calls |
| 🎨 Image · Surgical Edit | MAI-Image-2.5 | Controlled image editing that preserves everything except the requested change |
| 🎙️ Transcribe · Entity biasing | MAI-Transcribe-1.5 | Domain-aware transcription using phrase-list biasing and verbatim mode |
| 🗣️ Voice · Personalities | MAI-Voice-2 | The same line read in three emotional styles (Neutral / Empathy / Excited) |
| 🎬 Multimodal finale | All four | Chains the four capabilities into one end-to-end campaign scenario |

Every demo runs 🟢 LIVE against real Foundry endpoints when `.env` is populated, and degrades to a
deterministic 🟡 FALLBACK otherwise — so a live network hiccup on stage never kills the demo.

**Deployed and tested end-to-end** against a fresh Foundry account (`infra/main.bicep`,
region `eastus`). This tenant enforces `disableLocalAuth=true` via Azure Policy (no api-key can be
issued), so a local patch (see `mai-foundry-demos/README.md`) adds an Entra ID bearer-token
fallback. Result: Thinking-1, Image-2.5, and Transcribe-1.5 ran 🟢 LIVE via Entra ID; Voice-2's
regional TTS endpoint requires an actual api-key and stayed 🟡 FALLBACK in this tenant. See
`mai-foundry-demos/README.md` for the full breakdown and setup instructions.

---



- [Microsoft Foundry portal](https://ai.azure.com)
- [MAI Playground](https://playground.microsoft.ai)
- [Announcement blog post](https://techcommunity.microsoft.com/blog/azure-ai-foundry-blog/introducing-mai-transcribe-1-mai-voice-1-and-mai-image-2-in-microsoft-foundry/4507787)
- [MAI-Image-2 announcement](https://microsoft.ai/news/mai-image-2-efficient/)
- [MAI models combined announcement](https://microsoft.ai/news/today-were-announcing-3-new-world-class-mai-models-available-in-foundry/)
- [Model Card: MAI-Transcribe-1](https://ai.azure.com/catalog/models/MAI-Transcribe-1)
- [Model Card: MAI-Voice-1](https://ai.azure.com/catalog/models/MAI-Voice-1)
- [Model Card: MAI-Image-2](https://ai.azure.com/catalog/models/MAI-Image-2)
- [Use Foundry MAI Models (MS Docs)](https://learn.microsoft.com/azure/foundry/foundry-models/how-to/use-foundry-models-mai)
- [LLM Speech API](https://learn.microsoft.com/azure/ai-services/speech-service/llm-speech)
- [Azure Speech TTS docs](https://learn.microsoft.com/azure/ai-services/speech-service/text-to-speech)
- [Azure Speech regions](https://learn.microsoft.com/azure/ai-services/speech-service/regions)
- [Azure Pricing: Cognitive Services](https://azure.microsoft.com/pricing/details/cognitive-services/speech-services/)
- [Responsible AI for Speech](https://learn.microsoft.com/azure/ai-foundry/responsible-ai/speech-service/speech-to-text/transparency-note)
- [Model Card PDFs](https://microsoft.ai/pdf/MAI-Transcribe-1-Model-Card.pdf)
