#!/usr/bin/env bash
# Verify the externally published Static App over HTTPS.
#
#   bash deploy/verify.sh https://colab-controller-site.sugakura.ryokuryu.com
set -euo pipefail

BASE="${1:?usage: verify.sh https://<published-domain>}"
BASE="${BASE%/}"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
fail=0

pass() { echo "PASS $*"; }
bad()  { echo "FAIL $*" >&2; fail=1; }

status() { # status <method> <path> [extra curl args...]
  local method="$1" path="$2"; shift 2
  curl -sS --path-as-is -X "$method" -o /dev/null -w '%{http_code}' "$@" "$BASE$path"
}

expect() { # expect <want> <label> <method> <path> [extra curl args...]
  local want="$1" label="$2" method="$3" path="$4"; shift 4
  local got
  got="$(status "$method" "$path" "$@")"
  if [ "$got" = "$want" ]; then pass "$label ($got)"; else bad "$label (got $got, want $want)"; fi
}

expect_denied() { # never-served paths may be denied by the front proxy or runtime
  local label="$1" method="$2" path="$3"; shift 3
  local got
  got="$(status "$method" "$path" "$@")"
  case "$got" in
    400|403|404) pass "$label (denied: $got)";;
    *) bad "$label (got $got, want 400/403/404)";;
  esac
}

# TLS is validated by curl unless -k is passed (never pass -k here).
case "$BASE" in https://*) ;; *) bad "URL must be https"; esac

expect 200 'GET /' GET /
expect 200 'GET /index.html' GET /index.html
expect 200 'GET /privacy.html' GET /privacy.html
expect 200 'HEAD /' HEAD /
expect 404 'GET missing path' GET /definitely-not-present
expect 404 'GET README.md' GET /README.md
expect 404 'GET deploy script' GET /deploy/apply.sh
expect_denied 'GET .git/config' GET /.git/config
expect_denied 'GET .htaccess' GET /.htaccess
expect_denied 'GET traversal' GET /../etc/passwd
expect_denied 'GET encoded traversal' GET /%2e%2e/%2e%2e/etc/passwd
expect 405 'POST / is rejected' POST /

ctype="$(curl -sS -o /dev/null -D - "$BASE/" | tr -d '\r' | awk 'tolower($1)=="content-type:" {print $2; exit}')"
case "$ctype" in text/html*) pass "Content-Type / ($ctype)";; *) bad "Content-Type / ($ctype)";; esac

curl -sS "$BASE/" -o "$TMP/before"
curl -sS -X POST "$BASE/" -o /dev/null || true
curl -sS "$BASE/" -o "$TMP/after"
if cmp -s "$TMP/before" "$TMP/after"; then pass 'POST / does not change content'; else bad 'POST / changed content'; fi

if grep -q 'href="privacy.html"' "$TMP/before"; then
  pass 'homepage links to privacy.html'
else
  bad 'homepage is missing the privacy.html link'
fi
if curl -sS "$BASE/privacy.html" | grep -q 'href="index.html"'; then
  pass 'privacy page links back to the homepage'
else
  bad 'privacy page is missing the homepage link'
fi

if [ "$fail" -ne 0 ]; then
  echo "verification failed" >&2
  exit 1
fi
echo "verification passed: $BASE"
