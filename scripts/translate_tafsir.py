#!/usr/bin/env python3
"""Build Azerbaijani & Malay al-Mizan tafsir by translating the ENGLISH edition's
commentary into az/ms, writing almizan_az.json / almizan_ms.json with the same
structure (mapping + content). Resumable + concurrent. ur/fa/ar/en already exist.

    python scripts/translate_tafsir.py            # az + ms
    python scripts/translate_tafsir.py az         # one language
"""
import json
import os
import sys
from concurrent.futures import ThreadPoolExecutor, as_completed

sys.path.insert(0, os.path.dirname(__file__))
from translate_hadith import translate

TAFSIR = os.path.join(os.path.dirname(__file__), "..", "backend", "app", "data", "tafsir")
DEFAULT_LANGS = ["az", "ms"]
WORKERS = 10            # modest (a dua/ziyarat job may be sharing the endpoint)
SAVE_EVERY = 15


def main():
    langs = [a for a in sys.argv[1:] if a in DEFAULT_LANGS] or DEFAULT_LANGS
    en = json.load(open(os.path.join(TAFSIR, "almizan_en.json"), encoding="utf-8"))
    for lang in langs:
        out_path = os.path.join(TAFSIR, f"almizan_{lang}.json")
        if os.path.exists(out_path):
            out = json.load(open(out_path, encoding="utf-8"))
        else:
            out = {"edition": f"almizan_{lang}", "name": en.get("name"),
                   "language": lang, "author": en.get("author"),
                   "mapping": en["mapping"], "content": {}}
        todo = [cid for cid in en["content"] if cid not in out["content"]]
        print(f"{lang}: {len(todo)} chunks to translate (of {len(en['content'])})", flush=True)
        done = 0

        def save():
            json.dump(out, open(out_path, "w", encoding="utf-8"), ensure_ascii=False)

        with ThreadPoolExecutor(max_workers=WORKERS) as ex:
            futs = {ex.submit(translate, en["content"][cid], lang): cid for cid in todo}
            for fut in as_completed(futs):
                cid = futs[fut]
                try:
                    tr = fut.result()
                except Exception:
                    tr = None
                if tr:
                    out["content"][cid] = tr
                    done += 1
                    if done % SAVE_EVERY == 0:
                        save()
                        print(f"  {lang}: {done}/{len(todo)}", flush=True)
        save()
        print(f"{lang}: DONE ({done} chunks)", flush=True)
    print("\nAll az/ms tafsir translations done.")


if __name__ == "__main__":
    main()
