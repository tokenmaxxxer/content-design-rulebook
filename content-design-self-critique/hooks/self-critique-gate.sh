#!/usr/bin/env bash
# PreToolUse gate: self-critique note per copy string (present, genuine, ordered after rationale/tone/A-B)
# Kill switch: export CONTENT_DESIGN_SELF_CRITIQUE_GATE_OFF=1
#
# Migrated to source core issue #72's gate-lib.sh/gate-lib.py (issue #10
# remediation) instead of hand-rolling the trap/kill-switch/path-normalize/
# reconstruct machinery locally. Reference only, never a vendored copy
# (docs/handbooks/canon-scripts.md).

. "${CLAUDE_PLUGIN_ROOT_CORE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../core" && pwd -P)}/hooks/lib/gate-lib.sh"
gate_trap_fail_closed
set -uo pipefail
gate_kill_switch_active "${CONTENT_DESIGN_SELF_CRITIQUE_GATE_OFF:-}" || { trap - EXIT; exit 0; }

command -v python3 >/dev/null 2>&1 || gate_deny "self-critique-gate" "python3 not found; cannot evaluate gate"

INPUT_JSON="$(cat)"

# python3 is invoked against a temp script + temp input file (not
# "python3 - <<PYEOF" piped from stdin) because a heredoc attached to the
# same command clobbers the process's stdin, leaving nothing for a
# sys.stdin.read() call inside the script to see (verified in the
# pre-migration scripts this replaces).
PY_SCRIPT="$(mktemp "${TMPDIR:-/tmp}/self-critique-gate.XXXXXX.py")" || gate_deny "self-critique-gate" "cannot create temp python file"
INPUT_JSON_FILE="$(mktemp "${TMPDIR:-/tmp}/self-critique-gate-input.XXXXXX.json")" || gate_deny "self-critique-gate" "cannot create temp input file"
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

SCOPE_REGEX = re.compile(r'^docs/issue-[0-9]+/reports/content-design\.md$')

HEADER_RE = re.compile(r'^#{2,4}\s.*string.*$', re.IGNORECASE | re.MULTILINE)
SELF_CRITIQUE_RE = re.compile(r'self-critique', re.IGNORECASE)
GENUINE_RE = re.compile(r'rationale|tone|a/b|variant', re.IGNORECASE)
RATIONALE_RE = re.compile(r'rationale|decision.{0,10}->', re.IGNORECASE)
TONE_RE = re.compile(r'tone-axis|funny|serious|formal|casual|respectful|irreverent|enthusiastic|matter-of-fact', re.IGNORECASE)
AB_RE = re.compile(r'a/b|variant', re.IGNORECASE)


def deny(msg):
    print(f"DENY:{msg}")
    sys.exit(2)


def in_scope(tail):
    return tail is not None and SCOPE_REGEX.fullmatch(tail) is not None


def check_section(header_label, body):
    sc_match = SELF_CRITIQUE_RE.search(body)
    if not sc_match:
        return False, f"copy string '{header_label}' missing self-critique note"

    genuine_span = body[sc_match.start():]
    next_header_in_span = re.search(r'^#{2,4}\s', genuine_span[1:], re.MULTILINE)
    if next_header_in_span:
        genuine_span = genuine_span[:next_header_in_span.start() + 1]
    if not GENUINE_RE.search(genuine_span):
        return False, f"self-critique note for '{header_label}' does not reference rationale/tone/A-B content"

    sc_offset = sc_match.start()
    for marker_re in (RATIONALE_RE, TONE_RE, AB_RE):
        m = marker_re.search(body)
        if m and m.start() > sc_offset:
            # marker appears AFTER the self-critique offset -> self-critique
            # came first, i.e. it could not have genuinely checked this
            # content yet (ordering violation).
            return False, f"self-critique note for '{header_label}' appears before the rationale/tone/A-B content it must check (ordering violation)"

    return True, "ok"


def check(text):
    # Every check here runs against a section's own line window
    # (text[header_start:next_same_or_higher_header_start]) -- `text`
    # itself is never re.search'd directly after this split.
    headers = list(HEADER_RE.finditer(text))
    if not headers:
        return False, "no per-string section header found -- cannot verify per-string spec"

    def header_level(h):
        return len(re.match(r'^#{2,4}', h).group(0))

    for i, h in enumerate(headers):
        level = header_level(h.group(0))
        start = h.start()
        end = len(text)
        for j in range(i + 1, len(headers)):
            if header_level(headers[j].group(0)) <= level:
                end = headers[j].start()
                break
        body = text[start:end]
        header_label = h.group(0).strip()
        ok, msg = check_section(header_label, body)
        if not ok:
            return False, msg

    return True, "all copy-string sections have valid self-critique notes"


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
