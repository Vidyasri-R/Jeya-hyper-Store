#!/bin/bash
# Moves the API onto jeyahyperstore.in — run once, in your own terminal, from the repo root:
#   release/render-domain-switch.sh
# 1. render.yaml: api.jeyahyperstore.in as the service's custom domain; the staff and website
#    addresses allowed to call the API from a browser (CORS).
# 2. Render API: product-image base URL → https://cdn.jeyahyperstore.in (a secret-style setting,
#    so it lives in Render, not in render.yaml). Uses the Render key saved in ~/.claude.json; the
#    key is sent only to api.render.com and never printed.
# 3. Commit + push → Render's blueprint sync applies it and redeploys (~1 min).
set -euo pipefail
cd "$(dirname "$0")/.."

perl -0pi -e 's{(      - key: CORS_ORIGINS\n        value: )https://jeya-staff\.pages\.dev\n}{$1https://jeya-staff.pages.dev,https://staff.jeyahyperstore.in,https://jeyahyperstore.in,https://www.jeyahyperstore.in\n}' render.yaml
grep -q 'api.jeyahyperstore.in' render.yaml || perl -0pi -e 's{(    healthCheckPath: /health\n)}{$1    domains:\n      - api.jeyahyperstore.in\n}' render.yaml
git --no-pager diff --stat render.yaml

node --input-type=module -e "
import fs from 'node:fs'; import os from 'node:os';
const auth = JSON.parse(fs.readFileSync(os.homedir() + '/.claude.json', 'utf8')).mcpServers?.render?.headers?.Authorization;
if (!auth) { console.error('No Render key saved in ~/.claude.json'); process.exit(1); }
const res = await fetch('https://api.render.com/v1/services/srv-davs2p60tbcc73f68iqg/env-vars/R2_PUBLIC_BASE_URL', {
  method: 'PUT', headers: { Authorization: auth, 'Content-Type': 'application/json', Accept: 'application/json' },
  body: JSON.stringify({ value: 'https://cdn.jeyahyperstore.in' }) });
console.log('R2_PUBLIC_BASE_URL →', res.ok ? 'https://cdn.jeyahyperstore.in' : res.status + ' ' + (await res.text()).slice(0, 200));
if (!res.ok) process.exit(1);
"

git add render.yaml
git commit -q -m "API on api.jeyahyperstore.in; allow the jeyahyperstore.in sites to call it"
git push -q
echo "Done. Render redeploys in about a minute; https://api.jeyahyperstore.in/health answers once its certificate is issued."
