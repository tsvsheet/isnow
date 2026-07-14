#!/usr/bin/env python3
"""Validate the isnow conformance corpus.

Asserts, without needing any implementation: every YAML file parses, every case
has a unique name and exactly one recognized shape, and every `error` value is
one of the four stable codes. Exits non-zero with a report on any violation.

Contract: specs/contracts/conformance-corpus.md.
"""
from __future__ import annotations

import pathlib
import sys

ERROR_CODES = {"syntax", "symbol", "range", "context"}
SHAPES = ("holds", "canonical", "next", "prev", "error")
CORPUS_DIR = pathlib.Path(__file__).resolve().parent


def load_yaml(text: str):
    try:
        import yaml  # type: ignore
    except ModuleNotFoundError:
        return _minimal_load(text)
    return yaml.safe_load(text)


def _minimal_load(text: str):
    """A dependency-free reader for the corpus's flat case list.

    The corpus files are a deliberately small YAML subset: a top-level `cases:`
    sequence of mappings whose values are scalars or short scalar lists. This
    parses exactly that shape so `make corpus` needs no pip install.
    """
    cases: list[dict] = []
    current: dict | None = None
    list_key: str | None = None
    for raw in text.splitlines():
        line = raw.split(" #")[0].rstrip() if " #" in raw else raw.rstrip()
        if not line or line.lstrip().startswith("#") or line.strip() == "cases:":
            continue
        stripped = line.strip()
        if stripped.startswith("- name:"):
            current = {"name": _scalar(stripped[len("- name:"):])}
            cases.append(current)
            list_key = None
        elif stripped.startswith("- "):
            if current is not None and list_key is not None:
                current.setdefault(list_key, []).append(_scalar(stripped[2:]))
        elif ":" in stripped and current is not None:
            key, _, val = stripped.partition(":")
            key = key.strip()
            val = val.strip()
            if val == "":
                list_key = key
                current[key] = []
            elif val == "[]":
                current[key] = []
                list_key = None
            else:
                current[key] = _scalar(val)
                list_key = None
    return {"cases": cases}


def _scalar(text: str):
    text = text.strip()
    if len(text) >= 2 and text[0] == text[-1] and text[0] in "\"'":
        return text[1:-1]
    if text == "true":
        return True
    if text == "false":
        return False
    return text


def validate() -> list[str]:
    problems: list[str] = []
    seen: dict[str, str] = {}
    files = sorted(CORPUS_DIR.glob("*.yaml"))
    if not files:
        return ["no corpus files found in conformance/"]
    for path in files:
        doc = load_yaml(path.read_text())
        cases = (doc or {}).get("cases")
        if not isinstance(cases, list):
            problems.append(f"{path.name}: missing a `cases:` list")
            continue
        for case in cases:
            problems.extend(_check_case(path.name, case, seen))
    return problems


def _check_case(filename: str, case: dict, seen: dict[str, str]) -> list[str]:
    name = case.get("name")
    if not name:
        return [f"{filename}: a case has no name"]
    where = f"{filename}:{name}"
    out: list[str] = []
    if name in seen:
        out.append(f"{where}: duplicate name (also in {seen[name]})")
    seen[name] = filename
    shapes = [s for s in SHAPES if s in case]
    if len(shapes) != 1:
        out.append(f"{where}: expected exactly one of {SHAPES}, found {shapes}")
    if "error" in case and case["error"] not in ERROR_CODES:
        out.append(f"{where}: error code {case['error']!r} not in {sorted(ERROR_CODES)}")
    if ("holds" in case or "next" in case or "prev" in case) and "isnow" in case and "at" not in case and "from" not in case and "holds" in case:
        out.append(f"{where}: holds case needs an `at`")
    return out


def main() -> int:
    problems = validate()
    if problems:
        print("corpus INVALID:", file=sys.stderr)
        for p in problems:
            print(f"  - {p}", file=sys.stderr)
        return 1
    count = sum(len((load_yaml(p.read_text()) or {}).get("cases", [])) for p in CORPUS_DIR.glob("*.yaml"))
    print(f"corpus OK: {count} cases, all names unique")
    return 0


if __name__ == "__main__":
    sys.exit(main())
