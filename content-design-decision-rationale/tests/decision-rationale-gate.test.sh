#!/usr/bin/env bash
# TAP-ish test harness for hooks/decision-rationale-gate.sh
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GATE="$SCRIPT_DIR/../hooks/decision-rationale-gate.sh"

TMPDIR="${TMPDIR:-/tmp}"
WORKDIR="$(mktemp -d "$TMPDIR/decision-rationale-test.XXXXXX")"
trap 'rm -rf "$WORKDIR"' EXIT

FAIL=0

run_case() {
  local desc="$1" expected_exit="$2" json_file="$3"
  local out actual_exit
  out="$(bash "$GATE" < "$json_file" 2>"$WORKDIR/stderr.txt")"
  actual_exit=$?
  if [ "$actual_exit" -eq "$expected_exit" ]; then
    echo "ok - $desc"
  else
    echo "not ok - $desc (expected exit $expected_exit, got $actual_exit; stderr: $(cat "$WORKDIR/stderr.txt")))"
    FAIL=1
  fi
}

json_escape() {
  python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))'
}

# (a) proposal-path Write with rationale statement -> exit 0
CONTENT_A='This serves the checkout-cta decision -> we shorten the label because it reduces cognitive load.'
CONTENT_A_JSON="$(printf '%s' "$CONTENT_A" | json_escape)"
cat > "$WORKDIR/a.json" <<EOF
{"tool_name":"Write","tool_input":{"file_path":"docs/issue-12/proposals/content-design-cta.md","content":$CONTENT_A_JSON}}
EOF
run_case "(a) proposal with rationale -> exit 0" 0 "$WORKDIR/a.json"

# (b) proposal-path Write missing rationale -> exit 2
CONTENT_B='This is a proposal about the checkout CTA copy with no linking statement at all.'
CONTENT_B_JSON="$(printf '%s' "$CONTENT_B" | json_escape)"
cat > "$WORKDIR/b.json" <<EOF
{"tool_name":"Write","tool_input":{"file_path":"docs/issue-12/proposals/content-design-cta.md","content":$CONTENT_B_JSON}}
EOF
run_case "(b) proposal missing rationale -> exit 2" 2 "$WORKDIR/b.json"

# (c) report-path Write, two copy string sections, both with construction -> exit 0
CONTENT_C='## Copy string: Checkout Button

serves the checkout-button decision -> because it clarifies the next step

## Copy string: Error Banner

serves the error-banner decision -> because it reduces confusion
'
CONTENT_C_JSON="$(printf '%s' "$CONTENT_C" | json_escape)"
cat > "$WORKDIR/c.json" <<EOF
{"tool_name":"Write","tool_input":{"file_path":"docs/issue-12/reports/content-design.md","content":$CONTENT_C_JSON}}
EOF
run_case "(c) report both sections have rationale -> exit 0" 0 "$WORKDIR/c.json"

# (d) report-path Write, one of two sections missing construction -> exit 2, stderr names section
CONTENT_D='## Copy string: Checkout Button

serves the checkout-button decision -> because it clarifies the next step

## Copy string: Error Banner

this text has no linking construction of any kind at all here
'
CONTENT_D_JSON="$(printf '%s' "$CONTENT_D" | json_escape)"
cat > "$WORKDIR/d.json" <<EOF
{"tool_name":"Write","tool_input":{"file_path":"docs/issue-12/reports/content-design.md","content":$CONTENT_D_JSON}}
EOF
bash "$GATE" < "$WORKDIR/d.json" > "$WORKDIR/d.out.txt" 2>"$WORKDIR/d.err.txt"
d_exit=$?
if [ "$d_exit" -eq 2 ] && grep -q "Error Banner" "$WORKDIR/d.err.txt"; then
  echo "ok - (d) report missing section -> exit 2, stderr names section"
else
  echo "not ok - (d) report missing section -> exit 2, stderr names section (exit=$d_exit, stderr: $(cat "$WORKDIR/d.err.txt"))"
  FAIL=1
fi

# (e) file_path outside both regexes -> exit 0
cat > "$WORKDIR/e.json" <<'EOF'
{"tool_name":"Write","tool_input":{"file_path":"docs/issue-12/specs/random.md","content":"anything at all"}}
EOF
run_case "(e) out-of-scope path -> exit 0" 0 "$WORKDIR/e.json"

# (f) malformed JSON -> exit 2
printf '{not valid json' > "$WORKDIR/f.json"
run_case "(f) malformed JSON -> exit 2" 2 "$WORKDIR/f.json"

# (g) kill switch set -> exit 0 unconditionally
cat > "$WORKDIR/g.json" <<EOF
{"tool_name":"Write","tool_input":{"file_path":"docs/issue-12/proposals/content-design-cta.md","content":$CONTENT_B_JSON}}
EOF
CONTENT_DESIGN_DECISION_RATIONALE_GATE_OFF=1 bash "$GATE" < "$WORKDIR/g.json" > /dev/null 2>"$WORKDIR/g.err.txt"
g_exit=$?
if [ "$g_exit" -eq 0 ]; then
  echo "ok - (g) kill switch -> exit 0"
else
  echo "not ok - (g) kill switch -> exit 0 (got $g_exit; stderr: $(cat "$WORKDIR/g.err.txt"))"
  FAIL=1
fi

if [ "$FAIL" -ne 0 ]; then
  exit 1
fi
exit 0
