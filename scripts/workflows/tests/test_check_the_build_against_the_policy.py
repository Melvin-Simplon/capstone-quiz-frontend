import importlib.util
import json
import pathlib

import pytest

SCRIPT = (
    pathlib.Path(__file__).resolve().parent.parent
    / "deploy"
    / "check-the-build-against-the-policy.py"
)

_spec = importlib.util.spec_from_file_location("policy_check", SCRIPT)
policy = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(policy)

STRICT = {"script-src": ["'self'"], "connect-src": ["'self'", "https://api.example.com"]}

def write_site(root, csp, document):
    config = root / policy.CONFIG
    config.parent.mkdir(parents=True)
    config.write_text(json.dumps({"globalHeaders": {"Content-Security-Policy": csp}}))
    built = root / policy.DOCUMENT
    built.parent.mkdir(parents=True)
    built.write_text(document)

def test_read_directives_splits_the_policy(tmp_path):
    config = tmp_path / "config.json"
    csp = "default-src 'self'; script-src 'self' https://cdn.example.com; "
    config.write_text(json.dumps({"globalHeaders": {"Content-Security-Policy": csp}}))

    assert policy.read_directives(config) == {
        "default-src": ["'self'"],
        "script-src": ["'self'", "https://cdn.example.com"],
    }

def test_unsafe_inline_allows_everything():
    directives = {"script-src": ["'unsafe-inline'"]}
    document = '<link onload="x()"><script>alert(1)</script>'

    assert policy.refused_inline_script(document, directives) == []

def test_inline_event_handler_is_refused():
    refused = policy.refused_inline_script('<link rel="x" onload="this.media=\'all\'">', STRICT)

    assert refused == ["inline event handler: onload=\"this.media='all'\""]

@pytest.mark.parametrize("tag", ["script", "SCRIPT", "Script"])
def test_inline_script_body_is_refused_whatever_the_case(tag):
    document = f"<{tag}>alert(1)</{tag}>"

    assert policy.refused_inline_script(document, STRICT) == ["inline script body"]

def test_external_and_empty_scripts_pass():
    document = '<script src="main.js"></script><script>  </script>'

    assert policy.refused_inline_script(document, STRICT) == []

def test_origin_outside_the_policy_is_refused():
    document = (
        '<script src="https://api.example.com/a.js"></script>'
        '<link href="https://evil.example.org/b.css">'
    )

    assert policy.refused_origins(document, STRICT) == [
        "no directive allows https://evil.example.org: https://evil.example.org/b.css"
    ]

def test_main_fails_when_a_file_is_missing(tmp_path, monkeypatch):
    monkeypatch.chdir(tmp_path)

    assert policy.main() == 1

def test_main_fails_on_a_refused_document(tmp_path, monkeypatch):
    write_site(tmp_path, "script-src 'self'", "<script>alert(1)</script>")
    monkeypatch.chdir(tmp_path)

    assert policy.main() == 1

def test_main_passes_a_clean_document(tmp_path, monkeypatch):
    write_site(tmp_path, "script-src 'self'", '<script src="main.js"></script>')
    monkeypatch.chdir(tmp_path)

    assert policy.main() == 0
