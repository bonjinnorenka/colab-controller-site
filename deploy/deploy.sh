#!/usr/bin/env bash
# Reproducible site deploy from a workstation: upload public assets and the
# deploy scripts over SSH/rsync, then run `sgctl apply` on the Sugakura host.
#
#   SG_HOST=umupumxy@183.90.183.154 bash deploy/deploy.sh
#
# Optional:
#   SG_REMOTE_DIR=sugakura-apps/colab-controller-site   (default)
#   SUGAKURA_HOME=~/sugakura-prod                       (passed to apply.sh)
#
# No CI/CD service, web server, database, secret, or cron entry is created for
# this app.  Updates only replace files in public/ and refresh the app spec.
set -euo pipefail

: "${SG_HOST:?set SG_HOST to the Sugakura SSH target (user@host)}"
SITE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REMOTE_DIR="${SG_REMOTE_DIR:-sugakura-apps/colab-controller-site}"

for f in public/index.html public/privacy.html; do
  [ -f "$SITE_DIR/$f" ] || { echo "missing $f" >&2; exit 1; }
done

ssh "$SG_HOST" "mkdir -p '$REMOTE_DIR/public' '$REMOTE_DIR/deploy'"
rsync -az --delete "$SITE_DIR/public/" "$SG_HOST:$REMOTE_DIR/public/"
rsync -az --delete "$SITE_DIR/deploy/" "$SG_HOST:$REMOTE_DIR/deploy/"
scp -q "$SITE_DIR/README.md" "$SG_HOST:$REMOTE_DIR/README.md"

if [ -n "${SUGAKURA_HOME:-}" ]; then
  ssh "$SG_HOST" "SUGAKURA_HOME='$SUGAKURA_HOME' bash '$REMOTE_DIR/deploy/apply.sh'"
else
  ssh "$SG_HOST" "bash '$REMOTE_DIR/deploy/apply.sh'"
fi
