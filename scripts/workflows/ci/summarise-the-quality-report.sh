#!/usr/bin/env bash
# Tests and coverage on the run's summary page, because the sonar job's log is
# seven hundred lines and these numbers sit in the middle of it.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/workflows/lib.sh
source "${HERE}/lib.sh"

readonly RECAP_NAME="summarise-the-quality-report"
readonly TESTS="${TESTS:-test-results.json}"
readonly COVERAGE="${COVERAGE:-coverage/azure-quiz-frontend/coverage-summary.json}"
readonly PULL_REQUEST="${PULL_REQUEST:-}"
readonly PROPERTIES="${PROPERTIES:-sonar-project.properties}"

dashboard() {
    local key
    key=$(sed -n 's/^sonar\.projectKey=//p' "$PROPERTIES")
    local url="https://sonarcloud.io/dashboard?id=${key}"
    [[ -n "$PULL_REQUEST" ]] && url="${url}&pullRequest=${PULL_REQUEST}"
    printf '%s' "$url"
}

status() {
    python3 -c "
import json
print('ok' if json.load(open('${TESTS}'))['success'] else 'failed')
"
}

figures() {
    python3 -c "
import json
tests = json.load(open('${TESTS}'))
lines = json.load(open('${COVERAGE}'))['total']['lines']['pct']
print(f\"{tests['numPassedTests']} passed, {tests['numFailedTests']} failed, {lines}% of lines covered\")
"
}

table() {
    python3 -c "
import json
total = json.load(open('${COVERAGE}'))['total']
print('| Metric | Covered |')
print('| --- | --- |')
for name in ('lines', 'statements', 'functions', 'branches'):
    entry = total[name]
    print(f\"| {name.capitalize()} | {entry['pct']}% ({entry['covered']}/{entry['total']}) |\")
"
}

report() {
    summary "Quality" "vitest and SonarCloud" "$(status)" "$(figures)" <<TABLE
$(table)

[Open the SonarCloud dashboard]($(dashboard))
TABLE
}

main() {
    task "quality : put the tests and the coverage on the summary page"

    local missing=0
    for file in "$TESTS" "$COVERAGE"; do
        if [[ ! -f "$file" ]]; then
            report_unreachable "$file" "never written, nothing to summarise"
            missing=1
        fi
    done

    if (( missing == 0 )); then
        report
        report_ok "quality" "tests and coverage written to the run summary"
    fi

    recap "$RECAP_NAME"
}

main "$@"
