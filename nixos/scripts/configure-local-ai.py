#!/usr/bin/env python3
"""Merge local Qwen defaults without replacing other models or prompt templates."""
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


def model_defaults(data):
    fields = data.setdefault("load", {}).setdefault("fields", [])
    values = {
        "llm.load.contextLength": 131072,
        "llm.load.llama.acceleration.offloadRatio": 1,
        "llm.load.llama.flashAttention": True,
        "llm.load.offloadKVCacheToGpu": True,
        "llm.load.llama.kCacheQuantizationType": {"checked": True, "value": "q8_0"},
        "llm.load.llama.vCacheQuantizationType": {"checked": True, "value": "q8_0"},
        "llm.load.speculativeDecoding.draftMtp": True,
        "llm.load.speculativeDecoding.draftSimple": False,
        "llm.load.speculativeDecoding.draftMaxTokens": 5,
        "llm.load.numParallelSessions": 1,
    }
    for key, value in values.items():
        existing = next((field for field in fields if field["key"] == key), None)
        if existing is None:
            fields.append({"key": key, "value": value})
        else:
            existing["value"] = value


if __name__ == "__main__":
    home = Path.home()
    update(home / ".lmstudio/.internal/user-concrete-model-default-config/qwen/qwen3.8-27b.json", model_defaults)
