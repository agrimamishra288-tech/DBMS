# Hemora — Blood Bank & Donor Matching System

[![CI](https://github.com/agrimamishra288-tech/DBMS/actions/workflows/ci.yml/badge.svg)](https://github.com/agrimamishra288-tech/DBMS/actions/workflows/ci.yml)

The DBMS capstone: a PostgreSQL-backed blood bank platform with donor management, inventory, emergency requests, ABO/Rh-compatible donor and unit matching, donation records, and public reference data from data.gov.in and the World Bank. It lives in the `Capstone/` folder of the [DBMS repository](https://github.com/agrimamishra288-tech/DBMS), alongside `Lab/` and `Assignments/`.

- App: https://hemora-brown.vercel.app
- API: https://hemora-api.vercel.app (`/api/health`)
- Demo sign-in: `admin@bloodbank.in` / `Test@1234` — seeded accounts share this password, and the demo accounts skip the authenticator step.

## Screens

| Page | What it shows |
| --- | --- |
| Overview | Live donor, stock, request and expiry stats; coverage of the public directory |
| Donors | Search and filter by blood group, city and eligibility; register donor profiles; donation history |
| Inventory | Units by blood group, bank and city; 7-day expiry watch; add units and change status by role |
| Requests | Create patient requests, run compatibility matching, record donor matches, fulfil from stock |
| Donations | Record a donation (updates donor history and inventory in one transaction) and review history |
| Blood banks | 25 project centres with live stock plus the public licensed-facility directory (2,823 facilities) |
| Public data | 3,107 directory records, Tamil Nadu licence lists and World Bank health indicators |
| Login / Register | Email or phone sign-in, authenticator (TOTP) enrolment, and Google sign-in |

Light and dark themes are supported throughout.

## Roles

| Role | Can do |
| --- | --- |
| `admin` | Everything: donors, inventory, requests, matching, fulfilment, donations, bank records, deletions |
| `hospital` | View donors, add inventory, create and match requests, notify donors, record donations |
| `donor` | Browse donors, create requests, record donations |

Public visitors can read the overview, the licensed blood-bank directory and the public-data page; operational data needs a session.

## Stack

- PostgreSQL 16 on Neon
- Express 4 on Vercel serverless (`backend/src/app.js` exports the app; `src/start.js` is the local listener)
- React 18, Vite 5, Tailwind CSS
- JWT sessions, bcrypt password hashing, TOTP MFA (AES-256-GCM encrypted secrets)
- Firebase Authentication for Google sign-in, verified server-side with Firebase Admin
- GitHub Actions for CI

## Donor matching

Matching is driven by the `blood_compatibility` table (27 ABO/Rh donor-to-recipient rules), not exact group equality: O− is the universal donor, A+ recipients can receive from A+, A−, O+ and O−, and so on.

- `fn_find_matching_donors(request group, city)` returns compatible, available donors who have not donated in the last 90 days. Same-city donors come first, then exact group (score 100), universal O− (80) and other compatible groups (60). Each row includes `same_city`, `is_exact_match` and `compatibility_score`.
- `fn_find_matching_units(request group, city)` returns available, unexpired compatible units: local stock first, then exact group, then nearest expiry (FEFO).
- `GET /api/requests/:id/match` runs both functions in parallel, records the top donors in `request_donor_matches`, and moves a pending request to `matched`.
- The Match panel labels every donor and unit as **Same city** or **Other city**, so requests in cities with no donors still see compatible people elsewhere.

Migration `008_cross_city_matching.sql` holds the current definitions; earlier migrations kept matching inside the request city.

## Database design

Live schema (Neon): 15 tables, 5 views, 12 routines, 9 triggers, 43 indexes, plus `schema_migrations`.

- Domain tables: `users`, `donors`, `blood_groups`, `blood_compatibility`, `blood_banks`, `inventory`, `patients`, `blood_requests`, `donations`, `request_donor_matches`, `audit_log`, `public_blood_bank_directory`, `licensed_blood_banks`, `world_bank_indicators`.
- Views: `vw_eligible_donors`, `vw_available_stock`, `vw_expiring_soon`, `vw_pending_requests`, `vw_blood_bank_reference`.
- Routines: `fn_find_matching_donors`, `fn_find_matching_units`, `fn_haversine_km`, `fn_sync_donor_history`, `fn_update_donor_after_donation`, `fn_set_inventory_expiry`, `fn_set_updated_at`, `fn_audit_inventory`, `fn_audit_requests`, `fn_blood_bank_facility_type`, `sp_register_donation`, and procedure `sp_fulfill_request`.
- Triggers keep donation counts, inventory expiry, `updated_at` columns and audit rows in sync; `sp_fulfill_request` locks the request and units, checks compatibility and remaining units, and deducts stock atomically.
- Migrations `001`–`008` (including `001a_integrity_hardening`) add bank coordinates, the public directory, MFA, Firebase, World Bank indicators, licence data, integrity hardening and cross-city matching.

## API

All routes are under `/api`; operational routes need `Authorization: Bearer <token>`.

- Auth: `POST /auth/register`, `/auth/login`, `/auth/google`, `/auth/firebase`, `/auth/mfa/verify`; `GET /auth/me`
- Donors: `GET /donors`, `/donors/:id`, `/donors/:id/donations`; `PUT /donors/:id`; `DELETE /donors/:id` (admin)
- Inventory: `GET /inventory`, `/inventory/summary`, `/inventory/expiring`, `/inventory/:id`; `POST /inventory`; `PATCH /inventory/:id/status`
- Requests: `GET /requests`, `/requests/:id`, `/requests/:id/match`; `POST /requests`; `POST /requests/:id/notify/:donor_id`; `POST /requests/:id/fulfill` (admin); `PATCH /requests/:id/status`
- Donations: `GET /donations`; `POST /donations`
- Banks: `GET /banks`, `/banks/directory`, `/banks/:id`, `/banks/:id/stock`; `POST /banks`, `PATCH /banks/:id` (admin)
- Dashboard: `GET /dashboard/stats`, `/dashboard/network`, `/dashboard/stock`, `/dashboard/reports/donation-trends`, `/dashboard/reports/request-summary`, `/dashboard/reports/top-donors`
- Reference: `GET /reference/blood-banks`, `/reference/summary`, `/reference/world-bank`
- Health: `GET /health`

## Public data

- Operational records (users, donors, inventory, requests, donations) are seeded demo data, labelled as such in the UI.
- Licensed facilities come from the Blood Bank Directory published on data.gov.in (Government Open Data License – India) and Tamil Nadu licence lists; the directory lists licensed facilities, not live stock.
- Health indicators come from the World Bank Indicators API.

## Repository layout

```
Capstone/
  backend/    Express API, SQL schema, migrations, seed data, import scripts
  frontend/   React single-page dashboard
  docs/       Report diagrams and screenshots
Lab/          Lab exercises
Assignments/  Assignment submissions
```

## Local setup

Requirements: Node.js 20+, PostgreSQL 14+.

### Backend

```bash
cd Capstone/backend
npm install
cp .env.example .env      # DATABASE_URL and JWT_SECRET are required
npm run init-db           # schema + migrations + seed (seeds only when the database is empty)
npm start                 # http://localhost:5000
```

Useful scripts: `init-db:schema`, `init-db:seed`, `db:status`, `smoke`, plus the importers `db:import-public-directory`, `db:sync-data-gov-in`, `db:sync-world-bank`, `db:import-licensed-blood-banks`.

Google sign-in additionally needs `FIREBASE_PROJECT_ID` and `GOOGLE_APPLICATION_CREDENTIALS` pointing at a service-account JSON stored outside the repository (or `GOOGLE_APPLICATION_CREDENTIALS_JSON` when hosted).

### Frontend

```bash
cd Capstone/frontend
npm install
cp .env.example .env      # VITE_FIREBASE_* web app settings
npm run dev               # http://localhost:5173, proxies /api to port 5000
```

Set `VITE_PROXY_TARGET` in `Capstone/frontend/.env` if the API runs somewhere other than `http://localhost:5000`.

## Checks

- API health: `curl https://hemora-api.vercel.app/api/health` (expect `200` with a database timestamp)
- API smoke test: `cd Capstone/backend && BASE_URL=https://hemora-api.vercel.app npm run smoke`
- Frontend build: `cd Capstone/frontend && npm run build`
- Backend syntax: `cd Capstone/backend && find src -name '*.js' -print0 | xargs -0 -n1 node --check`
- GitHub Actions runs the backend check and frontend build on every push to `main` and on pull requests.

## Deployment notes

- Vercel imports `Capstone/backend/src/app.js` for the API and serves `Capstone/frontend` as the SPA; the frontend rewrites `/api/*` to the API deployment.
- Deployments are made with the Vercel CLI from `Capstone/backend` and `Capstone/frontend`; pushing to GitHub runs CI but does not deploy.
- The database is hosted on Neon; redeploying does not reseed or modify data. Apply new migrations to Neon before deploying code that depends on them.
- Firebase Admin credentials come from a file path locally or inline JSON when hosted. The frontend domain must be listed in Firebase Authentication → Settings → Authorized domains.
- Demo password-only sign-in is opt-in via `DEMO_PASSWORD_ONLY_EMAIL` and `DEMO_PASSWORD_ONLY_ALLOW_PRODUCTION`; leave them empty to require the authenticator step for every account.

## Documentation

- `Capstone/PROJECT_REPORT.md` — project report
- `Capstone/DATABASE_DEMO_GUIDE.md` — database walkthrough for the demo
- `Capstone/PRODUCT_REQUIREMENTS_DOCUMENT.md` — requirements
- `Capstone/REAL_DATA_INTEGRATION_GUIDE.md` — public data sources and imports
- `Capstone/docs/report-assets/` — architecture, ER and flow diagrams plus page screenshots
