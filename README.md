# MAI Models on Microsoft Foundry

## Introduction

Microsoft AI (MAI) has released three world-class multimodal AI models, now available in public preview through **Microsoft Foundry**. These are the same models that power Microsoft's own products — Copilot, Bing, PowerPoint, and Azure Speech — and are now accessible to every developer:

| Model | Type | What it does |
|---|---|---|
| **MAI-Transcribe-1** | Speech-to-Text | Enterprise-grade transcription across 25 languages |
| **MAI-Voice-1** | Text-to-Speech | High-fidelity, expressive speech synthesis |
| **MAI-Image-2** | Text-to-Image | Photorealistic image generation, #3 on Arena.ai |

> 💡 **Try before you code:** All three models are available in the [MAI Playground](https://playground.microsoft.ai) (US only) — no account required for initial experimentation.

---

## Learning objectives

After completing this module, you'll be able to:

- ✅ Set up credentials for all three MAI models using a `.env` file
- ✅ Transcribe audio files using MAI-Transcribe-1 via the LLM Speech API
- ✅ Generate expressive speech using MAI-Voice-1 via REST and the Azure Speech SDK
- ✅ Generate photorealistic images using MAI-Image-2 and MAI-Image-2e via the Foundry API
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
├── .env.example                 ← Credential template (copy to .env, never commit .env)
├── requirements.txt             ← Python dependencies
├── 01_MAI_Transcribe_1.ipynb   ← Speech-to-text notebook
├── 02_MAI_Voice_1.ipynb        ← Text-to-speech notebook
├── 03_MAI_Image_2.ipynb        ← Text-to-image notebook
└── README.md           ← This document
```

---

## Unit 1: Environment Setup

### Install dependencies

```bash
pip install -r requirements.txt
```

The `requirements.txt` includes:

```
azure-cognitiveservices-speech>=1.40.0  # MAI-Transcribe-1 & MAI-Voice-1
azure-identity>=1.17.0                  # Entra ID / managed identity auth
requests>=2.32.0                        # REST API calls
python-dotenv>=1.0.0                    # .env file support
Pillow>=10.0.0                          # Image display and manipulation
ipython>=8.0.0
ipywidgets>=8.0.0
```

### Configure your credentials

Copy `.env.example` to `.env` and fill in your values:

```bash
cp .env.example .env
```

```ini
# Azure Speech (MAI-Transcribe-1 & MAI-Voice-1)
SPEECH_KEY=your_speech_resource_key_here
SPEECH_REGION=eastus            # eastus or westus for Transcribe-1
                                 # centralus, japanwest, or swedencentral for Voice-1

# MAI-Voice-1 voice name (from Azure Speech Studio > Voice Gallery)
MAI_VOICE_NAME=en-US-MAIVoice1Neural

# MAI-Image-2 (Microsoft Foundry)
AZURE_FOUNDRY_ENDPOINT=https://<resource-name>.services.ai.azure.com
AZURE_FOUNDRY_API_KEY=your_foundry_api_key_here
MAI_IMAGE_2_DEPLOYMENT_NAME=mai-image-2
MAI_IMAGE_2E_DEPLOYMENT_NAME=mai-image-2e
```

> ⚠️ **Security:** Never commit your `.env` file. The `.env.example` file is safe to commit — it contains no real credentials.

### Load credentials in Python

```python
from dotenv import load_dotenv
import os

load_dotenv()

SPEECH_KEY    = os.getenv("SPEECH_KEY")
SPEECH_REGION = os.getenv("SPEECH_REGION")
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

```
POST https://{region}.api.cognitive.microsoft.com/speechtotext/transcriptions:transcribe?api-version=2025-10-15
```

### Code: Basic transcription

```python
import os, json, requests
from dotenv import load_dotenv

load_dotenv()
SPEECH_KEY    = os.getenv("SPEECH_KEY")
SPEECH_REGION = os.getenv("SPEECH_REGION", "eastus")

TRANSCRIBE_URL = (
    f"https://{SPEECH_REGION}.api.cognitive.microsoft.com"
    "/speechtotext/transcriptions:transcribe"
    "?api-version=2025-10-15"
)

definition = {
    "enhancedMode": {
        "enabled": True,
        "model": "mai-transcribe-1"
    }
}

with open("audio.wav", "rb") as audio:
    response = requests.post(
        TRANSCRIBE_URL,
        headers={"Ocp-Apim-Subscription-Key": SPEECH_KEY},
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

```
POST https://{region}.tts.speech.microsoft.com/cognitiveservices/v1
```

### Code: Basic text-to-speech (REST)

```python
import os, requests
from dotenv import load_dotenv

load_dotenv()
SPEECH_KEY    = os.getenv("SPEECH_KEY")
SPEECH_REGION = os.getenv("SPEECH_REGION", "centralus")
VOICE_NAME    = os.getenv("MAI_VOICE_NAME", "en-US-MAIVoice1Neural")

TTS_ENDPOINT = f"https://{SPEECH_REGION}.tts.speech.microsoft.com/cognitiveservices/v1"

ssml = f"""<speak version='1.0' xml:lang='en-US'>
  <voice xml:lang='en-US' name='{VOICE_NAME}'>
    Hello! I am MAI-Voice-1, a high-fidelity speech generation model.
  </voice>
</speak>"""

response = requests.post(
    TTS_ENDPOINT,
    headers={
        "Ocp-Apim-Subscription-Key": SPEECH_KEY,
        "Content-Type": "application/ssml+xml",
        "X-Microsoft-OutputFormat": "audio-24khz-160kbitrate-mono-mp3",
        "User-Agent": "MAI-Voice-Demo",
    },
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
  --sku-capacity 1
```

For MAI-Image-2e: replace `--model-name MAI-Image-2 --model-version 2026-02-20` with `--model-name MAI-Image-2e --model-version 2026-04-09`.

### API endpoint

```
POST https://{resource-name}.services.ai.azure.com/mai/v1/images/generations
```

### Code: Generate an image

```python
import os, base64, requests
from dotenv import load_dotenv

load_dotenv()
ENDPOINT        = os.getenv("AZURE_FOUNDRY_ENDPOINT")
API_KEY         = os.getenv("AZURE_FOUNDRY_API_KEY")
DEPLOYMENT_NAME = os.getenv("MAI_IMAGE_2_DEPLOYMENT_NAME", "mai-image-2")

url = f"{ENDPOINT.rstrip('/')}/mai/v1/images/generations"

payload = {
    "model":  DEPLOYMENT_NAME,
    "prompt": "A photorealistic mountain lake at sunrise, golden hour lighting",
    "width":  1024,
    "height": 1024,
}

response = requests.post(
    url,
    headers={"Content-Type": "application/json", "api-key": API_KEY},
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

## Unit 5: Pricing & Cost Optimization

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

## Unit 6: Authentication Best Practices

### API key auth (development)

```python
headers = {
    "Ocp-Apim-Subscription-Key": os.getenv("SPEECH_KEY"),  # Speech models
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

> ✅ **Best practice:** Use managed identity (DefaultAzureCredential) in production. Store API keys in Azure Key Vault, not in environment variables on cloud VMs.

---

## Unit 7: Responsible AI

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

## Unit 8: Error Handling & Troubleshooting

### Common errors

| Error | Cause | Fix |
|---|---|---|
| `401 Unauthorized` | Invalid API key or expired token | Regenerate key in Azure portal; refresh Entra token |
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
| **Notebook** | `01_MAI_Transcribe_1.ipynb` | `02_MAI_Voice_1.ipynb` | `03_MAI_Image_2.ipynb` |
| **Pricing** | $0.36/hr | $22/1M chars | $5/1M text + $33/1M img tokens |
| **Key strength** | #1 FLEURS, 50% cheaper GPU | 60s audio in <1s | #3 Arena.ai, superior text rendering |
| **API style** | REST multipart | REST SSML / SDK | REST JSON |
| **Auth** | API key / Entra ID | API key / Entra ID | API key / Entra ID |
| **Deployment** | Azure Speech resource | Azure Speech resource | Foundry global standard deployment |

---

## Additional resources

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
