#!/usr/bin/env bash
# TAP-ish test harness for hooks/decision-rationale-gate.sh
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GATE="$SCRIPT_DIR/../hooks/decision-rationale-gate.sh"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PROPOSAL_TARGET="docs/issue-12/proposals/content-design-cta.md"
REPORT_TARGET="docs/issue-12/reports/content-design.md"

# Local multi-repo dev layout: tokenmaxxxer-core is checked out as a sibling
# repo, not a sibling directory of this plugin (production installs core as
# an actual sibling plugin dir, matched by the gate's own "../../core"
# fallback). Point CLAUDE_PLUGIN_ROOT_CORE at it so this test suite runs
# without a live plugin install; override the env var to point elsewhere.
export CLAUDE_PLUGIN_ROOT_CORE="${CLAUDE_PLUGIN_ROOT_CORE:-$HOME/tokenmaxxxer/tokenmaxxxer-core/core}"

WORKDIR="${TMPDIR:-/tmp}/decision-rationale-gate-test.$$"
mkdir -p "$WORKDIR"

FAIL=0

run_case() {
  local name="$1"
  local json_file="$2"
  local expected_exit="$3"
  shift 3
  local env_prefix=("$@")

  local actual_exit
  CLAUDE_PROJECT_DIR="$REPO_ROOT" "${env_prefix[@]}" bash "$GATE" < "$json_file" >/dev/null 2>"$WORKDIR/stderr.$$"
  actual_exit=$?

  if [ "$actual_exit" -eq "$expected_exit" ]; then
    echo "ok - $name"
  else
    echo "not ok - $name (expected exit $expected_exit, got $actual_exit)"
    cat "$WORKDIR/stderr.$$" >&2
    FAIL=1
  fi
  rm -f "$WORKDIR/stderr.$$"
}

make_write_json() {
  local content_file="$1"
  local out_file="$2"
  local path="$3"
  python3 - "$content_file" "$out_file" "$path" <<'PYEOF'
import json, sys
content_file, out_file, path = sys.argv[1], sys.argv[2], sys.argv[3]
with open(content_file, "r", encoding="utf-8") as f:
    content = f.read()
payload = {"tool_name": "Write", "tool_input": {"file_path": path, "content": content}}
with open(out_file, "w", encoding="utf-8") as f:
    json.dump(payload, f)
PYEOF
}

make_edit_json() {
  local out_file="$1" path="$2" old="$3" new="$4" replace_all="$5"
  python3 - "$out_file" "$path" "$old" "$new" "$replace_all" <<'PYEOF'
import json, sys
out_file, path, old, new, replace_all = sys.argv[1:6]
payload = {"tool_name": "Edit", "tool_input": {
    "file_path": path, "old_string": old, "new_string": new,
    "replace_all": replace_all == "true",
}}
with open(out_file, "w", encoding="utf-8") as f:
    json.dump(payload, f)
PYEOF
}

make_multiedit_json() {
  # $1 = out_file, $2 = path, $3.. = triples old|new|replace_all
  local out_file="$1" path="$2"
  shift 2
  python3 - "$out_file" "$path" "$@" <<'PYEOF'
import json, sys
out_file, path = sys.argv[1], sys.argv[2]
triples = sys.argv[3:]
edits = []
for i in range(0, len(triples), 3):
    old, new, replace_all = triples[i], triples[i + 1], triples[i + 2]
    edits.append({"old_string": old, "new_string": new, "replace_all": replace_all == "true"})
payload = {"tool_name": "MultiEdit", "tool_input": {"file_path": path, "edits": edits}}
with open(out_file, "w", encoding="utf-8") as f:
    json.dump(payload, f)
PYEOF
}

make_bash_json() {
  local out_file="$1" command="$2"
  python3 - "$out_file" "$command" <<'PYEOF'
import json, sys
out_file, command = sys.argv[1], sys.argv[2]
payload = {"tool_name": "Bash", "tool_input": {"command": command}}
with open(out_file, "w", encoding="utf-8") as f:
    json.dump(payload, f)
PYEOF
}

# (a) proposal-path Write with rationale statement -> exit 0
CASE_A_CONTENT="$WORKDIR/case_a.content"
CASE_A_JSON="$WORKDIR/case_a.json"
printf 'This serves the checkout-cta decision -> we shorten the label because it reduces cognitive load.\n' > "$CASE_A_CONTENT"
make_write_json "$CASE_A_CONTENT" "$CASE_A_JSON" "$PROPOSAL_TARGET"
run_case "(a) proposal with rationale -> exit 0" "$CASE_A_JSON" 0

