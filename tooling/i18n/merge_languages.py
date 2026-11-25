#!/usr/bin/env python3
"""Merge tooling/i18n/locales/*.json into the String Catalogs.

Each file is named with the catalog language id (de.json, zh-Hans.json)
and maps every Localizable key, plus the four Info.plist privacy keys, to a string.
Placeholders (%d, %@) must match English.
"""

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
LOCALE_DIR = Path(__file__).resolve().parent / "locales"
CATALOG = ROOT / "Slide" / "Localization" / "Localizable.xcstrings"
INFO = ROOT / "Slide" / "Localization" / "InfoPlist.xcstrings"

PLACEHOLDER = re.compile(r"%(?:\d+\$)?[@d]")


def placeholders(text: str):
    return PLACEHOLDER.findall(text)


def unit(value: str):
    return {"stringUnit": {"state": "translated", "value": value}}


def main():
    catalog = json.loads(CATALOG.read_text())
    info = json.loads(INFO.read_text())
    english = {
        key: value["localizations"]["en"]["stringUnit"]["value"]
        for key, value in catalog["strings"].items()
    }
    info_english = {
        key: value["localizations"]["en"]["stringUnit"]["value"]
        for key, value in info["strings"].items()
    }
    files = sorted(LOCALE_DIR.glob("*.json"))
    if not files:
        sys.exit(f"no locale files in {LOCALE_DIR}")
    for path in files:
        lang = path.stem
        blob = json.loads(path.read_text())
        missing = [key for key in english if key not in blob]
        extra = [key for key in blob if key not in english and key not in info_english]
        if missing or extra:
            sys.exit(f"{path.name}: missing {missing[:8]} extra {extra[:8]}")
        for key, value in blob.items():
            if not isinstance(value, str) or not value.strip():
                sys.exit(f"{path.name}: empty {key}")
            if key in english and placeholders(value) != placeholders(english[key]):
                sys.exit(
                    f"{path.name}: placeholders for {key}: {placeholders(value)} != {placeholders(english[key])}"
                )
            if key in info_english and placeholders(value) != placeholders(info_english[key]):
                sys.exit(f"{path.name}: info placeholders {key}")
            target = info if key in info_english else catalog
            target["strings"][key].setdefault("localizations", {})[lang] = unit(value)
        print(lang, "ok", len(blob))
    CATALOG.write_text(json.dumps(catalog, ensure_ascii=False, indent=2) + "\n")
    INFO.write_text(json.dumps(info, ensure_ascii=False, indent=2) + "\n")
    print("wrote", CATALOG)


if __name__ == "__main__":
    main()
