#!/usr/bin/env bash

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/workflows/lib.sh
source "${HERE}/lib.sh"

readonly RECAP_NAME="is-the-environment-built"

main() {
    task "azure : is the environment built"

    local count
    if ! count=$(az resource list --tag project=simplon-quiz --query 'length(@)' -o tsv); then
        report_unreachable "azure" "az resource list did not answer"
        recap "$RECAP_NAME"
        return
    fi

    if [[ "$count" -eq 0 ]]; then
        report_skipped "azure" "nothing tagged project=simplon-quiz"
        hint "the environment is not built: run make all from the infrastructure repository"
        printf 'found=false\n' >> "$GITHUB_OUTPUT"
        summary "deploy" "azure" "skipping" "no resource tagged project=simplon-quiz" <<<'The environment does not exist, so there was nothing to deploy to. This is not a failed deployment.'
        recap "$RECAP_NAME"
        return
    fi

    report_ok "azure" "${count} resources tagged project=simplon-quiz"
    printf 'found=true\n' >> "$GITHUB_OUTPUT"
    recap "$RECAP_NAME"
}

main "$@"
