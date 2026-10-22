#!/usr/bin/env python3
"""Keeps the Quick Scriptable install guide on the main README in sync with its single source,
scriptable/QUICK_INSTALL.md. Edit that file, never the copy between the README markers.

    python3 scripts/sync_readme.py           # rewrite README.md
    python3 scripts/sync_readme.py --check   # exit 1 if README.md is out of date (used in CI)
"""
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
README = ROOT / "README.md"
SOURCE = ROOT / "scriptable" / "QUICK_INSTALL.md"
START = "<!-- quick-install:start (generated from scriptable/QUICK_INSTALL.md by scripts/sync_readme.py) -->"
END = "<!-- quick-install:end -->"


def synced(readme: str, guide: str) -> str:
    start = readme.find(START)
    end = readme.find(END)
    if start == -1 or end == -1 or end < start:
        raise SystemExit("README.md is missing the quick-install markers")
    return readme[: start + len(START)] + "\n" + guide.strip() + "\n" + readme[end:]


def main() -> int:
    readme = README.read_text(encoding="utf-8")
    updated = synced(readme, SOURCE.read_text(encoding="utf-8"))
    if "--check" in sys.argv:
        if updated != readme:
            print("README.md is out of date: run `python3 scripts/sync_readme.py` and commit.", file=sys.stderr)
            return 1
        print("README.md quick-install guide is up to date")
        return 0
    README.write_text(updated, encoding="utf-8")
    print("README.md updated")
    return 0


if __name__ == "__main__":
    sys.exit(main())
