#!/usr/bin/env bash
# Reading a secret goes through the data plane, which the vault firewall
# filters. The door is opened for this runner here and closed by
# close-the-vault.sh, so the allowed address never outlives the job.
#
# Writes to GITHUB_OUTPUT: runner_ip, value.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/workflows/lib.sh
source "${HERE}/lib.sh"

readonly RECAP_NAME="read-api-key"
readonly VAULT="${VAULT:?}"
# The rule is not in force the moment the call returns.
readonly SETTLE=15

emit() {
    local key="$1" value="$2"
    printf '%s=%s\n' "$key" "$value" >> "$GITHUB_OUTPUT"
}

# stdout carries the address and nothing else.
runner_address() {
    curl -fsS --max-time 15 https://api.ipify.org
}

# The address is recorded before the rule is added, on purpose: the closing step
# keys off that output, and an address allowed but never recorded would stay
# allowed after the job ends.
open_vault_to() {
    local ip="$1"
    emit runner_ip "$ip"
    if az keyvault network-rule add --name "$VAULT" \
        --ip-address "${ip}/32" --only-show-errors >/dev/null; then
        report_changed "$VAULT" "opened to ${ip}"
        sleep "$SETTLE"
    else
        report_failed "$VAULT" "could not allow ${ip}"
        return 1
    fi
}

read_secret() {
    local key
    if ! key=$(az keyvault secret show --vault-name "$VAULT" \
        --name backend-api-key --query value -o tsv 2>/dev/null) || [[ -z "$key" ]]; then
        report_failed "$VAULT" "backend-api-key could not be read"
        hint "the firewall may not have settled, or the identity lacks the data plane role"
        return 1
    fi
    printf '::add-mask::%s\n' "$key"
    emit value "$key"
    report_ok "$VAULT" "backend-api-key read and masked"
}

main() {
    task "${VAULT} : open the firewall and read the API key"

    local ip
    if ! ip=$(runner_address); then
        die "api.ipify.org" "could not determine this runner's address"
    fi
    report_ok "runner" "address ${ip}"

    open_vault_to "$ip" || true
    [[ "$RECAP_FAILED" -eq 0 ]] && { read_secret || true; }

    recap "$RECAP_NAME"
}

main "$@"
