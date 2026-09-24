#!/usr/bin/env bash

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/workflows/lib.sh
source "${HERE}/lib.sh"

readonly RECAP_NAME="close-the-vault"
readonly VAULT="${VAULT:?}"
readonly RUNNER_IP="${RUNNER_IP:?}"

close_vault() {
    task "${VAULT} : close the firewall again"
    if az keyvault network-rule remove --name "$VAULT" \
        --ip-address "${RUNNER_IP}/32" --only-show-errors >/dev/null; then
        report_changed "$VAULT" "closed to ${RUNNER_IP}"
    else
        report_failed "$VAULT" "could not remove the rule for ${RUNNER_IP}"
        hint "the address stays allowed on the vault until someone removes it"
        return 1
    fi
}

main() {
    close_vault || true
    recap "$RECAP_NAME"
}

main "$@"
