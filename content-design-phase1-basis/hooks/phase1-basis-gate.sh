#!/usr/bin/env bash
# PreToolUse gate: phase-1 proposal must state a survey+scout basis (or documented skip)
# Kill switch: export CONTENT_DESIGN_PHASE1_BASIS_GATE_OFF=1
set -u

KILL_SWITCH_VAR="CONTENT_DESIGN_PHASE1_BASIS_GATE_OFF"
SCOPE_REGEX='docs/issue-[0-9]+/proposals/.*content-design.*\.md'

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

RESULT="$(GATE_INPUT_JSON="$INPUT_JSON" python3 - <<'PYEOF'
import json, re, sys, os

SCOPE_REGEX = r'docs/issue-[0-9]+/proposals/.*content-design.*\.md'

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

def check(text, path):
    survey_re = r'docs/issue-[0-9]+/reports/[\w-]+/survey\.md'
    if re.search(survey_re, text):
        return True, "found survey report reference"
    if re.search(r'scout-brief', text, re.IGNORECASE):
        return True, "found scout-brief reference"
    if re.search(r'skip(ped)?.{0,40}scout', text, re.IGNORECASE) or re.search(r'scout.{0,40}skip', text, re.IGNORECASE):
        return True, "found documented scout-skip"
    return False, "missing stated survey+scout basis (or documented skip)"

def main():
    try:
        payload = json.loads(os.environ.get("GATE_INPUT_JSON", ""))
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
)"
PY_EXIT=$?

trap - EXIT
if [ "$PY_EXIT" -ne 0 ]; then
  echo "${RESULT#DENY:}" >&2
  exit 2
fi
exit 0
