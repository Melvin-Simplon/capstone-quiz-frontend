#!/usr/bin/env bash
# Puts the ZAP findings on the run's summary page, because the raw report is an
# artifact nobody downloads.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/workflows/lib.sh
source "${HERE}/lib.sh"

readonly RECAP_NAME="summarise-the-zap-report"
readonly REPORT="${REPORT:-report_md.md}"
readonly TARGET="${TARGET:?}"

write() {
    [[ -n "${GITHUB_STEP_SUMMARY:-}" ]] || return 0
    cat >> "$GITHUB_STEP_SUMMARY"
}

counts() {
    local level="$1"
    grep -c "^| ${level} |" "$REPORT" 2>/dev/null || printf '0'
}

heading() {
    write <<HEADER
## DAST : OWASP ZAP baseline

Scanned \`${TARGET}\` after deployment. Passive only: a static site has no form
to fuzz, so what this looks at is the response headers.

| Level | Alerts |
| --- | --- |
| High | $(counts High) |
| Medium | $(counts Medium) |
| Low | $(counts Low) |
| Informational | $(counts Informational) |

HEADER
}

body() {
    write <<'OPEN'
<details><summary>Full ZAP report</summary>

OPEN
    write < "$REPORT"
    write <<'CLOSE'

</details>
CLOSE
}

main() {
    task "zap : put the findings on the summary page"

    if [[ ! -f "$REPORT" ]]; then
        report_unreachable "zap" "${REPORT} was never written, nothing to summarise"
        recap "$RECAP_NAME"
        return 0
    fi

    heading
    body
    report_ok "zap" "findings written to the run summary"

    recap "$RECAP_NAME"
}

main "$@"
