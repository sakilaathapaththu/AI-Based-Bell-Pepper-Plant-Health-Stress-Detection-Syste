"""
Farmer-facing explanation layer, using the Gemini API ONLY to rephrase an
already-decided recovery plan into plain language - it never decides the
action, priority, or severity itself. Those are fully determined by
knowledge_base.py's deterministic rules before this module is ever called.

This separation matters: an LLM given raw sensor numbers and asked to
"recommend a recovery action" could hallucinate agronomic advice with no
accountability trail. Here, Gemini is only given the ALREADY-DECIDED
structured decision (action, priority, evidence) and asked to phrase it
naturally - the worst case if Gemini is unavailable/wrong is slightly
awkward phrasing, not a wrong recommendation.

If GEMINI_API_KEY is not set, or the API call fails for any reason (no
network, quota, invalid key), this falls back to the rule-based
why_this_action/recommended_action text untouched - the component must keep
working with zero internet/API access, since that text alone is already a
complete, correct answer.

Nothing in this file executes on import.
"""

from __future__ import annotations

import os

from dotenv import load_dotenv

# Loads adaptive-recovery-decision-support/.env (git-ignored) into the
# process environment, if that file exists, so GEMINI_API_KEY never has to
# be typed into the terminal every session or pasted into any committed
# file. Safe to call even if .env doesn't exist (no-op).
load_dotenv()

import config

_client = None
_client_init_attempted = False


def _get_client():
    """Lazily creates the Gemini client on first use, so importing this
    module never requires network access or a configured API key."""
    global _client, _client_init_attempted
    if _client_init_attempted:
        return _client

    _client_init_attempted = True
    api_key = os.environ.get(config.GEMINI_API_KEY_ENV_VAR)
    if not api_key:
        return None

    try:
        from google import genai

        _client = genai.Client(api_key=api_key)
    except Exception as exc:  # pragma: no cover - defensive, missing package/bad key
        print(f"[explanation] Gemini client unavailable, falling back to rule-based text: {exc}")
        _client = None

    return _client


def _build_prompt(decision: dict) -> str:
    evidence_lines = "\n".join(
        f"- {item['source']} detected {item['problem'].replace('_', ' ')} "
        f"(severity: {item['severity']}, confidence: {item.get('confidence')})"
        for item in decision.get("supporting_evidence", [])
    ) or "- No stress/pest evidence was flagged by the upstream components."

    return (
        "You are writing a short, plain-language explanation for a greenhouse "
        "worker who is not a technical expert. Do NOT change or contradict the "
        "decision below - only explain it clearly and reassuringly in 2-3 "
        "sentences. Do not invent any new recommendation, severity, or priority.\n\n"
        f"Plant condition: {decision['primary_problem']}\n"
        f"Severity: {decision['severity']}\n"
        f"Priority: {decision['priority']}\n"
        f"Recommended action: {decision['recommended_action']}\n"
        f"Secondary action: {decision['secondary_action']}\n"
        f"Growth stage: {decision['growth_stage']}\n"
        f"Environmental context: {decision['environmental_context']}\n"
        f"Evidence:\n{evidence_lines}\n\n"
        "Write the explanation now:"
    )


def generate_farmer_explanation(decision: dict) -> dict:
    """Returns {"text": str, "source": "gemini"|"rule_based_fallback"}."""
    client = _get_client()
    if client is None:
        return {"text": decision["why_this_action"], "source": "rule_based_fallback"}

    try:
        response = client.models.generate_content(
            model=config.GEMINI_MODEL_NAME,
            contents=_build_prompt(decision),
        )
        text = (response.text or "").strip()
        if not text:
            raise ValueError("Empty response from Gemini")
        return {"text": text, "source": "gemini"}
    except Exception as exc:  # pragma: no cover - defensive, network/quota/API errors
        print(f"[explanation] Gemini call failed, falling back to rule-based text: {exc}")
        return {"text": decision["why_this_action"], "source": "rule_based_fallback"}
