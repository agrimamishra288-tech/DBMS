# Hemora — Blood Bank & Donor Matching System

[![CI](https://github.com/agrimamishra288-tech/DBMS/actions/workflows/ci.yml/badge.svg)](https://github.com/agrimamishra288-tech/DBMS/actions/workflows/ci.yml)

A DBMS capstone project: a PostgreSQL-backed API and React dashboard for managing donors, blood inventory, requests, and donations, plus public reference data from data.gov.in and the World Bank.

## Live demo

- App: https://hemora-brown.vercel.app
- API: https://hemora-api.vercel.app (health check: `/api/health`)
- Demo sign-in: `admin@bloodbank.in` / `Test@1234` (other seeded accounts use the same password; the demo-only password allowlist lives in `DEMO_PASSWORD_ONLY_EMAIL`)

## Stack

- PostgreSQL, Express 4, React 18 with Vite and Tailwind CSS
- Firebase Authentication for Google sign-in
- Neon Postgres and Vercel (API as a serverless function) for the hosted demo

## Donor matching

Matching is driven by the `blood_compatibility` table (27 ABO/Rh donor-to-recipient rules), not exact group equality: O− is the universal donor, A+ recipients can receive from A+, A−, O+ and O−, and so on.

- `fn_find_matching_donors(request group, city)` returns compatible, available donors who have not donated in the last 90 days. Same-city donors come first, then exact group (score 100), universal O− (80) and other compatible groups (60). Each row includes `same_city`, `is_exact_match` and `compatibility_score`.
- `fn_find_matching_units(request group, city)` returns available, unexpired compatible units: local stock first, then exact group, then nearest expiry (FEFO).
- `GET /api/requests/:id/match` runs both functions in parallel, records the top donors in `request_donor_matches`, and moves a pending request to `matched`.
- The Match panel labels every donor and unit as **Same city** or **Other city**, so requests in cities with no donors still see compatible people elsewhere.

Migration `008_cross_city_matching.sql` holds the current definitions; earlier migrations kept matching inside the request city.

## Repository layout

This capstone lives in the `Capstone/` folder of the [DBMS repository](https://github.com/agrimamishra288-tech/DBMS), alongside the `Lab/` and `Assignments/` folders.

```
Capstone/
  backend/    Express API, SQL schema, migrations, seed data, import scripts
  frontend/   React single-page dashboard
  docs/       Report diagrams and other documentation assets
Lab/          Lab exercises
Assignments/  Assignment submissions
```

## Local setup

Requirements: Node.js 20+, PostgreSQL 14+.

### Backend

```bash
cd Capstone/backend
npm install
cp .env.example .env      # set DATABASE_URL and JWT_SECRET
npm run init-db           # schema + migrations + seed (seeds only if the database is empty)
npm start                 # http://localhost:5000
```

- `npm run init-db:schema` applies schema and migrations only.
- `npm run init-db:seed` runs migrations and seeds only if the database is empty.
- Seeding never truncates existing records.
- `npm run db:status` prints table and row counts.

### Frontend

```bash
cd Capstone/frontend
npm install
cp .env.example .env      # Vite Firebase settings
npm run dev               # http://localhost:5173, proxies /api to port 5000
```

Set `VITE_PROXY_TARGET` in `frontend/.env` if the API runs somewhere other than `http://localhost:5000`.

## Data provenance

- Operational records (users, donors, inventory, requests, donations) are seeded demo data, clearly marked as such in the UI.
- Public directory and indicator data come from official sources: the Blood Bank Directory (data.gov.in, Government Open Data License - India) and World Bank Indicators.
- The public directory lists licensed facilities, not live stock.

## Checks

- API health: `curl https://hemora-api.vercel.app/api/health` (expect `200` with a database timestamp)
- API smoke test: `cd Capstone/backend && BASE_URL=https://hemora-api.vercel.app npm run smoke` (health, login, dashboard stats)
- Local frontend build: `cd Capstone/frontend && npm run build`
- Local API syntax: `cd Capstone/backend && find src -name '*.js' -print0 | xargs -0 -n1 node --check`
- GitHub Actions runs both checks on every push to `main` and on pull requests.

## Deployment notes

- Vercel imports `backend/src/app.js`, which exports the Express app; the long-running listener lives in `backend/src/start.js` for local development.
- The database is hosted on Neon; redeploying does not reseed or modify existing data.
- Firebase Admin credentials come from `GOOGLE_APPLICATION_CREDENTIALS` (file path) locally or `GOOGLE_APPLICATION_CREDENTIALS_JSON` (inline JSON) when hosted.
- Google sign-in requires the frontend domain to be listed in Firebase Authentication -> Settings -> Authorized domains.

## Documentation

- `DATABASE_DEMO_GUIDE.md` — database walkthrough for the demo
- `PRODUCT_REQUIREMENTS_DOCUMENT.md` — requirements
- `PROJECT_REPORT.md` — report
- `REAL_DATA_INTEGRATION_GUIDE.md` — public data sources and imports
