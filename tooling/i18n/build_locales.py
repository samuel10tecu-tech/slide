#!/usr/bin/env python3
"""Write tooling/i18n/locales/<lang>.json from the translation modules."""
import json
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

from gen_ui import LANGS, UI  # noqa: E402
from gen_ui2 import UI2  # noqa: E402
from gen_tricks1 import TRICKS  # noqa: E402
from gen_tricks2 import T2  # noqa: E402
from gen_tricks3 import T3  # noqa: E402
from gen_tricks4 import T4  # noqa: E402
from gen_tricks5 import T5  # noqa: E402
from gen_tricks6 import T6  # noqa: E402
from gen_tricks7 import T7  # noqa: E402
from gen_tricks8 import T8  # noqa: E402
from gen_tricks9 import T9  # noqa: E402
from gen_tricks10 import T10  # noqa: E402
from gen_tricks11 import T11  # noqa: E402
from gen_tricks12 import T12  # noqa: E402
from gen_tricks14 import T14  # noqa: E402
from gen_tricks13 import T13  # noqa: E402
from gen_pass import PASS  # noqa: E402

MAPS = [UI, UI2, TRICKS, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, PASS]


def main():
    seen = {}
    for blob in MAPS:
        for key in blob:
            if key in seen:
                sys.exit(f"duplicate key {key}")
            seen[key] = blob[key]
    out_dir = HERE / "locales"
    out_dir.mkdir(exist_ok=True)
    for lang in LANGS:
        data = {key: row[lang] for key, row in seen.items()}
        path = out_dir / f"{lang}.json"
        path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n")
        print(lang, len(data))
    print("keys", len(seen))


if __name__ == "__main__":
    main()
