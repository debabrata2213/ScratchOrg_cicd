#!/usr/bin/env bash
# scripts/dev-setup.sh
# ─────────────────────────────────────────────────────────────────
# Run this once to spin up a personal scratch org for local dev.
# Usage:
#   chmod +x scripts/dev-setup.sh
#   ./scripts/dev-setup.sh
#   ./scripts/dev-setup.sh --alias myOrg --days 10
# ─────────────────────────────────────────────────────────────────

set -euo pipefail

ALIAS="dev-$(git branch --show-current | sed 's/[^a-zA-Z0-9-]/-/g')"
DAYS=7

# Simple arg parsing
while [[ $# -gt 0 ]]; do
  case "$1" in
    --alias) ALIAS="$2"; shift 2;;
    --days)  DAYS="$2";  shift 2;;
    *) echo "Unknown arg: $1"; exit 1;;
  esac
done

echo ""
echo "╔══════════════════════════════════════════════╗"
echo "║  Scratch Org Local Dev Setup                 ║"
echo "╚══════════════════════════════════════════════╝"
echo "  Alias : $ALIAS"
echo "  Days  : $DAYS"
echo ""

# 1. Create scratch org from snapshot (falls back to shape def)
echo "▶ Creating scratch org..."
if sf org create scratch \
    --definition-file config/project-scratch-def-snapshot.json \
    --alias "$ALIAS" \
    --duration-days "$DAYS" \
    --set-default \
    --wait 15 2>/dev/null; then
  echo "  ✓ Created from snapshot"
else
  echo "  ⚠ Snapshot unavailable, falling back to shape definition..."
  sf org create scratch \
    --definition-file config/project-scratch-def.json \
    --alias "$ALIAS" \
    --duration-days "$DAYS" \
    --set-default \
    --wait 15
  echo "  ✓ Created from shape definition"

  # 2. Deploy metadata (only needed when not using a snapshot)
  echo ""
  echo "▶ Deploying metadata..."
  sf project deploy start \
    --source-dir force-app \
    --target-org "$ALIAS" \
    --wait 30 \
    --test-level NoTestRun
  echo "  ✓ Metadata deployed"

  # 3. Seed data (only needed when not using a snapshot)
  echo ""
  echo "▶ Seeding data..."
  sf data import tree \
    --plan data/seed-plan.json \
    --target-org "$ALIAS"
  echo "  ✓ Data seeded"
fi

# 4. Post-deploy setup (always run — idempotent)
echo ""
echo "▶ Running post-deploy setup..."
sf apex run \
  --file scripts/apex/post-deploy-setup.apex \
  --target-org "$ALIAS"
echo "  ✓ Setup complete"

# 5. Open org in browser
echo ""
echo "▶ Opening org in browser..."
sf org open --target-org "$ALIAS"

echo ""
echo "╔══════════════════════════════════════════════╗"
echo "║  ✓ Dev org ready!                            ║"
echo "╚══════════════════════════════════════════════╝"
echo ""
echo "  Push changes : sf project deploy start --source-dir force-app"
echo "  Run tests    : sf apex run test --test-level RunLocalTests --code-coverage"
echo "  Open org     : sf org open --target-org $ALIAS"
echo "  Delete org   : sf org delete scratch --target-org $ALIAS --no-prompt"
echo ""
