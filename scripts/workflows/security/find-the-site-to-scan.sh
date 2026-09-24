#!/usr/bin/env bash

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/workflows/lib.sh
source "${HERE}/lib.sh"

readonly RECAP_NAME="find-the-site-to-scan"
readonly QUERY="[?tags.project=='simplon-quiz' && tags.component=='frontend'].defaultHostname | [0]"

emit() {
    [[ -n "${GITHUB_OUTPUT:-}" ]] || return 0
    printf '%s=%s\n' "$1" "$2" >> "$GITHUB_OUTPUT"
}

main() {
    task "azure : find the deployed site to scan"

    local host
    if ! host=$(az staticwebapp list --query "$QUERY" -o tsv); then
        report_unreachable "azure" "az staticwebapp list did not answer"
        recap "$RECAP_NAME"
        return
    fi

    if [[ -z "$host" ]]; then
        report_skipped "frontend" "no static web app tagged project=simplon-quiz, component=frontend"
        hint "the environment is not built, so there is nothing to scan"
        summary "dast" "OWASP ZAP" "skipping" "no site tagged project=simplon-quiz" <<<'The environment does not exist, so there was nothing to scan. This is not a failed scan.'
        emit url ""
        recap "$RECAP_NAME"
        return
    fi

    report_ok "frontend" "https://${host}"
    emit url "https://${host}"
    recap "$RECAP_NAME"
}

main "$@"
