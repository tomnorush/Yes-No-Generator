#!/usr/bin/env python3
"""Fails if App Store metadata breaks App Store Connect's limits or repeats keywords.

    python3 scripts/check_metadata.py
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
METADATA = ROOT / "AppStore" / "metadata"

LIMITS = {
    "name.txt": 30,
    "subtitle.txt": 30,
    "keywords.txt": 100,
    "promotional_text.txt": 170,
    "description.txt": 4000,
    "release_notes.txt": 4000,
}

# Words the App Store indexes anyway or that are wasted in the keyword field.
STOP_WORDS = {"app", "free", "the", "a", "an", "and", "or", "for", "of", "iphone", "apple"}


def words(text):
    return {w for w in re.findall(r"[a-z0-9]+", text.lower())}


def main():
    problems = []
    locales = [p for p in METADATA.iterdir() if p.is_dir()]
    if not locales:
        problems.append("no locales found in AppStore/metadata")
    for locale in locales:
        texts = {}
        for name, limit in LIMITS.items():
            path = locale / name
            if not path.exists():
                problems.append(f"{locale.name}/{name}: missing")
                continue
            text = path.read_text(encoding="utf-8").strip()
            texts[name] = text
            if len(text) > limit:
                problems.append(f"{locale.name}/{name}: {len(text)} characters, limit is {limit}")
            print(f"{locale.name}/{name}: {len(text)}/{limit}")

        keywords = [k.strip() for k in texts.get("keywords.txt", "").split(",")]
        if any(not k for k in keywords):
            problems.append(f"{locale.name}/keywords.txt: empty entry (check for a trailing comma)")
        if any(" " in k for k in texts.get("keywords.txt", "").split(",")):
            problems.append(f"{locale.name}/keywords.txt: remove spaces after commas; they count toward the limit")
        if len(set(keywords)) != len(keywords):
            problems.append(f"{locale.name}/keywords.txt: duplicate keywords")
        already_indexed = words(texts.get("name.txt", "")) | words(texts.get("subtitle.txt", ""))
        repeated = sorted(set(keywords) & already_indexed)
        if repeated:
            problems.append(f"{locale.name}/keywords.txt: already in name/subtitle, wasted: {', '.join(repeated)}")
        wasted = sorted(set(keywords) & STOP_WORDS)
        if wasted:
            problems.append(f"{locale.name}/keywords.txt: words that add nothing: {', '.join(wasted)}")

    if problems:
        print("\n".join(f"error: {p}" for p in problems), file=sys.stderr)
        return 1
    print("Metadata OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
