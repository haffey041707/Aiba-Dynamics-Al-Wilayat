"""Vercel serverless entry point.

Exposes the FastAPI ASGI app (`app`) so Vercel's @vercel/python runtime can
serve the /api/* routes. The static frontend in /web is served directly by
Vercel (see vercel.json).

NOTE: Vercel has no persistent disk and no bundled content data, so on Vercel
the Qur'an/Hadith content will be empty and accounts reset between cold starts.
For a fully working deployment use deploy/huggingface or deploy/setup.sh (VPS).
"""
import pathlib
import sys

# Make `import app...` resolve to the backend package.
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent.parent / "backend"))

from app.main import app  # noqa: E402,F401  (Vercel serves this ASGI `app`)
