"""Checks the built document against the policy the site will serve it with.

Static Web Apps applies the policy when it serves the page, and nothing else
does: ng serve sends no headers, so a document the browser will refuse still
passes every build and every test.
"""

import json
import pathlib
import re
import sys
from urllib.parse import urlparse

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent.parent))
from lib import Report  # noqa: E402

CONFIG = pathlib.Path("public/staticwebapp.config.json")
DOCUMENT = pathlib.Path("dist/azure-quiz-frontend/browser/index.html")


def read_directives(config):
    policy = json.loads(config.read_text())["globalHeaders"]["Content-Security-Policy"]
    return {
        parts[0]: parts[1:]
        for parts in (d.split() for d in policy.split(";") if d.strip())
    }


def refused_inline_script(document, directives):
    """An onload or onerror attribute is script the policy has no way to tell
    apart from an injection, so it never runs. Angular writes one when it defers
    the stylesheet, which silently costs the whole sheet."""
    if "'unsafe-inline'" in directives.get("script-src", []):
        return []

    refused = [
        f"inline event handler: {handler.strip()}"
        for handler in re.findall(r'\son[a-z]+\s*=\s*"[^"]*"', document)
    ]
    for opening, body in re.findall(r"<script([^>]*)>(.*?)</script>", document, re.S):
        if "src=" not in opening and body.strip():
            refused.append("inline script body")
    return refused


def refused_origins(document, directives):
    allowed = {
        host
        for values in directives.values()
        for host in values
        if host.startswith("http")
    }
    refused = []
    for url in re.findall(r'(?:href|src)="(https?://[^"]+)"', document):
        parsed = urlparse(url)
        origin = f"{parsed.scheme}://{parsed.netloc}"
        if origin not in allowed:
            refused.append(f"no directive allows {origin}: {url}")
    return refused


def main():
    report = Report("policy-check")
    report.task("build : check the document against the policy it will be served with")

    for path in (CONFIG, DOCUMENT):
        if not path.exists():
            report.fatal(str(path), "file not found")
            return report.recap()

    directives = read_directives(CONFIG)
    document = DOCUMENT.read_text()

    refused = refused_inline_script(document, directives)
    refused += refused_origins(document, directives)

    if refused:
        report.fatal(str(DOCUMENT), f"{len(refused)} thing(s) the policy refuses")
        for line in refused:
            report.hint(line)
    else:
        report.ok(str(DOCUMENT), "holds nothing the policy refuses")

    return report.recap()


if __name__ == "__main__":
    sys.exit(main())