# (b) proposal-path Write missing rationale -> exit 2
CASE_B_CONTENT="$WORKDIR/case_b.content"
CASE_B_JSON="$WORKDIR/case_b.json"
printf 'This is a proposal about the checkout CTA copy with no linking statement at all.\n' > "$CASE_B_CONTENT"
make_write_json "$CASE_B_CONTENT" "$CASE_B_JSON" "$PROPOSAL_TARGET"
run_case "(b) proposal missing rationale -> exit 2" "$CASE_B_JSON" 2

# (c) report-path Write, two copy string sections, both with construction -> exit 0
CASE_C_CONTENT="$WORKDIR/case_c.content"
CASE_C_JSON="$WORKDIR/case_c.json"
cat > "$CASE_C_CONTENT" <<'EOF'
## Copy string: Checkout Button

serves the checkout-button decision -> because it clarifies the next step

## Copy string: Error Banner

serves the error-banner decision -> because it reduces confusion
EOF
make_write_json "$CASE_C_CONTENT" "$CASE_C_JSON" "$REPORT_TARGET"
run_case "(c) report both sections have rationale -> exit 0" "$CASE_C_JSON" 0

# (d) report-path Write, one of two sections missing construction -> exit 2, stderr names section
CASE_D_CONTENT="$WORKDIR/case_d.content"
CASE_D_JSON="$WORKDIR/case_d.json"
cat > "$CASE_D_CONTENT" <<'EOF'
## Copy string: Checkout Button

serves the checkout-button decision -> because it clarifies the next step

## Copy string: Error Banner

this text has no linking construction of any kind at all here
EOF
make_write_json "$CASE_D_CONTENT" "$CASE_D_JSON" "$REPORT_TARGET"
CLAUDE_PROJECT_DIR="$REPO_ROOT" bash "$GATE" < "$CASE_D_JSON" > "$WORKDIR/d.out.txt" 2>"$WORKDIR/d.err.txt"
d_exit=$?
if [ "$d_exit" -eq 2 ] && grep -q "Error Banner" "$WORKDIR/d.err.txt"; then
  echo "ok - (d) report missing section -> exit 2, stderr names section"
else
  echo "not ok - (d) report missing section -> exit 2, stderr names section (exit=$d_exit, stderr: $(cat "$WORKDIR/d.err.txt"))"
  FAIL=1
fi

# (e) file_path outside both regexes -> exit 0
CASE_E_JSON="$WORKDIR/case_e.json"
CASE_E_CONTENT="$WORKDIR/case_e.content"
printf 'anything at all\n' > "$CASE_E_CONTENT"
make_write_json "$CASE_E_CONTENT" "$CASE_E_JSON" "docs/issue-12/specs/random.md"
run_case "(e) out-of-scope path -> exit 0" "$CASE_E_JSON" 0

# (f) malformed JSON: truncated -> exit 2
CASE_F_JSON="$WORKDIR/case_f.json"
printf '{not valid json' > "$CASE_F_JSON"
run_case "(f) malformed JSON (truncated) -> exit 2" "$CASE_F_JSON" 2

# (f2) malformed JSON: non-object top level -> exit 2
CASE_F2_JSON="$WORKDIR/case_f2.json"
printf '[1, 2, 3]' > "$CASE_F2_JSON"
run_case "(f2) malformed JSON (non-object top level) -> exit 2" "$CASE_F2_JSON" 2

# (f3) malformed JSON: empty payload -> exit 2
CASE_F3_JSON="$WORKDIR/case_f3.json"
: > "$CASE_F3_JSON"
run_case "(f3) malformed JSON (empty payload) -> exit 2" "$CASE_F3_JSON" 2

# (g) kill switch recognized on-value -> exit 0 unconditionally, even with bad content
run_case "(g) kill switch set (1) -> exit 0 unconditionally" "$CASE_B_JSON" 0 env CONTENT_DESIGN_DECISION_RATIONALE_GATE_OFF=1

# (h) kill switch set to an UNRECOGNIZED value ('typo') -> gate stays active -> exit 2
run_case "(h) kill switch unrecognized value ('typo') -> gate stays active -> exit 2" "$CASE_B_JSON" 2 env CONTENT_DESIGN_DECISION_RATIONALE_GATE_OFF=typo

# (i) Edit with replace_all: true against a multiply-occurring old_string
mkdir -p "$WORKDIR/$(dirname "$REPORT_TARGET")"
EDIT_BASE_FILE="$WORKDIR/$REPORT_TARGET"
cat > "$EDIT_BASE_FILE" <<'EOF'
## Copy string: Save Button

placeholder rationale marker -> because reasons apply

## Copy string: Cancel Button

placeholder rationale marker -> because reasons apply
EOF
CASE_I_JSON="$WORKDIR/case_i.json"
make_edit_json "$CASE_I_JSON" "$EDIT_BASE_FILE" "placeholder rationale marker -> because reasons apply" "no linking construction left here at all" true
# replace_all=true must replace BOTH occurrences -> neither section retains a
# rationale construction -> deny
run_case "(i) Edit replace_all=true on multiply-occurring old_string -> exit 2 (both sections stripped)" "$CASE_I_JSON" 2 env CLAUDE_PROJECT_DIR="$WORKDIR"

