#!/usr/bin/env python3

import pathlib
import re
import sys


REPO_ROOT = pathlib.Path(__file__).resolve().parent.parent
MAKEFILE_PATH = REPO_ROOT / "Makefile"
SKIP_DIR_NAMES = {".git", ".build", ".swiftpm", "dist"}

TARGET_RE = re.compile(r"^([A-Za-z0-9_-]+):", re.MULTILINE)
MAKE_CMD_RE = re.compile(r"\bmake ([A-Za-z0-9_-]+)\b")
FENCE_RE = re.compile(r"^```")
INLINE_CODE_RE = re.compile(r"`([^`]+)`")


def load_make_targets() -> set[str]:
    content = MAKEFILE_PATH.read_text(encoding="utf-8")
    return {match.group(1) for match in TARGET_RE.finditer(content)}


def discover_docs() -> list[pathlib.Path]:
    docs: list[pathlib.Path] = []

    for path in REPO_ROOT.rglob("*.md"):
        if any(part in SKIP_DIR_NAMES for part in path.parts):
            continue
        docs.append(path)

    return sorted(docs)


def collect_references(doc_path: pathlib.Path) -> list[tuple[int, str]]:
    references: list[tuple[int, str]] = []
    in_code_block = False

    for line_number, line in enumerate(doc_path.read_text(encoding="utf-8").splitlines(), start=1):
        if FENCE_RE.match(line.strip()):
            in_code_block = not in_code_block
            continue

        if in_code_block:
            references.extend((line_number, match.group(1)) for match in MAKE_CMD_RE.finditer(line))

        for inline in INLINE_CODE_RE.finditer(line):
            references.extend((line_number, match.group(1)) for match in MAKE_CMD_RE.finditer(inline.group(1)))

    return references


def main() -> int:
    known_targets = load_make_targets()
    doc_paths = discover_docs()
    failures: list[str] = []

    for doc_path in doc_paths:
        for line_number, target in collect_references(doc_path):
            if target not in known_targets:
                relative = doc_path.relative_to(REPO_ROOT)
                failures.append(f"{relative}:{line_number}: documented target 'make {target}' is missing from Makefile")

    if failures:
        print("Documentation consistency check failed:")
        for failure in failures:
            print(f"  - {failure}")
        return 1

    print("Documentation consistency check passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
