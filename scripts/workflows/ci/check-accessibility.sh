#!/usr/bin/env bash
# axe-core against the built site, served locally. The rules it checks need a
# rendered page, so a component test would not answer the same question.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/workflows/lib.sh
source "${HERE}/lib.sh"

readonly RECAP_NAME="check-accessibility"
readonly SITE="${SITE:-dist/azure-quiz-frontend/browser}"
readonly PORT="${PORT:-4173}"
readonly URL="http://127.0.0.1:${PORT}"
readonly REPORT="${REPORT:-axe-results.json}"

SERVER_PID=""

serve() {
    npx --yes http-server "$SITE" -p "$PORT" -s --proxy "${URL}?" &
    SERVER_PID=$!
    for _ in $(seq 1 30); do
        if curl -sf -o /dev/null "$URL"; then
            report_ok "server" "${URL} answers"
            return 0
        fi
        sleep 1
    done
    report_unreachable "server" "${URL} never answered"
    return 1
}

stop() {
    [[ -n "$SERVER_PID" ]] && kill "$SERVER_PID" 2>/dev/null || true
}
trap stop EXIT

scan() {
    npx --yes @axe-core/cli "$URL" --exit --save "$REPORT" --stdout
}

violations() {
    python3 -c "
import json
results = json.load(open('${REPORT}'))
print(sum(len(page.get('violations', [])) for page in results))
" 2>/dev/null || printf '0'
}

table() {
    python3 -c "
import json
rows = []
for page in json.load(open('${REPORT}')):
    for v in page.get('violations', []):
        rows.append((v['impact'] or 'unknown', v['id'], len(v['nodes']), v['help']))
if not rows:
    print('No violation.')
else:
    print('| Impact | Rule | Elements | What it is |')
    print('| --- | --- | --- | --- |')
    for impact, rule, count, help_text in sorted(rows):
        print(f'| {impact} | \`{rule}\` | {count} | {help_text} |')
"
}

report() {
    local count="$1" state="$2"
    summary "Accessibility" "axe-core" "$state" "${count} violation(s) on ${URL}" <<TABLE
$(table)
TABLE
}

main() {
    task "axe : the built site against the axe-core rules"

    serve || die "server" "nothing to scan"

    local state="ok"
    if ! scan; then
        state="failed"
    fi

    local count
    count=$(violations)
    report "$count" "$state"

    if [[ "$state" == "ok" ]]; then
        report_ok "axe" "no violation"
    else
        report_failed "axe" "${count} violation(s), see the run summary"
    fi

    recap "$RECAP_NAME"
}

main "$@"
