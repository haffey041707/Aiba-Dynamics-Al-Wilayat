# Publish Al-Wilayat free & forever on Hugging Face Spaces (no card)

A Hugging Face account is free, needs only an **email** (or Google) — it never
asks for a card — and your Space stays up with a permanent public URL.

## Steps (all in the browser, ~5 minutes + build time)

1. **Create a free account:** go to **https://huggingface.co/join** and sign up
   with your email or Google.

2. **Create a Space:** go to **https://huggingface.co/new-space**
   - **Owner:** you
   - **Space name:** `al-wilayat`
   - **License:** Other
   - **Select the SDK:** **Docker** → template **Blank**
   - **Hardware:** CPU basic (free)
   - **Visibility:** Public
   - Click **Create Space**.

3. **Add the two files** (use the **Files** tab → **+ Add file → Create a new file**):
   - Create **`Dockerfile`** → paste the contents of this folder's `Dockerfile`.
   - Open the existing **`README.md`** → replace it with this folder's `README.md`.
   - Commit each file.

4. The Space **builds automatically** (watch the **Logs**). It downloads the
   Qur'an/Hadith data, so the first build takes several minutes. When it says
   **Running**, your app is live at:

   **`https://<your-username>-al-wilayat.hf.space`**

   Share that link — anyone can use it, 24/7, free.

5. **(Recommended) Add your secrets:** Space **Settings → Variables and secrets
   → New secret**:
   - `WILAYAT_SECRET` = a long random string (sign-in token key)
   - `SMTP_HOST`, `SMTP_PORT`, `SMTP_USER`, `SMTP_FROM`, `SMTP_PASS`
     (only needed for password-reset emails)
   Then **Restart** the Space.

## Good to know
- The **URL is permanent** and the Space doesn't expire.
- On the free tier the disk **resets when the Space rebuilds/restarts**, so
  newly registered accounts can reset on a restart. The app itself and all
  content stay fine. For permanent accounts later, add HF **persistent storage**
  or move the database to a hosted one — ask and I'll set it up.
- To update the app later: in the Space, **Settings → Factory rebuild** (it
  re-pulls the latest source from GitHub).
