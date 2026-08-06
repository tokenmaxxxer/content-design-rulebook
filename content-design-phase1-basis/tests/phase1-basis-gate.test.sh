#!/usr/bin/env bash
# TAP-ish test harness for hooks/phase1-basis-gate.sh
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GATE="$SCRIPT_DIR/../hooks/phase1-basis-gate.sh"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TARGET_FILE="docs/issue-9/proposals/content-design-plan.md"

# Local multi-repo dev layout: tokenmaxxxer-core is checked out as a sibling
# repo, not a sibling directory of this plugin (production installs core as
# an actual sibling plugin dir, matched by the gate's own "../../core"
# fallback). Point CLAUDE_PLUGIN_ROOT_CORE at it so this test suite runs
# without a live plugin install; override the env var to point elsewhere.
export CLAUDE_PLUGIN_ROOT_CORE="${CLAUDE_PLUGIN_ROOT_CORE:-$HOME/tokenmaxxxer/tokenmaxxxer-core/core}"

WORKDIR="${TMPDIR:-/tmp}/phase1-basis-gate-test.$$"
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

# (a) proposal with survey.md path + scout-brief -> Write -> exit 0
CASE_A_CONTENT="$WORKDIR/case_a.content"
CASE_A_JSON="$WORKDIR/case_a.json"
printf 'See docs/issue-9/reports/content-design/survey.md and the scout-brief for basis.\n' > "$CASE_A_CONTENT"
make_write_json "$CASE_A_CONTENT" "$CASE_A_JSON" "$TARGET_FILE"
run_case "content with survey path + scout-brief passes" "$CASE_A_JSON" 0

# (b) proposal text with neither -> exit 2
CASE_B_CONTENT="$WORKDIR/case_b.content"
CASE_B_JSON="$WORKDIR/case_b.json"
printf 'No basis stated here at all.\n' > "$CASE_B_CONTENT"
make_write_json "$CASE_B_CONTENT" "$CASE_B_JSON" "$TARGET_FILE"
run_case "content with no basis denies" "$CASE_B_JSON" 2

# (c) file_path outside scope regex -> exit 0 (gate silent)
CASE_C_CONTENT="$WORKDIR/case_c.content"
CASE_C_JSON="$WORKDIR/case_c.json"
printf 'No basis stated here at all.\n' > "$CASE_C_CONTENT"
make_write_json "$CASE_C_CONTENT" "$CASE_C_JSON" "docs/issue-9/reports/content-design.md"
run_case "out-of-scope path passes silently" "$CASE_C_JSON" 0

# (d) malformed JSON: truncated -> exit 2
CASE_D_JSON="$WORKDIR/case_d.json"
printf '{not valid json' > "$CASE_D_JSON"
run_case "malformed JSON (truncated) denies" "$CASE_D_JSON" 2

# (d2) malformed JSON: non-object top level -> exit 2
CASE_D2_JSON="$WORKDIR/case_d2.json"
printf '[1, 2, 3]' > "$CASE_D2_JSON"
run_case "malformed JSON (non-object top level) denies" "$CASE_D2_JSON" 2

# (d3) malformed JSON: empty payload -> exit 2
CASE_D3_JSON="$WORKDIR/case_d3.json"
: > "$CASE_D3_JSON"
run_case "malformed JSON (empty payload) denies" "$CASE_D3_JSON" 2

# (e) kill switch recognized on-value -> exit 0 unconditionally, even with bad content
CASE_E_CONTENT="$WORKDIR/case_e.content"
CASE_E_JSON="$WORKDIR/case_e.json"
printf 'No basis stated here at all.\n' > "$CASE_E_CONTENT"
make_write_json "$CASE_E_CONTENT" "$CASE_E_JSON" "$TARGET_FILE"
run_case "kill switch set (1) bypasses gate unconditionally" "$CASE_E_JSON" 0 env CONTENT_DESIGN_PHASE1_BASIS_GATE_OFF=1

# (f) kill switch set to an UNRECOGNIZED value -> gate stays active, bad content -> exit 2
run_case "kill switch unrecognized value ('typo') -> gate stays active -> exit 2" "$CASE_E_JSON" 2 env CONTENT_DESIGN_PHASE1_BASIS_GATE_OFF=typo

