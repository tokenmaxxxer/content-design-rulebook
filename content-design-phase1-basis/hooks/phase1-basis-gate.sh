#!/usr/bin/env bash
# PreToolUse gate: phase-1 proposal must state a survey+scout basis (or documented skip)
# Kill switch: export CONTENT_DESIGN_PHASE1_BASIS_GATE_OFF=1
#
# Migrated to source core issue #72's gate-lib.sh/gate-lib.py (issue #10
# remediation) instead of hand-rolling the trap/kill-switch/path-normalize/
# reconstruct machinery locally. Reference only, never a vendored copy
# (docs/handbooks/canon-scripts.md).

. "${CLAUDE_PLUGIN_ROOT_CORE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../core" && pwd -P)}/hooks/lib/gate-lib.sh"
gate_trap_fail_closed
set -uo pipefail
gate_kill_switch_active "${CONTENT_DESIGN_PHASE1_BASIS_GATE_OFF:-}" || { trap - EXIT; exit 0; }

command -v python3 >/dev/null 2>&1 || gate_deny "phase1-basis-gate" "python3 not found; cannot evaluate gate"

INPUT_JSON="$(cat)"

# python3 is invoked against a temp script + temp input file (not
# "python3 - <<PYEOF" piped from stdin) because a heredoc attached to the
# same command clobbers the process's stdin, leaving nothing for a
# sys.stdin.read() call inside the script to see (verified in the
# pre-migration scripts this replaces).
PY_SCRIPT="$(mktemp "${TMPDIR:-/tmp}/phase1-basis-gate.XXXXXX.py")" || gate_deny "phase1-basis-gate" "cannot create temp python file"
INPUT_JSON_FILE="$(mktemp "${TMPDIR:-/tmp}/phase1-basis-gate-input.XXXXXX.json")" || gate_deny "phase1-basis-gate" "cannot create temp input file"
printf '%s' "$INPUT_JSON" > "$INPUT_JSON_FILE"

# Candidate path-shaped tokens for a Bash-tool write, extracted from the
# whole raw payload (over-inclusive by design -- gate_lib.gate_normalize_path
# + the scope check in Python below is what actually decides relevance).
GATE_BASH_TARGETS="$(gate_bash_write_targets "$INPUT_JSON")"
export GATE_BASH_TARGETS

cat > "$PY_SCRIPT" <<'PYEOF'
import importlib.util
import json
import os
import re
import sys

_spec = importlib.util.spec_from_file_location("gate_lib", os.environ["GATE_LIB_PY"])
gate_lib = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(gate_lib)

SCOPE_REGEX = re.compile(r'^docs/issue-[0-9]+/proposals/.*content-design.*\.md$')


def deny(msg):
    print(f"DENY:{msg}")
    sys.exit(2)


def in_scope(tail):
    return tail is not None and SCOPE_REGEX.fullmatch(tail) is not None


# whole-proposal check by design: a phase-1 proposal has no per-copy-string
# headers to section on, so (unlike ab-spec-gate's per-section check) this
# runs as a single regex check against the whole reconstructed document.
def check(text):
    survey_re = r'docs/issue-[0-9]+/reports/[\w-]+/survey\.md'
    if re.search(survey_re, text):
        return True, "found survey report reference"
    if re.search(r'scout-brief', text, re.IGNORECASE):
        return True, "found scout-brief reference"
    if re.search(r'skip(ped)?.{0,40}scout', text, re.IGNORECASE) or re.search(r'scout.{0,40}skip', text, re.IGNORECASE):
        return True, "found documented scout-skip"
    return False, "missing stated survey+scout basis (or documented skip)"


def resolve_current_content(path):
    try:
        with open(path, "r", encoding="utf-8") as f:
            return f.read()
    except OSError:
        return None


def main():
    with open(sys.argv[1], "r", encoding="utf-8") as f:
        raw = f.read()
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

RESULT="$(python3 "$PY_SCRIPT" "$INPUT_JSON_FILE")"
PY_EXIT=$?
rm -f "$PY_SCRIPT" "$INPUT_JSON_FILE"

trap - EXIT
if [ "$PY_EXIT" -ne 0 ]; then
  echo "${RESULT#DENY:}" >&2
  exit 2
fi
exit 0
