#!/usr/bin/env bash
# Register/update the colab-controller-site Static App on the Sugakura host.
# Run this ON the Sugakura host (BOX1), from the deployed site directory.
#
#   SUGAKURA_HOME=~/sugakura-prod bash deploy/apply.sh
#
# The site assets are installed into a directory that contains public files
# only.  The Sugakura app spec points its static runtime `root` at that
# directory, so repository metadata, deploy scripts, and logs can never be
# served by the gateway.
set -euo pipefail

SITE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PUBLIC="$SITE_DIR/public"
SG_HOME="${SUGAKURA_HOME:-$HOME/sugakura-prod}"
SGCTL="$SG_HOME/remote/sgctl"
APP_ID="colab-controller-site"
APP_ROOT="${APP_ROOT:-$HOME/sugakura-apps/$APP_ID/public}"
SPEC_TEMPLATE="$SITE_DIR/deploy/sgctl.colab-controller-site.json"

for f in index.html privacy.html; do
  [ -f "$PUBLIC/$f" ] || { echo "missing public/$f" >&2; exit 1; }
done
[ -x "$SGCTL" ] || { echo "sgctl not executable: $SGCTL" >&2; exit 1; }
[ -f "$SPEC_TEMPLATE" ] || { echo "missing spec: $SPEC_TEMPLATE" >&2; exit 1; }

# The static root must exist and contain only publishable files before the
# gateway validates/registers the app.
install -d -m 0755 "$APP_ROOT"
if [ "$(readlink -f "$PUBLIC")" != "$(readlink -f "$APP_ROOT")" ]; then
  find "$APP_ROOT" -mindepth 1 -delete
  cp -a "$PUBLIC"/. "$APP_ROOT"/
fi
chmod -R u+rwX,go+rX "$APP_ROOT"

SPEC="$(mktemp)"
trap 'rm -f "$SPEC"' EXIT
python3 - "$SPEC_TEMPLATE" "$SPEC" "$APP_ROOT" <<'PY'
import json
import sys

src, dst, root = sys.argv[1:4]
with open(src, encoding="utf-8") as f:
    spec = json.load(f)
spec["root"] = root
with open(dst, "w", encoding="utf-8") as f:
    json.dump(spec, f, indent=2)
    f.write("\n")
PY

echo "== applying $APP_ID (root: $APP_ROOT) =="
"$SGCTL" apply "$SPEC"
