# DevOps TODO — TestFlight + Vercel CI/CD

All code changes are done. The steps below are manual external tasks you must complete before CI/CD is fully operational.

---

## Step 1 — Neon Database (free tier)

1. Go to [neon.tech](https://neon.tech) → Sign up → **New Project** → name it `verifia-prod`
2. Open **Connection Details** in the Neon dashboard:
   - Copy the **Pooled connection** string → this is `DATABASE_URL`
     - Append `&pgbouncer=true&connection_limit=1` to it
   - Copy the **Direct connection** string → this is `DIRECT_URL`
   - Both strings look like: `postgresql://user:pass@ep-xxx.neon.tech/verifia_prod?sslmode=require`
3. Run the first migration locally:
   ```bash
   cd apps/backend
   DATABASE_URL="<direct-neon-url>" npx prisma migrate deploy
   ```

---

## Step 2 — Vercel: Backend project

1. Go to [vercel.com](https://vercel.com) → **New Project** → Import `VerifiA` repo
2. Set **Root Directory**: `apps/backend`
3. Set **Framework Preset**: Other
4. Add all environment variables (use production values):

   | Variable | Value |
   |---|---|
   | `DATABASE_URL` | Pooled Neon URL (with `&pgbouncer=true&connection_limit=1`) |
   | `DIRECT_URL` | Direct Neon URL |
   | `JWT_PRIVATE_KEY_PEM` | Your existing private key |
   | `JWT_PUBLIC_KEY_PEM` | Your existing public key |
   | `NODE_ENV` | `production` |
   | `VERIFIA_SKIP_ATTEST` | `false` |
   | `CORS_ORIGIN` | Your portal Vercel URL (e.g. `https://verifia.vercel.app`) |
   | `APPLE_TEAM_ID` | Your Apple Developer Team ID |
   | `APPLE_BUNDLE_ID` | `com.verifia.verifiaMobile` |
   | Any other keys from `.env.example` | Production values |

5. Click **Deploy** once to confirm it works
6. Go to **Settings → General** and copy:
   - **Project ID** → `VERCEL_PROJECT_ID_BACKEND`
   - **Team/Org ID** → `VERCEL_ORG_ID`

---

## Step 3 — Vercel: Portal project

1. In Vercel → **New Project** → Import same `VerifiA` repo (second project)
2. Set **Root Directory**: `apps/portal`
3. Add environment variables:

   | Variable | Value |
   |---|---|
   | `VITE_API_URL` | Your backend Vercel URL (e.g. `https://verifia-api.vercel.app`) |
   | `VITE_VERIFIER_API_KEY` | Your API key |

4. Click **Deploy** once to confirm it works
5. Copy the **Project ID** → `VERCEL_PROJECT_ID_PORTAL`

---

## Step 4 — Vercel token

1. Go to [vercel.com/account/tokens](https://vercel.com/account/tokens)
2. Click **Create** → name it `github-ci` → no expiry (or set one)
3. Copy the token → `VERCEL_TOKEN`

---

## Step 5 — Apple Developer Program

- Must be enrolled at [developer.apple.com/programs](https://developer.apple.com/programs/) ($99/yr)
- If not enrolled yet, enrollment takes up to 48 hours to process

---

## Step 6 — App Store Connect: Create the app

1. Go to [appstoreconnect.apple.com](https://appstoreconnect.apple.com)
2. **Apps → "+" → New App**
   - Platform: iOS
   - Bundle ID: `com.verifia.verifiaMobile`
   - SKU: `verifia-mobile`
3. After creation, go to **App Information** and copy the **Apple ID (numeric)** → `ITC_TEAM_ID`

---

## Step 7 — App Store Connect API Key

1. In App Store Connect → **Users and Access → Integrations → App Store Connect API**
2. Click **"+" → Name: `CI`**, Role: **App Manager**
3. Download the `.p8` file (only shown once — save it securely)
4. Note the **Key ID** shown → `ASC_KEY_ID`
5. Note the **Issuer ID** shown at the top of the page → `ASC_ISSUER_ID`
6. Base64-encode the key file:
   ```bash
   base64 -i AuthKey_XXXXXX.p8 | tr -d '\n'
   ```
   → `ASC_KEY_CONTENT`

---

## Step 8 — Distribution Certificate + Provisioning Profile

### Distribution Certificate
1. In Xcode → **Settings → Accounts** → select your Apple ID → **Manage Certificates**
2. Click **"+" → Apple Distribution**
3. Open **Keychain Access** → find the new "Apple Distribution: ..." certificate
4. Right-click → **Export** → save as `.p12`, set a password
5. Base64-encode it:
   ```bash
   base64 -i YourCert.p12 | tr -d '\n'
   ```
   → `CERTIFICATE_BASE64`
6. The password you set → `CERTIFICATE_PASSWORD`

### Provisioning Profile
1. In App Store Connect → **Certificates, Identifiers & Profiles → Profiles → "+"**
2. Select **App Store** → select `com.verifia.verifiaMobile` → select your Distribution Certificate
3. Name it (e.g. `VerifiA AppStore`) → note the exact name → `PROVISIONING_PROFILE_NAME`
4. Download the `.mobileprovision` file
5. Base64-encode it:
   ```bash
   base64 -i VerifiA_AppStore.mobileprovision | tr -d '\n'
   ```
   → `PROVISIONING_PROFILE_BASE64`

---

## Step 9 — Add all GitHub Secrets

Go to: **GitHub repo → Settings → Secrets and variables → Actions → New repository secret**

Add each of the following:

| Secret name | Where to get it |
|---|---|
| `VERCEL_TOKEN` | Step 4 |
| `VERCEL_ORG_ID` | Step 2 (Vercel backend project settings) |
| `VERCEL_PROJECT_ID_BACKEND` | Step 2 |
| `VERCEL_PROJECT_ID_PORTAL` | Step 3 |
| `DIRECT_URL_PROD` | Step 1 (direct Neon URL, used for migrations) |
| `ASC_KEY_ID` | Step 7 |
| `ASC_ISSUER_ID` | Step 7 |
| `ASC_KEY_CONTENT` | Step 7 (base64-encoded `.p8`) |
| `PROVISIONING_PROFILE_NAME` | Step 8 (exact profile name string) |
| `PROVISIONING_PROFILE_BASE64` | Step 8 (base64-encoded `.mobileprovision`) |
| `CERTIFICATE_BASE64` | Step 8 (base64-encoded `.p12`) |
| `CERTIFICATE_PASSWORD` | Step 8 (password set during `.p12` export) |
| `VERIFIA_API_URL_PROD` | Your backend Vercel URL (same as `VITE_API_URL`) |

---

## Step 10 — Verify CI/CD end-to-end

1. Push a commit to `main`
2. Go to **GitHub → Actions** and watch:
   - `backend` job → `deploy-backend` job (runs migration + deploys to Vercel)
   - `portal` job → `deploy-portal` job (deploys to Vercel)
   - `flutter` job → `testflight` job (builds `.ipa` + uploads to TestFlight)
3. In App Store Connect → **TestFlight** — build should appear within ~10 minutes after upload

---

## CI/CD flow summary

```
git push main
    ├── backend (test) ──→ deploy-backend (prisma migrate + vercel --prod)
    ├── portal (build) ──→ deploy-portal (vercel --prod)
    └── flutter (test) ──→ testflight (fastlane beta → TestFlight)
```

Deploy jobs only run on `push` to `main`. PRs only run the CI jobs (no deploy).
