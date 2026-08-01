#!/usr/bin/env bash
# PreToolUse gate: decision-tied rationale (proposal basis-level statement / per-copy-string [decision] -> [why])
# Kill switch: export CONTENT_DESIGN_DECISION_RATIONALE_GATE_OFF=1
#
# Migrated to source core issue #72's gate-lib.sh/gate-lib.py (issue #10
# remediation) instead of hand-rolling the trap/kill-switch/path-normalize/
# reconstruct machinery locally. Reference only, never a vendored copy
# (docs/handbooks/canon-scripts.md).

. "${CLAUDE_PLUGIN_ROOT_CORE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../core" && pwd -P)}/hooks/lib/gate-lib.sh"
gate_trap_fail_closed
set -uo pipefail
gate_kill_switch_active "${CONTENT_DESIGN_DECISION_RATIONALE_GATE_OFF:-}" || { trap - EXIT; exit 0; }

command -v python3 >/dev/null 2>&1 || gate_deny "decision-rationale-gate" "python3 not found; cannot evaluate gate"

INPUT_JSON="$(cat)"

# python3 is invoked against a temp script + temp input file (not
# "python3 - <<PYEOF" piped from stdin) because a heredoc attached to the
# same command clobbers the process's stdin, leaving nothing for a
# sys.stdin.read() call inside the script to see (verified in the
# pre-migration scripts this replaces).
PY_SCRIPT="$(mktemp "${TMPDIR:-/tmp}/decision-rationale-gate.XXXXXX.py")" || gate_deny "decision-rationale-gate" "cannot create temp python file"
INPUT_JSON_FILE="$(mktemp "${TMPDIR:-/tmp}/decision-rationale-gate-input.XXXXXX.json")" || gate_deny "decision-rationale-gate" "cannot create temp input file"
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

PROPOSAL_REGEX = re.compile(r'docs/issue-[0-9]+/proposals/.*content-design.*\.md')
REPORT_REGEX = re.compile(r'docs/issue-[0-9]+/reports/content-design\.md')


def deny(msg):
    print(f"DENY:{msg}")
    sys.exit(2)


def mode_for(tail):
    if tail is None:
        return None
    if PROPOSAL_REGEX.fullmatch(tail):
        return "proposal"
    if REPORT_REGEX.fullmatch(tail):
        return "report"
    return None


def has_rationale(text):
    marker_re = re.compile(r'->|because|so that', re.I)
    for m in marker_re.finditer(text):
        start = max(0, m.start() - 80)
        end = min(len(text), m.end() + 80)
        window = text[start:end]
        if re.search(r'decision', window, re.I):
            return True
    return False


def check_proposal(text):
    # Deliberately a whole-document check: a phase-1 proposal has no
    # copy-string headers, so there is no per-section basis to key on.
    if has_rationale(text):
        return True, "decision-tied rationale statement present"
    return False, "missing decision-tied rationale statement"


def check_report(text):
    lines = text.splitlines()

    all_headers = []  # (line_idx, level)
    for i, line in enumerate(lines):
        hm = re.match(r'^(#{1,6})\s', line)
        if hm:
            all_headers.append((i, len(hm.group(1))))

    cs_re = re.compile(r'^#{2,4}\s.*string', re.I)
    copystring_headers = []  # (line_idx, level, title)
    for i, line in enumerate(lines):
        if cs_re.search(line):
            hm = re.match(r'^(#{1,6})\s+(.*)$', line)
            level = len(hm.group(1))
            title = hm.group(2).strip()
            copystring_headers.append((i, level, title))

    if not copystring_headers:
        return False, "no per-string section header found -- cannot verify per-string spec"

    for idx, level, title in copystring_headers:
        end_idx = len(lines)
        for j, lvl in all_headers:
            if j > idx and lvl <= level:
                end_idx = j
                break
        body = "\n".join(lines[idx:end_idx])
        if not has_rationale(body):
            return False, f"copy string '{title}' missing decision-tied rationale ([decision] -> [why] construction)"

    return True, "all copy string sections have decision-tied rationale"


def check(text, mode):
    if mode == "proposal":
        return check_proposal(text)
    if mode == "report":
        return check_report(text)
    return True, "out of scope (no matching mode)"


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
            if mode_for(tail) is not None:
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
    mode = mode_for(tail)
    if mode is None:
        print("PASS:out of scope")
        sys.exit(0)

    current_content = None if tool_name == "Write" else resolve_current_content(path)
    if tool_name != "Write" and current_content is None:
        deny("cannot determine resulting content (base file unreadable)")

    text, ok = gate_lib.gate_reconstruct_write(tool_name, ti, current_content)
    if not ok:
        deny("cannot determine resulting content (edit target not found or unsupported shape)")

    ok, msg = check(text, mode)
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
