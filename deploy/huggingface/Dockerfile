# Al-Wilayat — Hugging Face Space (Docker SDK)
# Self-contained image: fetches the source + content data and serves the app
# and API on port 7860 (the port Hugging Face Spaces routes traffic to).

FROM python:3.12-slim

# git is needed to fetch the source during build.
RUN apt-get update && apt-get install -y --no-install-recommends git \
    && rm -rf /var/lib/apt/lists/*

# Hugging Face runs the container as a non-root user (uid 1000).
RUN useradd -m -u 1000 user
USER user
ENV HOME=/home/user \
    PATH=/home/user/.local/bin:$PATH \
    WILAYAT_NOBROWSER=1

WORKDIR /home/user/app
RUN git clone --depth 1 https://github.com/haffey041707/Aiba-Dynamics-Al-Wilayat.git .

WORKDIR /home/user/app/backend
RUN pip install --no-cache-dir --user -r requirements.txt

# Bake the content into the image so the Space is self-contained.
# (Each step is best-effort so one flaky download can't fail the whole build.)
RUN python ingest/fetch_quran.py || true
RUN python ingest/fetch_hadith.py || true
RUN python ingest/fetch_duas_ziyarat.py || true
RUN python ingest/fetch_ziyarat.py || true

EXPOSE 7860
CMD ["python", "-m", "uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "7860"]
