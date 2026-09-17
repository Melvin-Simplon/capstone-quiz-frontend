#!/usr/bin/env bash
# Resolves what to deploy to, by tag rather than by name, so that renaming or
# rebuilding the infrastructure leaves this untouched.
#
# Writes to GITHUB_OUTPUT: api_url, backend_origin, site, group, vault.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/workflows/lib.sh
source "${HERE}/lib.sh"

readonly RECAP_NAME="find-targets"
readonly TAGGED="[?tags.project=='simplon-quiz']"

# One query per value: asking for a pair returns a JSON array, which tsv prints
# one element per line rather than as two columns, so reading it into two
# variables silently leaves the second one empty.
#
# stdout carries the value and nothing else, the caller captures it.
query_one() {
    local command="$1" filter="$2"
    az "$command" list --query "${TAGGED} | ${filter}" -o tsv 2>/dev/null
}

# Resolves one component and reports on it. stdout carries the value.
resolve() {
    local label="$1" command="$2" filter="$3" value
    if ! value=$(query_one "$command" "$filter"); then
        report_unreachable "$label" "az ${command} list did not answer"
        return 1
    fi
    if [[ -z "$value" ]]; then
        report_failed "$label" "nothing tagged project=simplon-quiz, component=${label}"
        return 1
    fi
    report_ok "$label" "$value"
    printf '%s' "$value"
}

emit() {
    local key="$1" value="$2"
    printf '%s=%s\n' "$key" "$value" >> "$GITHUB_OUTPUT"
}

main() {
    task "azure : resolve the deployment targets by tag"

    local backend site group vault
    backend=$(resolve backend webapp "[?tags.component=='backend'].defaultHostName | [0]") || true
    site=$(resolve frontend staticwebapp "[?tags.component=='frontend'].name | [0]") || true
    group=$(resolve group staticwebapp "[?tags.component=='frontend'].resourceGroup | [0]") || true
    vault=$(resolve secrets keyvault "[?tags.component=='secrets'].name | [0]") || true

    if ! recap "$RECAP_NAME"; then
        exit 1
    fi

    emit api_url "https://${backend}/api"
    emit backend_origin "https://${backend}"
    emit site "$site"
    emit group "$group"
    emit vault "$vault"
}

main "$@"
