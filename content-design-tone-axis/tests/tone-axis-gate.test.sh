#!/usr/bin/env bash
# Test harness for content-design-tone-axis/hooks/tone-axis-gate.sh
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GATE="$SCRIPT_DIR/../hooks/tone-axis-gate.sh"

TMPDIR="${TMPDIR:-/tmp}"
WORKDIR="$(mktemp -d "$TMPDIR/tone-axis-gate-test.XXXXXX")"

FAIL=0

pass_count=0
fail_count=0

assert_exit() {
  local desc="$1" expected="$2" actual="$3"
  if [ "$expected" -eq "$actual" ]; then
    echo "ok - $desc (exit $actual)"
    pass_count=$((pass_count + 1))
  else
    echo "not ok - $desc (expected exit $expected, got $actual)"
    fail_count=$((fail_count + 1))
    FAIL=1
  fi
}

assert_contains() {
  local desc="$1" haystack="$2" needle="$3"
  if printf '%s' "$haystack" | grep -qF "$needle"; then
    echo "ok - $desc (contains '$needle')"
    pass_count=$((pass_count + 1))
  else
    echo "not ok - $desc (missing '$needle') got: $haystack"
    fail_count=$((fail_count + 1))
    FAIL=1
  fi
}

make_json_file() {
  local out_file="$1" tool_name="$2" file_path="$3" content="$4"
  python3 - "$out_file" "$tool_name" "$file_path" "$content" <<'PYEOF'
import json, sys
out_file, tool_name, file_path, content = sys.argv[1:5]
payload = {"tool_name": tool_name, "tool_input": {"file_path": file_path, "content": content}}
with open(out_file, "w", encoding="utf-8") as f:
    json.dump(payload, f)
PYEOF
}

# --- Case (a): section names an axis -> exit 0 ---
CASE_A_PATH="docs/issue-7/reports/content-design.md"
CASE_A_CONTENT='## Copy string: Save button

Formal <-> Casual: leaning formal because legal copy

Body text.
'
CASE_A_JSON="$WORKDIR/case_a.json"
make_json_file "$CASE_A_JSON" "Write" "$CASE_A_PATH" "$CASE_A_CONTENT"
OUT_A="$(bash "$GATE" < "$CASE_A_JSON" 2>&1)"
assert_exit "case (a) axis named -> PASS" 0 $?

# --- Case (b): explicit skip with reason -> exit 0 ---
CASE_B_CONTENT='## Copy string: Error message

tone-axis: skip, reason: fixed legal string
'
CASE_B_JSON="$WORKDIR/case_b.json"
make_json_file "$CASE_B_JSON" "Write" "$CASE_A_PATH" "$CASE_B_CONTENT"
OUT_B="$(bash "$GATE" < "$CASE_B_JSON" 2>&1)"
assert_exit "case (b) explicit skip with reason -> PASS" 0 $?

# --- Case (c): section has neither -> exit 2, message names tone-axis and header ---
CASE_C_CONTENT='## Copy string: Confirm dialog

Just some body text with no tone information at all.
'
CASE_C_JSON="$WORKDIR/case_c.json"
make_json_file "$CASE_C_JSON" "Write" "$CASE_A_PATH" "$CASE_C_CONTENT"
OUT_C="$(bash "$GATE" < "$CASE_C_JSON" 2>&1)"
CASE_C_EXIT=$?
assert_exit "case (c) neither present -> DENY" 2 "$CASE_C_EXIT"
assert_contains "case (c) message names tone-axis" "$OUT_C" "tone-axis"
assert_contains "case (c) message names section header" "$OUT_C" "Copy string: Confirm dialog"

# --- Case (d): file_path outside scope -> exit 0 ---
CASE_D_JSON="$WORKDIR/case_d.json"
make_json_file "$CASE_D_JSON" "Write" "docs/issue-7/notes.md" "$CASE_C_CONTENT"
bash "$GATE" < "$CASE_D_JSON" > /dev/null 2>&1
assert_exit "case (d) out of scope -> PASS" 0 $?

# --- Case (e): malformed JSON -> exit 2 ---
CASE_E_JSON="$WORKDIR/case_e.json"
printf '{not valid json' > "$CASE_E_JSON"
bash "$GATE" < "$CASE_E_JSON" > /dev/null 2>&1
assert_exit "case (e) malformed JSON -> DENY" 2 $?

# --- Case (f): kill switch set -> exit 0 unconditionally ---
CASE_F_JSON="$WORKDIR/case_f.json"
make_json_file "$CASE_F_JSON" "Write" "$CASE_A_PATH" "$CASE_C_CONTENT"
CONTENT_DESIGN_TONE_AXIS_GATE_OFF=1 bash "$GATE" < "$CASE_F_JSON" > /dev/null 2>&1
assert_exit "case (f) kill switch on -> PASS unconditionally" 0 $?

rm -rf "$WORKDIR"

echo
echo "Results: $pass_count passed, $fail_count failed"

if [ "$FAIL" -ne 0 ]; then
  exit 1
fi
exit 0
