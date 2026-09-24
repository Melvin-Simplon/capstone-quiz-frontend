import os
import sys

_COLOUR = bool(
    (sys.stderr.isatty() or os.environ.get("GITHUB_ACTIONS"))
    and not os.environ.get("NO_COLOR")
)

_OUTCOMES = {
    "ok": ("0;32", "ok"),
    "changed": ("0;33", "changed"),
    "unreachable": ("1;31", "unreachable"),
    "fatal": ("0;31", "failed"),
    "skipping": ("0;36", "skipped"),
}

def _paint(colour, text):
    return f"\033[{colour}m{text}\033[0m" if _COLOUR else text

class Report:

    def __init__(self, name):
        self.name = name
        self.counts = dict.fromkeys(_OUTCOMES, 0)

    def task(self, title):
        line = f"TASK [{title}] "
        print("\n" + _paint("1", line + "*" * max(3, 72 - len(line))), file=sys.stderr)

    def _emit(self, outcome, host, message):
        self.counts[outcome] += 1
        colour = _OUTCOMES[outcome][0]
        print(f"{_paint(colour, f'{outcome}:'.ljust(12))} [{host}] {message}", file=sys.stderr)

    def ok(self, host, message):
        self._emit("ok", host, message)

    def changed(self, host, message):
        self._emit("changed", host, message)

    def skipping(self, host, message):
        self._emit("skipping", host, message)

    def unreachable(self, host, message):
        self._emit("unreachable", host, message)

    def fatal(self, host, message):
        self._emit("fatal", host, message)

    def hint(self, message):
        print(f"             {message}", file=sys.stderr)

    def recap(self):
        print("\n" + _paint("1", "PLAY RECAP " + "*" * 62), file=sys.stderr)

        cells = []
        for outcome, (colour, label) in _OUTCOMES.items():
            count = self.counts[outcome]
            cells.append(_paint(colour, f"{label}={count:<3}"))

        print(f"{self.name:<22} : " + " ".join(cells), file=sys.stderr)
        return 1 if self.counts["fatal"] or self.counts["unreachable"] else 0
