#!/usr/bin/env python3
"""Merge remote Qwen defaults without replacing other OpenCode providers."""
import argparse
import json
import shutil
from datetime import datetime
from pathlib import Path


def update(path, change):
    original = path.read_text() if path.exists() else "{}"
    data = json.loads(original)
    change(data)
    rendered = json.dumps(data, indent=2) + "\n"
    if rendered == original:
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists():
        shutil.copy2(path, path.with_name(path.name + datetime.now().strftime(".%Y%m%d-%H%M%S.bak")))
    temporary = path.with_name(path.name + ".tmp")
    temporary.write_text(rendered)
    if path.exists():
        shutil.copymode(path, temporary)
    temporary.replace(path)


def opencode_defaults(data, base_url):
    data.setdefault("$schema", "https://opencode.ai/config.json")
    data["model"] = "lmstudio/qwen/qwen3.8-27b"
    provider = data.setdefault("providers", {}).setdefault("lmstudio", {})
    provider["name"] = "Remote GPU server"
    provider.setdefault("package", "@opencode/ai/providers/openai-compatible")
    provider.setdefault("settings", {})["baseURL"] = base_url
    model = provider.setdefault("models", {}).setdefault("qwen/qwen3.8-27b", {})
    model.update({"name": "Qwen 3.8 27B (remote, 128K, MTP)", "modelID": "qwen/qwen3.8-27b"})
    model["limit"] = {"context": 131072, "output": 16384}
    model.setdefault("capabilities", {}).update({"tools": True, "input": ["text", "image"], "output": ["text"], "reasoning": {"supported": True}})
    model.setdefault("compatibility", {}).update({"reasoningField": "reasoning_content", "maxTokensField": "max_tokens"})
    model.setdefault("body", {})["reasoning_effort"] = "low"
    variants = model.setdefault("variants", [])
    for effort in ("low", "medium", "xhigh"):
        variant = next((item for item in variants if item["id"] == effort), None)
        if variant is None:
            variant = {"id": effort}
            variants.append(variant)
        variant.setdefault("body", {})["reasoning_effort"] = effort


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("base_url", help="OpenAI-compatible endpoint including /v1")
    args = parser.parse_args()
    home = Path.home()
    # The existing JSONC file contains plain JSON; preserve its other providers.
    update(home / ".config/opencode/opencode.jsonc", lambda data: opencode_defaults(data, args.base_url))
