#!/usr/bin/env bash

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/workflows/lib.sh
source "${HERE}/lib.sh"

readonly RECAP_NAME="deployment-token"
readonly SITE="${SITE:?}"
readonly GROUP="${GROUP:?}"

fetch_token() {
    az staticwebapp secrets list --name "$SITE" \
        --resource-group "$GROUP" \
        --query properties.apiKey -o tsv
}

main() {
    task "${SITE} : read the deployment token"

    local token
    if ! token=$(fetch_token) || [[ -z "$token" ]]; then
        die "$SITE" "no deployment token came back"
    fi

    printf '::add-mask::%s\n' "$token"
    printf 'token=%s\n' "$token" >> "$GITHUB_OUTPUT"
    report_ok "$SITE" "token read and masked"

    recap "$RECAP_NAME"
}

main "$@"
