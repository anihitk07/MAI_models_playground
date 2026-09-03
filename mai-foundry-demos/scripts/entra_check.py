"""Ad-hoc Entra ID live-auth check (not part of the pytest suite).

scripts/live_smoke.py's missing_services() contract intentionally requires
api-keys to be configured (see tests/test_live_smoke.py) — it is NOT
Entra-aware by design, so it can't be reused here. This script exercises
MAIClient directly, which *is* Entra-aware (see MAIClient._authable), to
prove the org-policy (disableLocalAuth=true) workaround actually works
end-to-end against the real deployed resources.
"""

from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from mai import MAIClient  # noqa: E402

client = MAIClient()
cfg = client.cfg
print(f"execution_mode={cfg.execution_mode}")
print(f"foundry_endpoint={cfg.foundry_endpoint!r} thinking_ready(): {client.thinking_ready()}")

print("\n--- Thinking-1 chat ---")
try:
    resp = client.chat_completion(
        [{"role": "user", "content": "Reply with exactly: OK"}],
        max_completion_tokens=4096,
    )
    content = (resp["choices"][0]["message"].get("content") or "").strip()
    print("PASS:", content[:80])
except Exception as exc:
    print("FAIL:", exc)

print("\n--- Image generation ---")
try:
    res = client.generate_image("A plain red circle on a white background.", 768, 768)
    print(f"source={res.source} bytes={len(res.data or b'')} elapsed={res.elapsed:.1f}s error={res.error}")
except Exception as exc:
    print("FAIL:", exc)

print("\n--- Voice-2 synthesis (regional TTS endpoint) ---")
try:
    tts = client.synthesize("Live smoke test for MAI Voice.", voice="en-US-Ethan:MAI-Voice-2")
    print(f"source={tts.source} bytes={len(tts.data or b'')} error={tts.error}")
except Exception as exc:
    print("FAIL:", exc)