# (g) Edit with replace_all: true against a multiply-occurring old_string
mkdir -p "$WORKDIR/$(dirname "$TARGET_FILE")"
EDIT_BASE_FILE="$WORKDIR/$TARGET_FILE"
printf 'scout-brief note\nscout-brief note\nNo other basis mentioned.\n' > "$EDIT_BASE_FILE"
CASE_G_JSON="$WORKDIR/case_g.json"
make_edit_json "$CASE_G_JSON" "$EDIT_BASE_FILE" "scout-brief note" "handled" true
# replace_all=true must replace BOTH occurrences -> zero scout-brief mentions left -> deny
run_case "Edit replace_all=true on multiply-occurring old_string -> exit 2 (0 scout-brief left)" "$CASE_G_JSON" 2 env CLAUDE_PROJECT_DIR="$WORKDIR"

# (h) MultiEdit with mixed replace_all true/false in one call
printf 'scout-brief note\nscout-brief note\nOther prose.\n' > "$EDIT_BASE_FILE"
CASE_H_JSON="$WORKDIR/case_h.json"
make_multiedit_json "$CASE_H_JSON" "$EDIT_BASE_FILE" \
  "scout-brief note" "fixed note" false \
  "Other prose." "Other prose (updated)." true
# first edit's replace_all=false must touch only the FIRST occurrence, leaving
# exactly one "scout-brief" mention -> passes
run_case "MultiEdit mixed replace_all true/false -> exit 0 (replace_all honored per-edit)" "$CASE_H_JSON" 0 env CLAUDE_PROJECT_DIR="$WORKDIR"

# (i) absolute file_path matching the same scope a relative fixture matches
CASE_I_CONTENT="$WORKDIR/case_i.content"
CASE_I_JSON="$WORKDIR/case_i.json"
printf 'Basis: scout-brief attached.\n' > "$CASE_I_CONTENT"
make_write_json "$CASE_I_CONTENT" "$CASE_I_JSON" "$REPO_ROOT/$TARGET_FILE"
run_case "absolute file_path in scope -> exit 0" "$CASE_I_JSON" 0

# (i2) ./-prefixed relative variant of the same in-scope target
CASE_I2_CONTENT="$WORKDIR/case_i2.content"
CASE_I2_JSON="$WORKDIR/case_i2.json"
printf 'Basis: scout-brief attached.\n' > "$CASE_I2_CONTENT"
make_write_json "$CASE_I2_CONTENT" "$CASE_I2_JSON" "./docs/issue-9/proposals/content-design-plan.md"
run_case "./-prefixed file_path in scope -> exit 0" "$CASE_I2_JSON" 0

# (j) Bash-tool write reaching the same target a Write-tool call would hit -> deny
CASE_J_JSON="$WORKDIR/case_j.json"
make_bash_json "$CASE_J_JSON" "printf 'stuff' > docs/issue-9/proposals/content-design-plan.md"
run_case "Bash-tool write to gated target -> exit 2" "$CASE_J_JSON" 2

# (k) CLAUDE_PLUGIN_ROOT_CORE pointed nowhere -> guarded source must deny, not allow (issue-75/issue-13)
run_case "missing core (CLAUDE_PLUGIN_ROOT_CORE nonexistent) -> exit 2, not silent-allow" "$CASE_A_JSON" 2 env CLAUDE_PLUGIN_ROOT_CORE="$WORKDIR/no-such-core"

# (l) mktemp must not be invoked by the gate anymore -- shadow it with a
# failing fake and confirm it is never called
mkdir -p "$WORKDIR/fake-bin"
cat > "$WORKDIR/fake-bin/mktemp" <<EOF
#!/usr/bin/env bash
touch "$WORKDIR/mktemp-invoked.marker"
exit 1
EOF
chmod +x "$WORKDIR/fake-bin/mktemp"
run_case "gate does not invoke mktemp" "$CASE_A_JSON" 0 env PATH="$WORKDIR/fake-bin:$PATH"
if [ -e "$WORKDIR/mktemp-invoked.marker" ]; then
  echo "not ok - gate does not invoke mktemp (marker file present)"
  FAIL=1
  rm -f "$WORKDIR/mktemp-invoked.marker"
fi

if [ "${DEBUG_KEEP_WORKDIR:-}" != "1" ]; then
  rm -rf "$WORKDIR"
else
  echo "WORKDIR=$WORKDIR" >&2
fi

if [ "$FAIL" -ne 0 ]; then
  exit 1
fi
exit 0
