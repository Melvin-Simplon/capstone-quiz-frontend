import os
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent.parent))
from lib import Report  # noqa: E402

SUBSTITUTIONS = {
    "src/environments/environment.ts": (
        ("https://REPLACE_WITH_PROD_API_URL/api", "API_URL"),
        ("__BACKEND_API_KEY__", "API_KEY"),
    ),
    "public/staticwebapp.config.json": (
        ("__BACKEND_ORIGIN__", "BACKEND_ORIGIN"),
    ),
}

def read_required(report, variable):
    value = os.environ.get(variable)
    if not value:
        report.fatal("runner", f"{variable} is not set")
        return None
    return value

def substitute(report, path, pairs):
    if not path.exists():
        report.fatal(str(path), "file not found")
        return False

    text = path.read_text()
    for placeholder, variable in pairs:
        if placeholder not in text:
            report.fatal(str(path), f"{placeholder} is missing, nothing was substituted")
            return False
        value = read_required(report, variable)
        if value is None:
            return False
        text = text.replace(placeholder, value)

    path.write_text(text)
    report.changed(str(path), f"{len(pairs)} value(s) substituted")
    return True

def main():
    report = Report("point-the-build")
    report.task("build : bake in what the bundle cannot read at runtime")

    for name, pairs in SUBSTITUTIONS.items():
        substitute(report, pathlib.Path(name), pairs)

    return report.recap()

if __name__ == "__main__":
    sys.exit(main())
