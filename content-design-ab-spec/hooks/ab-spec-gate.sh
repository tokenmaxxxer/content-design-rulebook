#!/usr/bin/env bash
# PreToolUse gate: testable A/B variant spec per copy string (varied element + signal, or not-applicable + reason)
# Kill switch: export CONTENT_DESIGN_AB_SPEC_GATE_OFF=1
#
# Migrated to source core issue #72's gate-lib.sh/gate-lib.py (issue #10
# remediation) instead of hand-rolling the trap/kill-switch/path-normalize/
# reconstruct machinery locally. Reference only, never a vendored copy
# (docs/handbooks/canon-scripts.md).

. "${CLAUDE_PLUGIN_ROOT_CORE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../core" && pwd -P)}/hooks/lib/gate-lib.sh" || { echo "ab-spec-gate.sh: cannot source gate-lib.sh" >&2; exit 2; }
gate_trap_fail_closed
set -uo pipefail
gate_kill_switch_active "${CONTENT_DESIGN_AB_SPEC_GATE_OFF:-}" || { trap - EXIT; exit 0; }

command -v python3 >/dev/null 2>&1 || gate_deny "ab-spec-gate" "python3 not found; cannot evaluate gate"

INPUT_JSON="$(cat)"

# Payload travels via GATE_INPUT_JSON env var; stdin is claimed by the heredoc carrying the python program below.

# Candidate path-shaped tokens for a Bash-tool write, extracted from the
# whole raw payload (over-inclusive by design -- gate_lib.gate_normalize_path
# + the scope check in Python below is what actually decides relevance).
GATE_BASH_TARGETS="$(gate_bash_write_targets "$INPUT_JSON")"
export GATE_BASH_TARGETS
export GATE_INPUT_JSON="$INPUT_JSON"

RESULT="$(python3 <<'PYEOF'
import importlib.util
import json
import os
import re
import sys

_spec = importlib.util.spec_from_file_location("gate_lib", os.environ["GATE_LIB_PY"])
gate_lib = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(gate_lib)

SCOPE_REGEX = re.compile(r'^docs/issue-[0-9]+/reports/content-design\.md$')

HEADER_RE = re.compile(r'^#{2,4}\s.*string', re.IGNORECASE)
AB_RE = re.compile(r'a/b|a-b test|variant', re.IGNORECASE)
NOT_APPLICABLE_RE = re.compile(r'not applicable', re.IGNORECASE)
VARIED_RE = re.compile(r'varied element', re.IGNORECASE)
SIGNAL_RE = re.compile(r'signal', re.IGNORECASE)


def deny(msg):
    print(f"DENY:{msg}")
    sys.exit(2)


def in_scope(tail):
    return tail is not None and SCOPE_REGEX.fullmatch(tail) is not None


def split_sections(text):
    lines = text.splitlines()
    header_idxs = [i for i, l in enumerate(lines) if HEADER_RE.search(l)]
    sections = []
    for n, idx in enumerate(header_idxs):
        end = header_idxs[n + 1] if n + 1 < len(header_idxs) else len(lines)
        header = lines[idx].strip()
        sections.append((header, lines[idx:end]))
    return sections


def check_section(header, lines):
    has_not_applicable = False
    for line in lines:
        if NOT_APPLICABLE_RE.search(line) and AB_RE.search(line):
            has_not_applicable = True
            break
    if has_not_applicable:
        return True, f"not-applicable A/B spec for '{header}'"

    section_text = "\n".join(lines)
    if not AB_RE.search(section_text):
        return False, f"missing A/B variant spec (or not-applicable + reason) for '{header}'"

    varied_count = sum(1 for l in lines if VARIED_RE.search(l))
    if varied_count != 1:
        return False, (
            f"expected exactly one varied element in A/B spec for '{header}', "
            f"found {varied_count}"
        )

    if not SIGNAL_RE.search(section_text):
        return False, f"A/B spec missing user-behavior signal for '{header}'"

    return True, f"A/B spec ok for '{header}'"


def check(text):
    # Every check here runs against a section's own line window
    # (lines[header_idx:next_header_idx]) -- `text` itself is never
    # re.search'd directly after this split.
    sections = split_sections(text)
    if not sections:
        return False, "no per-string section header found -- cannot verify per-string A/B spec"
    for header, lines in sections:
        ok, msg = check_section(header, lines)
        if not ok:
            return False, msg
    return True, "all sections have valid A/B spec or explicit not-applicable"


def resolve_current_content(path):
    try:
        with open(path, "r", encoding="utf-8") as f:
            return f.read()
    except OSError:
        return None


def main():
    raw = os.environ["GATE_INPUT_JSON"]
    payload = gate_lib.gate_parse_json_or_deny(raw, deny)
    tool_name = payload.get("tool_name", "")
    ti = payload.get("tool_input", {}) or {}
    root = os.environ.get("CLAUDE_PROJECT_DIR") or os.getcwd()

    if tool_name == "Bash":
        for tok in os.environ.get("GATE_BASH_TARGETS", "").splitlines():
            tail = gate_lib.gate_normalize_path(root, tok)
            if in_scope(tail):
                deny(
                    f"Bash-tool command appears to write to gated file '{tok}'; this "
                    "gate cannot verify semantic content from a Bash write -- use "
                    "Write/Edit/MultiEdit instead"
                )
        print("PASS:no Bash write target in scope")
        sys.exit(0)

    if tool_name not in ("Write", "Edit", "MultiEdit"):
        print("PASS:tool not in scope")
        sys.exit(0)

    path = ti.get("file_path", "") or ""
    tail = gate_lib.gate_normalize_path(root, path)
    if not in_scope(tail):
        print("PASS:out of scope")
        sys.exit(0)

    current_content = None if tool_name == "Write" else resolve_current_content(path)
    if tool_name != "Write" and current_content is None:
        deny("cannot determine resulting content (base file unreadable)")

    text, ok = gate_lib.gate_reconstruct_write(tool_name, ti, current_content)
    if not ok:
        deny("cannot determine resulting content (edit target not found or unsupported shape)")

    ok, msg = check(text)
    if ok:
        print(f"PASS:{msg}")
        sys.exit(0)
    deny(msg)


main()
PYEOF
)"
PY_EXIT=$?

trap - EXIT
if [ "$PY_EXIT" -ne 0 ]; then
  echo "${RESULT#DENY:}" >&2
  exit 2
fi
exit 0
