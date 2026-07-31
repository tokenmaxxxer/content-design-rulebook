#!/usr/bin/env bash
# PreToolUse gate: decision-tied rationale (proposal basis-level statement / per-copy-string [decision] -> [why])
# Kill switch: export CONTENT_DESIGN_DECISION_RATIONALE_GATE_OFF=1
set -u

KILL_SWITCH_VAR="CONTENT_DESIGN_DECISION_RATIONALE_GATE_OFF"
SCOPE_REGEX='docs/issue-[0-9]+/proposals/.*content-design.*\.md|docs/issue-[0-9]+/reports/content-design\.md'

__fc_deny() {
  echo "DENY: $1" >&2
  exit 2
}
trap '__fc_deny "gate crashed or exited abnormally (fail-closed)"' EXIT

val="$(eval echo \"\$${KILL_SWITCH_VAR}\" 2>/dev/null || true)"
case "$(printf '%s' "${val:-}" | tr '[:upper:]' '[:lower:]')" in
  ""|0|false|no|off) : ;;   # not off, gate stays active
  *) trap - EXIT; exit 0 ;; # kill switch on -> bypass
esac

command -v python3 >/dev/null 2>&1 || __fc_deny "python3 not found; cannot evaluate gate"

INPUT_JSON="$(cat)"

# NOTE: `python3 - <<'PYEOF' ... PYEOF` combined with a pipe would make the
# heredoc win control of fd0 for the python3 process, so sys.stdin.read()
# inside the script would always read empty (verified). To actually deliver
# INPUT_JSON to the script's stdin, the python source is written to a temp
# file first and INPUT_JSON is piped to that instead; control flow (parse
# JSON, extract file_path, scope check, reconstruct, check(), PASS/DENY) is
# otherwise unchanged from the shared contract skeleton.
PYFILE="$(mktemp "${TMPDIR:-/tmp}/decision-rationale-gate.XXXXXX.py")" || __fc_deny "cannot create temp python file"

cat > "$PYFILE" <<'PYEOF'
import json, re, sys, os

SCOPE_REGEX = r'docs/issue-[0-9]+/proposals/.*content-design.*\.md|docs/issue-[0-9]+/reports/content-design\.md'
PROPOSAL_REGEX = r'docs/issue-[0-9]+/proposals/.*content-design.*\.md'
REPORT_REGEX = r'docs/issue-[0-9]+/reports/content-design\.md'

def reconstruct_text(tool_name, ti):
    path = ti.get("file_path", "")
    if tool_name == "Write":
        return ti.get("content", ""), None
    try:
        with open(path, "r", encoding="utf-8") as f:
            base = f.read()
    except OSError:
        return None, "cannot determine resulting content (base file unreadable)"
    if tool_name == "Edit":
        old, new = ti.get("old_string", ""), ti.get("new_string", "")
        if old not in base:
            return None, "cannot determine resulting content (old_string not found)"
        return base.replace(old, new, 1), None
    if tool_name == "MultiEdit":
        text = base
        for e in ti.get("edits", []):
            old, new = e.get("old_string", ""), e.get("new_string", "")
            if old not in text:
                return None, "cannot determine resulting content (old_string not found in MultiEdit)"
            text = text.replace(old, new, 1)
        return text, None
    return None, f"cannot determine resulting content (unknown tool {tool_name})"

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
        if has_rationale(text):
            return True, "decision-tied rationale statement present (whole document)"
        return False, "missing decision-tied rationale statement"

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

def check(text, path):
    if re.search(PROPOSAL_REGEX, path):
        return check_proposal(text)
    if re.search(REPORT_REGEX, path):
        return check_report(text)
    return True, "out of scope (no matching mode)"

def main():
    try:
        payload = json.loads(sys.stdin.read())
    except Exception:
        print("DENY:malformed JSON input"); sys.exit(2)
    tool_name = payload.get("tool_name", "")
    ti = payload.get("tool_input", {}) or {}
    path = ti.get("file_path", "") or ""
    if not re.search(SCOPE_REGEX, path):
        print("PASS:out of scope"); sys.exit(0)
    if tool_name not in ("Write", "Edit", "MultiEdit"):
        print("PASS:tool not in scope"); sys.exit(0)
    text, err = reconstruct_text(tool_name, ti)
    if err:
        print(f"DENY:{err}"); sys.exit(2)
    ok, msg = check(text, path)
    if ok:
        print(f"PASS:{msg}"); sys.exit(0)
    print(f"DENY:{msg}"); sys.exit(2)

main()
PYEOF

RESULT="$(printf '%s' "$INPUT_JSON" | python3 "$PYFILE")"
PY_EXIT=$?
rm -f "$PYFILE"

trap - EXIT
if [ "$PY_EXIT" -ne 0 ]; then
  echo "${RESULT#DENY:}" >&2
  exit 2
fi
exit 0
