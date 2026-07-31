#!/usr/bin/env bash
# PreToolUse gate: self-critique note per copy string (present, genuine, ordered after rationale/tone/A-B)
# Kill switch: export CONTENT_DESIGN_SELF_CRITIQUE_GATE_OFF=1
set -u

KILL_SWITCH_VAR="CONTENT_DESIGN_SELF_CRITIQUE_GATE_OFF"
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

# Note: piping stdin into `python3 - <<HEREDOC` doesn't work as one might
# expect -- the heredoc redirect on the python3 command takes over fd0
# entirely (it's what "python3 -" reads its *program* from), so a pipe
# feeding the same command's stdin is silently discarded and
# sys.stdin.read() inside the script sees EOF. To avoid that, the JSON
# payload is written to a scratch file under $TMPDIR and passed as argv.
_SCRATCH_DIR="${TMPDIR:-/tmp}"
INPUT_JSON_FILE="$(mktemp "${_SCRATCH_DIR%/}/self-critique-gate-input.XXXXXX")"
printf '%s' "$INPUT_JSON" > "$INPUT_JSON_FILE"

RESULT="$(python3 - "$INPUT_JSON_FILE" <<'PYEOF'
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
SELF_CRITIQUE_RE = re.compile(r'self-critique', re.IGNORECASE)
GENUINE_RE = re.compile(r'rationale|tone|a/b|variant', re.IGNORECASE)
RATIONALE_RE = re.compile(r'rationale|decision.{0,10}->', re.IGNORECASE)
TONE_RE = re.compile(r'tone-axis|funny|serious|formal|casual|respectful|irreverent|enthusiastic|matter-of-fact', re.IGNORECASE)
AB_RE = re.compile(r'a/b|variant', re.IGNORECASE)

def check_section(header_label, body, base_offset):
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

def check(text, path):
    headers = list(HEADER_RE.finditer(text))
    if not headers:
        if not SELF_CRITIQUE_RE.search(text):
            return False, "missing self-critique note (no copy-string sections found; whole-doc fallback)"
        return True, "self-critique marker present (whole-doc fallback, ordering skipped)"

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
        ok, msg = check_section(header_label, body, start)
        if not ok:
            return False, msg

    return True, "all copy-string sections have valid self-critique notes"

def main():
    try:
        with open(sys.argv[1], "r", encoding="utf-8") as f:
            raw = f.read()
        payload = json.loads(raw)
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
rm -f "$INPUT_JSON_FILE"

trap - EXIT
if [ "$PY_EXIT" -ne 0 ]; then
  echo "${RESULT#DENY:}" >&2
  exit 2
fi
exit 0
