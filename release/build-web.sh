#!/bin/bash
# Builds jeyahyperstore.in: the customer web shop (Flutter web) plus the policy pages from site/
# (/privacy/, /terms/, /refunds/, /delivery/, /delete-account/, /contact/ keep their addresses).
#   release/build-web.sh            → build/web-site/   (then deploy, below)
#   npx wrangler@4 pages deploy build/web-site --project-name jeyahyperstore --branch main
# Cloudflare Pages serves index.html for any other path (no top-level 404.html), so links like
# /product/<slug> open the right page.
set -euo pipefail
cd "$(dirname "$0")/.."
OUT=build/web-site

(cd app && flutter build web --release --wasm)
rm -rf "$OUT" && mkdir -p "$OUT"
cp -R app/build/web/. "$OUT/"
for page in privacy terms refunds delivery delete-account contact; do
  cp -R "site/$page" "$OUT/$page"
done
cp site/styles.css site/logo.png "$OUT/"
cat > "$OUT/_headers" <<'EOF'
/*
  X-Content-Type-Options: nosniff
  Referrer-Policy: strict-origin-when-cross-origin
  Permissions-Policy: geolocation=(self), camera=(), microphone=()
/index.html
  Cache-Control: no-cache
/flutter_bootstrap.js
  Cache-Control: no-cache
/main.dart.*
  Cache-Control: no-cache
EOF
echo "Built $OUT ($(du -sh "$OUT" | cut -f1))"
