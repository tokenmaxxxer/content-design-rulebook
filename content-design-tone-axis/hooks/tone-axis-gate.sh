#!/usr/bin/env bash
# PreToolUse gate: NN Group 4-axis tone check per copy string, present-or-skipped-with-reason
# Kill switch: export CONTENT_DESIGN_TONE_AXIS_GATE_OFF=1
set -u

KILL_SWITCH_VAR="CONTENT_DESIGN_TONE_AXIS_GATE_OFF"
SCOPE_REGEX='docs/issue-[0-9]+/reports/content-design\.md'

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

# NOTE: python3 is invoked against a temp script file (not "python3 - <<PYEOF")
# because a heredoc attached to a command already receiving piped stdin
# clobbers that pipe (the heredoc becomes the process's stdin, so a script
# read via "-" would consume the heredoc and leave nothing for
# sys.stdin.read() to see). Writing the script to a file and piping the
# JSON into that invocation keeps stdin free for the JSON payload.
PY_SCRIPT="$(mktemp "${TMPDIR:-/tmp}/tone-axis-gate.XXXXXX.py")"
trap '__fc_deny "gate crashed or exited abnormally (fail-closed)"' EXIT
cat > "$PY_SCRIPT" <<'PYEOF'
import json, re, sys, os

SCOPE_REGEX = r'docs/issue-[0-9]+/reports/content-design\.md'

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

HEADER_RE = re.compile(r'^#{2,4}\s.*string.*$', re.IGNORECASE | re.MULTILINE)

AXIS_RE = re.compile(
    r'(funny|serious|formal|casual|respectful|irreverent|enthusiastic|matter-of-fact)',
    re.IGNORECASE,
)

SKIP_RE = re.compile(r'skip.{0,30}(reason|because)', re.IGNORECASE)

def has_skip_marker(body):
    if SKIP_RE.search(body):
        return True
    # 'not applicable' near 'tone'
    for m in re.finditer(r'not applicable', body, re.IGNORECASE):
        window_start = max(0, m.start() - 60)
        window_end = min(len(body), m.end() + 60)
        window = body[window_start:window_end]
        if re.search(r'tone', window, re.IGNORECASE):
            return True
    return False

def check(text, path):
    matches = list(HEADER_RE.finditer(text))
    if not matches:
        sections = [("(whole document)", text)]
    else:
        sections = []
        for i, m in enumerate(matches):
            header = m.group(0).strip()
            start = m.end()
            end = matches[i + 1].start() if i + 1 < len(matches) else len(text)
            body = text[start:end]
            sections.append((header, body))

    for header, body in sections:
        if AXIS_RE.search(body):
            continue
        if has_skip_marker(body):
            continue
        return False, f"copy string '{header}' missing tone-axis check (present-or-skipped-with-reason required)"

    return True, "all copy string sections have tone-axis check present or skipped with reason"

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

RESULT="$(printf '%s' "$INPUT_JSON" | python3 "$PY_SCRIPT")"
PY_EXIT=$?
rm -f "$PY_SCRIPT"

trap - EXIT
if [ "$PY_EXIT" -ne 0 ]; then
  echo "${RESULT#DENY:}" >&2
  exit 2
fi
exit 0
