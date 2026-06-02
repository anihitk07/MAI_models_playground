# LinkedIn Post — MAI Models Playground

> Draft post for launching the **MAI Models Playground** (`anihitk07/MAI_models_playground`). Copy/paste into LinkedIn — adjust hashtags or tag names as needed.

---

🚀 **MAI Models Playground is live — and what a journey it has been.**

Over the last few weeks I have had the privilege of working hand-in-hand with the **Microsoft AI Product Engineering Group** on the latest wave of MAI models — **MAI-Transcribe-1 / 1.5, MAI-Voice-1 / 2-Preview, and MAI-Image-2 / 2e / 2.5** — now available in **Microsoft Foundry**.

These aren’t lab experiments. They’re the **same models powering Copilot Voice, Copilot Audio Expressions, Copilot dictation, Bing, PowerPoint, and Azure Speech** — and they’re now in every developer’s hands.

A few highlights from working directly with the product engineering team:

🔹 Iterating on **fresh model cards** and Foundry integration patterns as they were being finalized.
🔹 Watching **MAI-Transcribe-1.5** scale to 43 languages, 200-keyword entity biasing, and 5.7× faster long-form inference.
🔹 Hearing **MAI-Voice-2-Preview** generate natural, expressive speech across 15 languages and 18 locales — at **$22 / 1M characters**.
🔹 Seeing **MAI-Image-2.5** push photorealistic generation forward while staying efficient.

Why this matters: every one of these models pushes Microsoft further up the **global AI leadership stack**. Best-in-class quality, openly available in Foundry, with pricing that lets builders ship — not just demo. This is how Microsoft turns AI research into real product velocity.

---

## What’s in the repo

**👉 https://github.com/anihitk07/MAI_models_playground**

This is a **self-contained, deploy-and-go playground** for the MAI family in Microsoft Foundry:

✅ **One-click Bicep + PowerShell infra** — provisions an AI Foundry account, project, and MAI image deployments.
✅ **No standalone Speech service needed** — `MAI-Transcribe-1.5` and `MAI-Voice-2-Preview` run directly against the Foundry endpoint.
✅ **Auto-generated `deployment.env`** — endpoint, resource ID, keys, and deployment names wired straight into the notebooks.
✅ **7 end-to-end Jupyter notebooks** — transcribe, voice, and image samples + Foundry-keyless / Entra-auth flows.
✅ **MS Learn-style breakdown** in the README — model cards, pricing, regions, and code snippets per model.

---

## Use it in 3 steps

1️⃣ **Deploy** the infra:

```powershell
az login
pwsh .\infra\Deploy-MaiFoundry.ps1 -Location swedencentral
```

2️⃣ **Install** the Python dependencies:

```bash
pip install -r requirements.txt
```

3️⃣ **Plug in** — open any notebook under `notebooks/` (e.g. `05_MAI_Transcribe_1_5.ipynb`) and run. Credentials are picked up automatically from the generated `deployment.env`.

That’s it. No portal clicking, no hand-edited config, no scattered SDKs.

---

A huge thank-you to the **MAI Product Engineering Group** for the trust and the iteration loops. The future of multimodal AI is being shaped right now — and Microsoft is squarely at the front of it.

If you want to play with the same models I worked with, the repo is open and the deploy script is one command away. 👇

🔗 https://github.com/anihitk07/MAI_models_playground

#MicrosoftAI #MAIModels #MicrosoftFoundry #AzureAI #GenAI #Copilot #SpeechToText #TextToSpeech #ImageGeneration #DeveloperTools
