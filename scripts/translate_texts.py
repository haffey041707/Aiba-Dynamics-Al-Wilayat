#!/usr/bin/env python3
"""Translate the ENGLISH of every Dua / Ziyarat verse into Urdu/Farsi/
Azerbaijani/Malay and store it on the verse as v["ur"|"fa"|"az"|"ms"].
Arabic (v["ar"]) and English (v["en"]) are untouched. Resumable + concurrent.

    python scripts/translate_texts.py
"""
import glob
import json
import os
import sys
from concurrent.futures import ThreadPoolExecutor, as_completed

sys.path.insert(0, os.path.dirname(__file__))
from translate_hadith import translate          # reuse the same translator

LANGS = ["ur", "fa", "az", "ms"]
WORKERS = 16
BASE = os.path.join(os.path.dirname(__file__), "..", "backend", "app", "data")


def main():
    files = sorted(glob.glob(os.path.join(BASE, "dua", "*.json")) +
                   glob.glob(os.path.join(BASE, "ziyarat", "*.json")))
    print(f"Translating {len(files)} dua/ziyarat files into {LANGS}\n")
    grand = 0
    for f in files:
        d = json.load(open(f, encoding="utf-8"))
        verses = d.get("verses", [])
        tasks = [(v, lang, (v.get("en") or "").strip())
                 for v in verses for lang in LANGS
                 if (v.get("en") or "").strip() and not v.get(lang)]
        if not tasks:
            print(f"  ✓ {os.path.basename(f):28} already done")
            continue
        done = 0
        with ThreadPoolExecutor(max_workers=WORKERS) as ex:
            futs = {ex.submit(translate, en, lang): (v, lang) for (v, lang, en) in tasks}
            for fut in as_completed(futs):
                v, lang = futs[fut]
                try:
                    tr = fut.result()
                except Exception:
                    tr = None
                if tr:
                    v[lang] = tr
                    done += 1
                    grand += 1
        json.dump(d, open(f, "w", encoding="utf-8"), ensure_ascii=False)
        print(f"  • {os.path.basename(f):28} +{done} (total {grand})", flush=True)
    print(f"\nDone. {grand} translations added.")


if __name__ == "__main__":
    main()
