#!/usr/bin/env bash
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GATE="$SCRIPT_DIR/../hooks/phase1-basis-gate.sh"
TMPDIR="${TMPDIR:-/tmp}"

FAIL=0

run_case() {
  local desc="$1" expected="$2" json="$3"
  local out
  out="$(printf '%s' "$json" | bash "$GATE" 2>/dev/null)"
  local actual=$?
  if [ "$actual" -eq "$expected" ]; then
    echo "ok - $desc"
  else
    echo "not ok - $desc (expected $expected got $actual)"
    FAIL=1
  fi
}

# (a) proposal with survey.md path + scout-brief -> Write -> exit 0
FILE_A="$TMPDIR/phase1-basis-a-$$.md"
JSON_A=$(cat <<EOF
{"tool_name":"Write","tool_input":{"file_path":"docs/issue-9/proposals/content-design-plan.md","content":"See docs/issue-9/reports/content-design/survey.md and the scout-brief for basis."}}
EOF
)
run_case "content with survey path + scout-brief passes" 0 "$JSON_A"

# (b) proposal text with neither -> exit 2
JSON_B=$(cat <<EOF
{"tool_name":"Write","tool_input":{"file_path":"docs/issue-9/proposals/content-design-plan.md","content":"No basis stated here at all."}}
EOF
)
run_case "content with no basis denies" 2 "$JSON_B"

# (c) file_path outside scope regex -> exit 0 (gate silent)
JSON_C=$(cat <<EOF
{"tool_name":"Write","tool_input":{"file_path":"docs/issue-9/reports/content-design.md","content":"No basis stated here at all."}}
EOF
)
run_case "out-of-scope path passes silently" 0 "$JSON_C"

# (d) malformed JSON on stdin -> exit 2
run_case "malformed JSON denies" 2 "{not valid json"

# (e) kill switch set -> exit 0 unconditionally
JSON_E=$(cat <<EOF
{"tool_name":"Write","tool_input":{"file_path":"docs/issue-9/proposals/content-design-plan.md","content":"No basis stated here at all."}}
EOF
)
out_e="$(CONTENT_DESIGN_PHASE1_BASIS_GATE_OFF=1 bash "$GATE" <<< "$JSON_E" 2>/dev/null)"
actual_e=$?
if [ "$actual_e" -eq 0 ]; then
  echo "ok - kill switch bypasses gate"
else
  echo "not ok - kill switch bypasses gate (expected 0 got $actual_e)"
  FAIL=1
fi

exit $FAIL
