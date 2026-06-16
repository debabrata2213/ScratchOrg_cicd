# Scratch Org CI/CD — Complete Guide
### A Basic Salesforce Project : Accounts & Contacts

---

## Table of Contents
1. [Project Overview](#1-project-overview)
2. [Repository Structure](#2-repository-structure)
3. [One-Time Setup](#3-one-time-setup)
4. [Developer Workflow (Day-to-Day)](#4-developer-workflow-day-to-day)
5. [CI/CD Pipeline Explained](#5-cicd-pipeline-explained)
6. [GitHub Secrets Reference](#6-github-secrets-reference)
7. [Apex Tests Guide](#7-apex-tests-guide)
8. [LWC Jest Tests Guide](#8-lwc-jest-tests-guide)
9. [Seed Data Guide](#9-seed-data-guide)
10. [Snapshot Lifecycle](#10-snapshot-lifecycle)
11. [Troubleshooting](#11-troubleshooting)
12. [Quick Command Reference](#12-quick-command-reference)

---

## 1. Project Overview

This project demonstrates a CI/CD setup for a Salesforce app using **scratch orgs** instead of sandboxes, built around two standard objects:

- **Account** — with a custom `AccountTier__c` picklist field (Gold / Silver / Bronze)
- **Contact** — with a custom `PriorityScore__c` number field (auto-calculated by trigger)

### What's included

| Component | Purpose |
|---|---|
| `AccountTier__c` field | Custom picklist on Account |
| `PriorityScore__c` field | Auto-scored field on Contact (email = +10, phone = +5) |
| `ContactTrigger` | Recalculates score on Contact insert / update / delete |
| `AccountService` | Apex class with `@AuraEnabled` methods for the LWC |
| `AccountServiceTest` | 5 Apex test methods with `@TestSetup` data |
| `accountDashboard` LWC | Component showing Accounts + Contacts with tier editor |
| `accountDashboard.test.js` | 4 Jest unit tests for the LWC |
| `AccountContactAppAccess` perm set | Field + object permissions |
| `data/` | Sanitised seed data (3 Accounts, 4 Contacts) |
| `scripts/apex/post-deploy-setup.apex` | Assigns perm set on fresh org |
| 4 GitHub Actions workflows | PR validation, QA deploy, Prod deploy, snapshot refresh |

### Branch strategy

```
feature/ABC-123  →  develop  →  main
      ↓                ↓          ↓
  scratch org       QA sandbox  Production
  (PR validation)   (on merge)  (on merge, with approval)
```

---

## 2. Repository Structure

```
account-contact-app/
│
├── .github/
│   └── workflows/
│       ├── pr-validation.yml         ← Runs on every PR
│       ├── deploy-qa.yml             ← Runs on merge to develop
│       ├── deploy-production.yml     ← Runs on merge to main (with approval)
│       ├── refresh-snapshot.yml      ← Runs weekly (Sunday 02:00 UTC)
│       └── cleanup-scratch-orgs.yml  ← Runs nightly (03:00 UTC)
│
├── config/
│   ├── project-scratch-def.json          ← Shape-based definition (first build / snapshot refresh)
│   └── project-scratch-def-snapshot.json ← Snapshot-based definition (day-to-day / CI PRs)
│
├── force-app/main/default/
│   ├── objects/
│   │   ├── Account/fields/AccountTier__c.field-meta.xml
│   │   └── Contact/fields/PriorityScore__c.field-meta.xml
│   ├── classes/
│   │   ├── AccountService.cls
│   │   ├── AccountService.cls-meta.xml
│   │   ├── AccountServiceTest.cls
│   │   └── AccountServiceTest.cls-meta.xml
│   ├── triggers/
│   │   ├── ContactTrigger.trigger
│   │   └── ContactTrigger.trigger-meta.xml
│   ├── lwc/
│   │   └── accountDashboard/
│   │       ├── accountDashboard.html
│   │       ├── accountDashboard.js
│   │       ├── accountDashboard.js-meta.xml
│   │       └── __tests__/
│   │           └── accountDashboard.test.js
│   └── permissionsets/
│       └── AccountContactAppAccess.permissionset-meta.xml
│
├── data/
│   ├── seed-plan.json    ← Import plan (parent → child order)
│   ├── accounts.json     ← 3 sanitised Account records
│   └── contacts.json     ← 4 sanitised Contact records
│
├── scripts/
│   ├── apex/
│   │   └── post-deploy-setup.apex   ← Assigns perm set, idempotent
│   └── dev-setup.sh                 ← One-command local dev setup
│
├── package.json          ← Jest config + npm scripts
└── sfdx-project.json
```

---

## 3. One-Time Setup

### 3.1 Prerequisites

```bash
# Salesforce CLI v2
npm install -g @salesforce/cli@latest
sf --version

# Node (for Jest)
node --version  # >= 18 recommended

# Git
git --version
```

### 3.2 Enable Dev Hub & Org Shape

In **Production** (or your dedicated Dev Hub org):
1. Setup → Quick Find → **Dev Hub** → Enable Dev Hub
2. Setup → Quick Find → **Org Shape** → Enable

### 3.3 Authenticate your orgs locally

```bash
# Dev Hub (Production)
sf org login web \
  --alias DevHub \
  --instance-url https://login.salesforce.com \
  --set-default-dev-hub

# QA Sandbox
sf org login web \
  --alias QASandbox \
  --instance-url https://test.salesforce.com
```

### 3.4 Create the Org Shape

```bash
# Creates a "shape" of production's edition + features + settings
sf org create shape --target-org DevHub

# Confirm it was created
sf org list shape --target-dev-hub DevHub
```

Copy the **Org ID** from `sf org display --target-org DevHub` and paste it into `config/project-scratch-def.json`:
```json
{
  "sourceOrg": "00D5g000000XXXXAAA"
}
```

### 3.5 Set up JWT authentication for CI (one-time per project)

This lets GitHub Actions authenticate to Salesforce without a browser.

**Step 1 — Generate a certificate and private key:**
```bash
mkdir -p .jwt
openssl genrsa -out .jwt/server.key 2048
openssl req -new -key .jwt/server.key -out .jwt/server.csr \
  -subj "/CN=sf-cicd/O=MyOrg/C=IN"
openssl x509 -req -sha256 -days 730 \
  -in .jwt/server.csr \
  -signkey .jwt/server.key \
  -out .jwt/server.crt

# NEVER commit .jwt/ — add to .gitignore immediately
echo ".jwt/" >> .gitignore
```

**Step 2 — Create a Connected App in Dev Hub:**
1. Setup → App Manager → New Connected App
2. Enable OAuth Settings
3. Callback URL: `http://localhost:1717/OauthRedirect`
4. Enable **Use digital signatures** → upload `.jwt/server.crt`
5. OAuth Scopes: `Manage user data via APIs (api)`, `Perform requests at any time (refresh_token)`
6. Save, then note the **Consumer Key**

**Step 3 — Pre-authorize the integration user's profile:**
1. Connected App → Manage → Edit Policies
2. Permitted Users: **Admin approved users are pre-authorized**
3. Save, then go to Profiles → assign the Connected App to your CI user's profile

**Step 4 — Store secrets in GitHub:**

Go to: GitHub repo → Settings → Secrets and Variables → Actions → New repository secret

| Secret name | Value |
|---|---|
| `SF_CONSUMER_KEY` | Consumer Key from the Connected App |
| `SF_DEVHUB_USERNAME` | Dev Hub user's email/username |
| `SF_QA_USERNAME` | QA sandbox user's email/username |
| `SF_PROD_USERNAME` | Production user's email/username |
| `SF_JWT_KEY` | Entire content of `.jwt/server.key` |

### 3.6 Set up GitHub Environments (for deployment protection)

Go to: GitHub repo → Settings → Environments

Create two environments:
- **`qa`** — no protection rules (auto-deploys on merge to `develop`)
- **`production`** — add "Required reviewers" (someone must approve before deploying to prod)

### 3.7 Install Node dependencies

```bash
npm install
```

---

## 4. Developer Workflow (Day-to-Day)

### Starting a new feature

```bash
# 1. Create a feature branch
git checkout develop
git pull origin develop
git checkout -b feature/ABC-123-account-tier-logic

# 2. Spin up a personal scratch org (one command)
chmod +x scripts/dev-setup.sh
./scripts/dev-setup.sh
# or with custom alias/duration:
./scripts/dev-setup.sh --alias abc-123 --days 10
```

The setup script automatically:
- Creates a scratch org from the latest snapshot
- Falls back to shape + full deploy if no snapshot is available
- Runs the post-deploy setup (perm sets, etc.)
- Opens the org in your browser

### Making changes

```bash
# Push your changes to the scratch org
sf project deploy start --source-dir force-app --target-org abc-123

# Or pull changes you made in the org back to your local files
sf project retrieve start --source-dir force-app --target-org abc-123

# Run Apex tests locally
sf apex run test \
  --target-org abc-123 \
  --test-level RunLocalTests \
  --code-coverage \
  --result-format human

# Run Jest tests
npm run test:unit
```

### Opening a PR

```bash
git add .
git commit -m "feat(account): add tier validation logic"
git push origin feature/ABC-123-account-tier-logic
# → Open PR against 'develop' on GitHub
# → pr-validation.yml triggers automatically
```

### Cleaning up

```bash
# When your PR is merged, delete your local scratch org
sf org delete scratch --target-org abc-123 --no-prompt
```

---

## 5. CI/CD Pipeline Explained

### Workflow 1: `pr-validation.yml` — runs on every PR

```
PR opened/updated
       │
       ├─── Job 1: LWC Jest Tests ──────────────────────────────────┐
       │     npm ci → npm run test:unit                              │
       │                                                             │
       └─── Job 2: Scratch Org Validation (needs Job 1 to pass) ────┘
             │
             ├─ sf org login jwt (authenticate Dev Hub)
             ├─ sf org create scratch (from snapshot; fallback to shape)
             ├─ sf project deploy start (deploy force-app)
             ├─ sf apex run (post-deploy-setup.apex)
             ├─ sf apex run test --test-level RunLocalTests --code-coverage
             └─ sf org delete scratch (ALWAYS, even on failure)
```

The key design decisions:
- **Jest runs first** (no org needed, fast). If Jest fails, we skip creating a scratch org entirely — saving time and org quota.
- **Snapshot fallback**: if the snapshot doesn't exist yet (e.g., first time setup), the workflow falls back to a full deploy from the shape definition.
- **Always delete**: the `if: always()` on the delete step ensures no scratch org is left behind, even if the pipeline crashes midway.

### Workflow 2: `deploy-qa.yml` — runs on merge to `develop`

Deploys to the QA sandbox using `RunSpecifiedTests` (faster than `RunLocalTests` since metadata was already validated in PR). Uses the `qa` GitHub environment.

### Workflow 3: `deploy-production.yml` — runs on merge to `main`

1. Waits for a manual approval (configured on the `production` GitHub environment)
2. Runs a `--dry-run` (check-only) deploy first
3. If check-only passes, runs the real deploy with `RunLocalTests`

### Workflow 4: `refresh-snapshot.yml` — weekly (Sunday 02:00 UTC)

```
Every Sunday
      │
      ├─ Create scratch org from Org Shape (clean slate, no drift)
      ├─ Deploy latest metadata from main
      ├─ Run post-deploy-setup.apex
      ├─ Import seed data
      ├─ Run Apex tests (smoke check)
      ├─ sf org create snapshot (async — polls every 5 min, up to 2 hours)
      ├─ Update config/project-scratch-def-snapshot.json in repo
      ├─ Prune old snapshots (keep latest 3)
      └─ Delete the build scratch org
```

### Workflow 5: `cleanup-scratch-orgs.yml` — nightly (03:00 UTC)

Deletes expired scratch orgs to prevent hitting Dev Hub limits.

---

## 6. GitHub Secrets Reference

| Secret | Used in | Description |
|---|---|---|
| `SF_CONSUMER_KEY` | All workflows | OAuth Consumer Key from Connected App |
| `SF_JWT_KEY` | All workflows | Private key file content (PEM format) |
| `SF_DEVHUB_USERNAME` | PR validation, snapshot refresh, cleanup | Dev Hub admin username |
| `SF_QA_USERNAME` | QA deploy | QA sandbox username |
| `SF_PROD_USERNAME` | Production deploy | Production username |

---

## 7. Apex Tests Guide

### `AccountServiceTest.cls` — what each test covers

| Test method | What it validates |
|---|---|
| `testGetAccountsWithContacts_returnsData` | Returns accounts with related contacts correctly |
| `testUpdateAccountTier_updatesSuccessfully` | `updateAccountTier()` persists the new picklist value |
| `testRecalculatePriorityScores_emailAndPhone` | Email (10) + phone (5) = score of 15 |
| `testRecalculatePriorityScores_noEmailNoPhone` | No email, no phone = score of 0 |
| `testUpdateAccountTier_invalidTier_throwsException` | Invalid picklist value throws `DmlException` |

### Running Apex tests locally

```bash
# Run all tests in class
sf apex run test \
  --target-org your-scratch-org-alias \
  --class-names AccountServiceTest \
  --code-coverage \
  --result-format human

# Run all local tests (everything not in managed packages)
sf apex run test \
  --target-org your-scratch-org-alias \
  --test-level RunLocalTests \
  --code-coverage \
  --result-format human \
  --output-dir reports/apex

# Check code coverage
# Results in reports/apex/test-result-codecoverage.json
```

### Code coverage requirement

Salesforce requires **75% code coverage** minimum to deploy. The pipeline runs with `--code-coverage` on every PR. If coverage drops below 75%, the deploy step will fail with a clear error.

---

## 8. LWC Jest Tests Guide

### `accountDashboard.test.js` — what each test covers

| Test | What it validates |
|---|---|
| `renders a card for each account` | Correct number of `.account-card` elements rendered |
| `shows account names` | Account names appear in rendered HTML |
| `shows contact priority score` | `PriorityScore__c` value is rendered correctly |
| `shows error message on API failure` | Error state renders the `.slds-text-color_error` element |

### Running Jest tests locally

```bash
# Run once
npm run test:unit

# Watch mode (re-runs on file save)
npm run test:unit:watch

# With coverage report
npm run test:unit -- --coverage
# Coverage report at: coverage/lcov-report/index.html
```

### Jest mock pattern

Apex calls are mocked at the top of each test file using the `{ virtual: true }` pattern, because the `@salesforce/apex/*` imports don't exist in a Node environment:

```javascript
jest.mock('@salesforce/apex/AccountService.getAccountsWithContacts', () => ({
    default: jest.fn()
}), { virtual: true });
```

Then in each test:
```javascript
getAccountsWithContacts.default.mockResolvedValue(MOCK_ACCOUNTS);
// or for error testing:
getAccountsWithContacts.default.mockRejectedValue({ body: { message: 'Error' } });
```

---

## 9. Seed Data Guide

### Files

- `data/seed-plan.json` — defines import order (Accounts first, then Contacts)
- `data/accounts.json` — 3 Account records with `referenceId` keys
- `data/contacts.json` — 4 Contact records referencing Account `referenceId` via `@AccountRef1`

### Import order matters

Contacts reference Accounts, so Accounts must be imported first. The plan file controls this:

```json
[
  { "sobject": "Account", "saveRefs": true,  "files": ["accounts.json"] },
  { "sobject": "Contact", "resolveRefs": true, "files": ["contacts.json"] }
]
```

`saveRefs: true` on Account tells the CLI to remember the new real IDs.
`resolveRefs: true` on Contact tells it to replace `@AccountRef1` with the actual ID.

### Import command

```bash
sf data import tree \
  --plan data/seed-plan.json \
  --target-org your-scratch-org-alias
```

### Exporting updated seed data

If you add records in your scratch org and want to refresh the seed files:

```bash
sf data export tree \
  --query "SELECT Id, Name, AccountTier__c, Industry, Phone, BillingCity, BillingState FROM Account" \
  --target-org your-scratch-org-alias \
  --output-dir data \
  --plan

sf data export tree \
  --query "SELECT Id, FirstName, LastName, Email, Phone, AccountId FROM Contact" \
  --target-org your-scratch-org-alias \
  --output-dir data
```

**Always review exported data before committing** — make sure no real names, emails, or phone numbers are present.

---

## 10. Snapshot Lifecycle

### Current snapshot

The active snapshot name is always in `config/project-scratch-def-snapshot.json`. The refresh workflow updates this file automatically.

### Manual snapshot refresh

If you need to refresh the snapshot outside the weekly schedule:

```bash
# Trigger the workflow manually from GitHub Actions tab
# Repository → Actions → "Refresh Snapshot" → Run workflow
```

Or locally:

```bash
# 1. Create a build scratch org
sf org create scratch \
  --definition-file config/project-scratch-def.json \
  --alias snapshot-build \
  --duration-days 7

# 2. Deploy + setup + seed
sf project deploy start --source-dir force-app --target-org snapshot-build --wait 30
sf apex run --file scripts/apex/post-deploy-setup.apex --target-org snapshot-build
sf data import tree --plan data/seed-plan.json --target-org snapshot-build

# 3. Create snapshot
sf org create snapshot \
  --target-dev-hub DevHub \
  --source-org snapshot-build \
  --snapshot-name acct-contact-baseline-vX

# 4. Wait for it to become Active
sf org list snapshot --target-dev-hub DevHub

# 5. Update config/project-scratch-def-snapshot.json
# 6. Delete build org
sf org delete scratch --target-org snapshot-build --no-prompt
```

### Snapshot limits

Dev Hub has limits on both the number of active snapshots and the size of the source org. If you hit limits, delete old snapshots:

```bash
sf org list snapshot --target-dev-hub DevHub
sf org delete snapshot --target-dev-hub DevHub --snapshot old-snapshot-name --no-prompt
```

---

## 11. Troubleshooting

### Scratch org creation fails: "Insufficient privileges"
→ Your Dev Hub user needs the **Salesforce DX** permission set or System Administrator profile.

### "No snapshot found" error in CI
→ The snapshot was deleted or expired. Trigger the `refresh-snapshot.yml` workflow manually.

### Apex test failure: "FIELD_INTEGRITY_EXCEPTION on AccountTier__c"
→ The `AccountTier__c` field wasn't deployed before tests ran. Check the deploy step logs.

### JWT auth fails: "invalid_client_id"
→ The Consumer Key secret is wrong, or the Connected App isn't activated yet. Wait a few minutes after creating the Connected App before using JWT.

### Code coverage below 75%
→ Add more test methods to `AccountServiceTest.cls` covering additional branches.

### "Snapshot status: Error" during refresh
→ Common causes: org has unsupported metadata, active sessions, or data volume too large. Check Dev Hub setup → scratch org snapshots for error details.

### Scratch org limit hit in CI
→ The cleanup workflow may be behind. Delete manually:
```bash
sf org list --target-dev-hub DevHub
sf org delete scratch --target-org <username> --no-prompt
```

---

## 12. Quick Command Reference

```bash
# ── Local dev ────────────────────────────────────────────────────
./scripts/dev-setup.sh                            # Full scratch org setup (one command)
./scripts/dev-setup.sh --alias my-org --days 14  # Custom alias / duration

sf project deploy start --source-dir force-app    # Push local changes to default org
sf project retrieve start --source-dir force-app  # Pull org changes to local

sf apex run test \
  --test-level RunLocalTests \
  --code-coverage --result-format human           # Run all Apex tests

npm run test:unit                                 # Run LWC Jest tests
npm run test:unit:watch                           # Jest watch mode

sf org open                                       # Open default org in browser
sf org list                                       # List all authenticated orgs
sf org delete scratch --target-org <alias> --no-prompt  # Delete scratch org

# ── Snapshot management ──────────────────────────────────────────
sf org list snapshot --target-dev-hub DevHub      # List all snapshots
sf org create snapshot \                          # Create new snapshot
  --target-dev-hub DevHub \
  --source-org <alias> \
  --snapshot-name <name>

# ── Org Shape ────────────────────────────────────────────────────
sf org create shape --target-org SourceOrg        # Create org shape
sf org list shape --target-dev-hub DevHub         # List shapes

# ── Data ─────────────────────────────────────────────────────────
sf data import tree --plan data/seed-plan.json    # Import seed data
sf data export tree --query "SELECT..." --plan    # Export data

# ── Auth ─────────────────────────────────────────────────────────
sf org login web --alias DevHub --set-default-dev-hub
sf org login jwt \
  --client-id $KEY \
  --jwt-key-file server.key \
  --username $USER \
  --alias DevHub \
  --set-default-dev-hub
```