# (j) MultiEdit with mixed replace_all true/false in one call
cat > "$EDIT_BASE_FILE" <<'EOF'
## Copy string: Save Button

placeholder rationale marker -> because reasons apply

## Copy string: Cancel Button

placeholder rationale marker -> because reasons apply
EOF
CASE_J_JSON="$WORKDIR/case_j.json"
# first edit's replace_all=false touches only the FIRST occurrence (Save
# Button section) leaving it without a rationale construction; second edit's
# replace_all=true is an unrelated header rewrite. Cancel Button section
# keeps its untouched rationale marker -> Save Button lacks one -> deny.
make_multiedit_json "$CASE_J_JSON" "$EDIT_BASE_FILE" \
  "placeholder rationale marker -> because reasons apply" "no linking construction left here" false \
  "## Copy string: Cancel Button" "## Copy string: Cancel Button (updated)" true
run_case "(j) MultiEdit mixed replace_all true/false -> exit 2 (first section stripped, second intact)" "$CASE_J_JSON" 2 env CLAUDE_PROJECT_DIR="$WORKDIR"

# (k) absolute file_path matching the same scope a relative fixture matches
CASE_K_CONTENT="$WORKDIR/case_k.content"
CASE_K_JSON="$WORKDIR/case_k.json"
cat > "$CASE_K_CONTENT" <<'EOF'
## Copy string: Confirm Button

serves the confirm-button decision -> because it reduces ambiguity
EOF
make_write_json "$CASE_K_CONTENT" "$CASE_K_JSON" "$REPO_ROOT/$REPORT_TARGET"
run_case "(k) absolute file_path in scope -> exit 0" "$CASE_K_JSON" 0

# (k2) ./-prefixed relative variant of the same in-scope target
CASE_K2_CONTENT="$WORKDIR/case_k2.content"
CASE_K2_JSON="$WORKDIR/case_k2.json"
cat > "$CASE_K2_CONTENT" <<'EOF'
## Copy string: Confirm Button

serves the confirm-button decision -> because it reduces ambiguity
EOF
make_write_json "$CASE_K2_CONTENT" "$CASE_K2_JSON" "./$REPORT_TARGET"
run_case "(k2) ./-prefixed file_path in scope -> exit 0" "$CASE_K2_JSON" 0

# (l) Bash-tool write reaching the same target a Write-tool call would hit -> deny
CASE_L_JSON="$WORKDIR/case_l.json"
make_bash_json "$CASE_L_JSON" "printf 'stuff' > $REPORT_TARGET"
run_case "(l) Bash-tool write to gated report target -> exit 2" "$CASE_L_JSON" 2

# (m) REPORT-mode document with NO copy-string headers at all -> must DENY
# explicitly (defect-3 fix: no more silent whole-document fallback)
CASE_M_CONTENT="$WORKDIR/case_m.content"
CASE_M_JSON="$WORKDIR/case_m.json"
printf 'This serves the overall decision -> because it improves clarity, but has no copy-string headers.\n' > "$CASE_M_CONTENT"
make_write_json "$CASE_M_CONTENT" "$CASE_M_JSON" "$REPORT_TARGET"
CLAUDE_PROJECT_DIR="$REPO_ROOT" bash "$GATE" < "$CASE_M_JSON" > "$WORKDIR/m.out.txt" 2>"$WORKDIR/m.err.txt"
m_exit=$?
if [ "$m_exit" -eq 2 ] && grep -q "no per-string section header found" "$WORKDIR/m.err.txt"; then
  echo "ok - (m) report with no copy-string headers -> exit 2, explicit deny (defect-3 regression)"
else
  echo "not ok - (m) report with no copy-string headers -> exit 2, explicit deny (exit=$m_exit, stderr: $(cat "$WORKDIR/m.err.txt"))"
  FAIL=1
fi

# (n) CLAUDE_PLUGIN_ROOT_CORE pointed nowhere -> guarded source must deny, not allow (issue-75/issue-13)
run_case "(n) missing core (CLAUDE_PLUGIN_ROOT_CORE nonexistent) -> exit 2, not silent-allow" "$CASE_A_JSON" 2 env CLAUDE_PLUGIN_ROOT_CORE="$WORKDIR/no-such-core"

if [ "${DEBUG_KEEP_WORKDIR:-}" != "1" ]; then
  rm -rf "$WORKDIR"
else
  echo "WORKDIR=$WORKDIR" >&2
fi

if [ "$FAIL" -ne 0 ]; then
  exit 1
fi
exit 0
