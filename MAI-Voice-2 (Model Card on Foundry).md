
# MAI-Voice-2

The next iteration in our speech synthesis family, MAI‑Voice‑2 is a prompted text‑to‑speech (TTS) model that generates high‑fidelity, natural, and expressive speech across 15 languages. It captures human-like intonation, rhythm, and emotional nuance, enabling engaging and lifelike conversational experiences.  

## About this model

There are two ways to set the voice for your project:

• Curated voice library: Licensed voices designed to work straight out of the box.  
• Voice prompting: Provide a short audio clip (5–60 seconds) and the model matches it instantly.     

## Key capabilities

- Natural voice synthesis.  
- High-fidelity, high-clarity voice output.  
- Multilingual support across 15 languages & 18 locales.
- Voice prompting with improved pacing, delivery, and naturalness. Instantly generate natural speech in any consented voice, without additional training/fine-tuning.     
- Long-form content generation.

## Key model capabilities

1. **High fidelity Natural Voice Synthesis**  
Produces speech with realistic intonation, rhythm, and emotional range.     

2. **State-of-the-Art Voice Prompting**  
Generate speech from short audio prompts (5-60 seconds). Prompt quality significantly impacts output, with best results from natural, conversational delivery and moderate energy levels.     

3. **Fine-grained control**  
Supports turn-level control over tone, delivery, and emotion.     

4. **Long-form content generation**  
Supports extended narration (e.g., audiobooks, podcasts) via chunking with context carryover.     

5. **Multilingual speech synthesis**  
English, Italian, Spanish (Mexico), Hindi, English (Australia), French, German, Portuguese (Brazil), Korean, Portuguese (Portugal), Spanish (Spain), Chinese (Simplified), Turkish, Russian, Thai, Dutch, Romanian, Hungarian.

---

# Use cases

## Key use cases

- **Media: Entertainment** – Generate expressive voices for games, films, podcasts, and immersive experiences.  
- **Virtual Assistants and Chatbots** – Power conversational agents across apps and devices with natural voices.  
- **Accessibility Features** – Provide narration for visually impaired users and assistive voice technologies.  
- **Educational Experiences** – Build interactive learning content with expressive narration.  
- **Marketing and Advertising** – Deliver consistent voice experiences across campaigns.  
- **Self-authored Content** – Turn written content into spoken audio using custom voice characteristics.  
- **IVR Systems** – Enable natural, expressive call center interactions.  
- **Public Announcements** – Deliver clear, engaging voice output for public information systems.     

## Out of scope use cases

This model prioritizes naturalness and expressivity over ultra-low latency scenarios.   

Usage will be restricted to use the service in any way that is inconsistent with the [Code of Conduct](https://learn.microsoft.com/en-us/legal/ai-code-of-conduct?context=%2Fazure%2Fai-services%2Fspeech-service%2Fcontext%2Fcontext#usage-restrictions)  

---

# Pricing

$22 per 1M characters

---

# Technical specs

### Training cut-off date

This information is not available. 

### Input formats

Transcript text + speaker prompt (5-60s audio), with optional non-verbal annotations such as [pause] or [laughs].     

### Output

24kHz mono audio.   

### Context length

Up to ~1 minute per generation, with longer outputs supported via chunking.     

### Supported languages

English(US), English (Australia), Hindi, French, German, Italian, Portuguese (Brazil), Hindi, Spanish (Spain), Spanish(Mexico), Korean (South Korea), Mandarin, Russian, Thai, Dutch, Turkish, Romanian, Hungarian.


## Supported Azure regions

MAI-Voice-2 can be accessed globabally. The model is currently served from three regions

* East US (EUS)
* Sweden Central (SEC)
* SEA=Southeast Asia (SEA)

to which the requests are routed.


## Model architecture

This information is not available. 

## Optimizing model performance

This information is not available. 

## Additional assets

This information is not available.

# Distribution

- **Speech SDK**  

Integrate TTS capabilities directly into applications using Azure’s Speech SDK, available for platforms including .NET, Python, Java, JavaScript, and C++. 

 

- **REST API**  

Access TTS functionality via a public, subscription-based API for flexible integration into web services, mobile apps, and backend systems. 

# More information

Learn more in the full [Azure AI Speech Service documentation](https://learn.microsoft.com/azure/ai-services/speech-service/). 
