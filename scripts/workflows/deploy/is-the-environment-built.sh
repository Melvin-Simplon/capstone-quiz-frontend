#!/usr/bin/env bash
# Answers one question: is there an environment to deploy to at all.
#
# The environment is created and destroyed between sessions, so finding nothing
# is a normal state here: there is nothing to deploy, which is not the same as a
# deployment that did not work. That case reports skipping and hands the
# decision back through the found output, rather than failing the run.
#
# It deliberately asks nothing more. Terraform builds the site, the backend and
# the vault together, so either the environment is there or it is not. An
# environment that exists but is missing a piece is a real fault, and
# find-targets.sh still fails on it with the piece named.
#
# Writes to GITHUB_OUTPUT: found.

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
