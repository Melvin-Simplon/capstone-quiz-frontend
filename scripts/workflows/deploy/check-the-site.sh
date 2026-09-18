#!/usr/bin/env bash
# Serving the site proves nothing about it being able to reach the backend,
# which is the pair of settings the build just baked in. This checks both.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/workflows/lib.sh
source "${HERE}/lib.sh"

readonly RECAP_NAME="check-the-site"
readonly SITE="${SITE:?}"
readonly GROUP="${GROUP:?}"
readonly API_URL="${API_URL:?}"
readonly API_KEY="${API_KEY:?}"

readonly ATTEMPTS=20
readonly PAUSE=10

# stdout carries the url and nothing else.
site_url() {
    local host
    host=$(az staticwebapp show --name "$SITE" \
        --resource-group "$GROUP" \
        --query defaultHostname -o tsv 2>/dev/null)
    [[ -n "$host" ]] || return 1
    printf 'https://%s' "$host"
}

wait_for_site() {
    local url="$1" code=""
    for _ in $(seq 1 "$ATTEMPTS"); do
        code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 "$url" || true)
        [[ "$code" == "200" ]] && { report_ok "$SITE" "${url} answered 200"; return 0; }
        sleep "$PAUSE"
    done
    report_failed "$SITE" "${url} answered ${code:-nothing} after $(( ATTEMPTS * PAUSE ))s"
    return 1
}

# A 200 is not enough: App Service answers 200 with its own welcome page on
# every path until an application is deployed over it, so the answer has to be
# JSON for this to mean anything.
check_backend_answers_json() {
    local origin="$1" api="${API_URL}/certifications" type
    type=$(curl -s -o /dev/null -w '%{content_type}' --max-time 20 \
        -H "X-Api-Key: ${API_KEY}" -H "Origin: ${origin}" "$api" || true)

    case "$type" in
        application/json*)
            report_ok "backend" "answers the site in JSON"
            ;;
        "")
            report_unreachable "backend" "no answer from ${api}"
            return 1
            ;;
        *)
            report_failed "backend" "answered ${type} on ${api}, not JSON. Is it deployed?"
            return 1
            ;;
    esac
}

# Silent without GITHUB_OUTPUT, so the script still runs by hand.
emit() {
    [[ -n "${GITHUB_OUTPUT:-}" ]] || return 0
    printf '%s=%s\n' "$1" "$2" >> "$GITHUB_OUTPUT"
}

main() {
    task "${SITE} : the site answers, and the backend answers it"

    local url
    if ! url=$(site_url); then
        die "$SITE" "the static web app has no hostname yet"
    fi
    emit url "$url"

    if wait_for_site "$url"; then
        check_backend_answers_json "$url" || true
    fi

    recap "$RECAP_NAME"
}

main "$@"
