#!/usr/bin/env bash
# PreToolUse gate: testable A/B variant spec per copy string (varied element + signal, or not-applicable + reason)
# Kill switch: export CONTENT_DESIGN_AB_SPEC_GATE_OFF=1
set -u

KILL_SWITCH_VAR="CONTENT_DESIGN_AB_SPEC_GATE_OFF"
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

# python3 helper does: parse JSON, extract file_path, check SCOPE_REGEX,
# reconstruct resulting text for Write/Edit/MultiEdit (read current file
# from disk for Edit/MultiEdit base), run the check, print PASS/DENY:<msg>,
# exit 0/2 accordingly. Each plugin's python3 block implements ONLY its
# own check function; JSON parsing / text reconstruction / regex-scope
# logic is duplicated per plugin verbatim (no shared library file, per
# proposal's "no inter-plugin source" rule).

RESULT="$(INPUT_JSON="$INPUT_JSON" python3 - <<'PYEOF'
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

HEADER_RE = re.compile(r'^#{2,4}\s.*string', re.IGNORECASE)
AB_RE = re.compile(r'a/b|a-b test|variant', re.IGNORECASE)
NOT_APPLICABLE_RE = re.compile(r'not applicable', re.IGNORECASE)
VARIED_RE = re.compile(r'varied element', re.IGNORECASE)
SIGNAL_RE = re.compile(r'signal', re.IGNORECASE)

def split_sections(text):
    lines = text.splitlines()
    header_idxs = [i for i, l in enumerate(lines) if HEADER_RE.search(l)]
    if not header_idxs:
        return [("document", lines)]
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
    if varied_count > 1:
        return False, f"more than one varied element in A/B spec for '{header}'"

    if not SIGNAL_RE.search(section_text):
        return False, f"A/B spec missing user-behavior signal for '{header}'"

    return True, f"A/B spec ok for '{header}'"

def check(text, path):
    sections = split_sections(text)
    for header, lines in sections:
        ok, msg = check_section(header, lines)
        if not ok:
            return False, msg
    return True, "all sections have valid A/B spec or explicit not-applicable"

def main():
    try:
        payload = json.loads(os.environ.get("INPUT_JSON", ""))
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
