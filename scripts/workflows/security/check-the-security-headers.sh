#!/usr/bin/env bash
# The gate ZAP cannot be trusted to be: every header this site declares in
# staticwebapp.config.json has to come back on a real request.
#
# ZAP reports what it happens to have a passive rule for, and it has none for
# Referrer-Policy. This reads the configuration and asks for exactly what is in
# it, so adding a header there extends the check for free.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/workflows/lib.sh
source "${HERE}/lib.sh"

readonly RECAP_NAME="check-the-security-headers"
readonly SITE_URL="${SITE_URL:?}"
readonly CONFIG="public/staticwebapp.config.json"

# stdout carries one header name per line.
declared_headers() {
    python3 -c "
import json, sys
config = json.load(open('${CONFIG}'))
for name in config.get('globalHeaders', {}):
    print(name)
"
}

# stdout carries the response headers, lowercased.
fetch_headers() {
    curl -sSI --max-time 20 "$SITE_URL" | tr '[:upper:]' '[:lower:]'
}

check_one() {
    local name="$1" headers="$2"
    if grep -qi "^${name,,}:" <<< "$headers"; then
        report_ok "$name" "served"
        return 0
    fi
    report_failed "$name" "declared in ${CONFIG}, absent from the response"
    return 1
}

main() {
    task "${SITE_URL} : the declared security headers are actually served"

    local headers
    if ! headers=$(fetch_headers) || [[ -z "$headers" ]]; then
        die "$SITE_URL" "no answer, nothing to check"
    fi

    local name
    while read -r name; do
        check_one "$name" "$headers" || true
    done < <(declared_headers)

    recap "$RECAP_NAME"
}

main "$@"
