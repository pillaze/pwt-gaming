# PWT Gaming — Website Source Repository

Official website: https://pwtgaming.com

## What this contains

- `web/` — complete editable website/PWA deployment source from the **v11.1 restored-rating / Team Builder fix** package (HTML, CSS, JS, images, avatars, icons, manifest, service worker).
- `database/reference-sql/` — available historical Supabase SQL setup, migration/seed, and security scripts for reference.
- `mobile-legacy/` — an **older v1.0 alpha2 Capacitor mobile source snapshot**. This is **not synchronized with v11.1**; do not deploy its `www/` over the current web app.

This is a working-source snapshot, **not an original Git history**, and the `web/` app currently embeds its CSS and JavaScript in `index.html`. No build pipeline is required for the web version.

## Run locally on Windows

Open PowerShell in the extracted repository:

```powershell
cd web
py -m http.server 8080
```

Open http://localhost:8080. If Python is unavailable, use `npx serve .` from `web/` (Node.js required).

**Important:** The web app connects to the existing production Supabase project using a public/publishable client key in `index.html`. Local actions such as posting chats, updating profiles, or admin changes may affect live data. Use a separate Supabase project for safe development, and review authentication redirect URLs for localhost.

## Deploy to Netlify

Set the site's **publish directory to `web`** when connecting this GitHub repository to Netlify. No build command is needed. Alternatively drag the `web/` folder to Netlify manual deploy.

For the PWA, test caching/service-worker upgrades carefully when deploying changes.

## Push to GitHub

Create an empty private GitHub repository named `pwt-gaming`, then run from the repository root:

```powershell
git init
git add .
git commit -m "Import PWT Gaming website source v11.1"
git branch -M main
git remote add origin https://github.com/YOUR_USERNAME/pwt-gaming.git
git push -u origin main
```

For ongoing development, commit changes locally and push. Connect the GitHub repo to the existing Netlify site to enable deploys from Git, **after verifying the publish directory and avoiding creation of a duplicate production site**.

## Database caveat

The included SQL files are historical reference scripts, **not a verified complete export of the current production database**. Live Supabase includes later migrations and data not reconstructed here. Do **not** execute seed scripts against production or assume they can recreate today's state. For full portability, export the current database schema and data through your Supabase project using the supported CLI/dashboard workflow, and handle private user data securely.

Known migration identifiers (metadata only): `20260929130652`, `20260929130749`, `20260929162155`, `20260929162656`, `20260929212810`.

## Security

- A Supabase **publishable** key is present in the frontend; this is expected for client-side Supabase apps. Row-level security and authorization must protect data.
- Never commit `service_role` keys, private credentials, `.env` files, session tokens, or real user data exports.
- Review all historical SQL before running it.
- Prefer a **private repository** until you have audited code and assets for third-party licensing and personal information.

## Version notes

This package uses the v11.1 website source snapshot, not an independently verified export of the currently live Netlify deploy. Later live-site edits will not automatically be included.

## Player Lobby redesign (local work)

The current source includes the mobile Lobby, availability polls, and notification inbox. New backend additions and deployment checks are documented in [docs/CHAT_LOBBY_DEPLOYMENT.md](docs/CHAT_LOBBY_DEPLOYMENT.md). These additions have not been applied to the production database or deployed. Run `node tests/chat-regression.cjs` and `node tests/chat-push.cjs` for isolated logic checks; use `python3 tests/build_chat_preview.py` for a sample-only UI preview.
