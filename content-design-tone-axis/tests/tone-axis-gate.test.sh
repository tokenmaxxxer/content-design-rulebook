#!/usr/bin/env bash
# TAP-ish test harness for hooks/tone-axis-gate.sh
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GATE="$SCRIPT_DIR/../hooks/tone-axis-gate.sh"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TARGET_FILE="docs/issue-7/reports/content-design.md"

# Local multi-repo dev layout: tokenmaxxxer-core is checked out as a sibling
# repo, not a sibling directory of this plugin (production installs core as
# an actual sibling plugin dir, matched by the gate's own "../../core"
# fallback). Point CLAUDE_PLUGIN_ROOT_CORE at it so this test suite runs
# without a live plugin install; override the env var to point elsewhere.
export CLAUDE_PLUGIN_ROOT_CORE="${CLAUDE_PLUGIN_ROOT_CORE:-$HOME/tokenmaxxxer/tokenmaxxxer-core/core}"

WORKDIR="${TMPDIR:-/tmp}/tone-axis-gate-test.$$"
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

run_case_capture() {
  # Same as run_case, but also asserts stderr contains a given substring.
  local name="$1" json_file="$2" expected_exit="$3" needle="$4"
  shift 4
  local env_prefix=("$@")

  local actual_exit out
  out="$(CLAUDE_PROJECT_DIR="$REPO_ROOT" "${env_prefix[@]}" bash "$GATE" < "$json_file" 2>&1 1>/dev/null)"
  actual_exit=$?

  if [ "$actual_exit" -eq "$expected_exit" ] && printf '%s' "$out" | grep -qF "$needle"; then
    echo "ok - $name"
  else
    echo "not ok - $name (expected exit $expected_exit / needle '$needle', got exit $actual_exit, out: $out)"
    FAIL=1
  fi
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

# (a) section names an axis -> PASS exit 0
CASE_A_CONTENT="$WORKDIR/case_a.content"
CASE_A_JSON="$WORKDIR/case_a.json"
printf '## Copy string: Save button\n\nFormal <-> Casual: leaning formal because legal copy\n\nBody text.\n' > "$CASE_A_CONTENT"
make_write_json "$CASE_A_CONTENT" "$CASE_A_JSON" "$TARGET_FILE"
run_case "case (a) axis named -> exit 0" "$CASE_A_JSON" 0

# (b) explicit skip with reason -> PASS exit 0
CASE_B_CONTENT="$WORKDIR/case_b.content"
CASE_B_JSON="$WORKDIR/case_b.json"
printf '## Copy string: Error message\n\ntone-axis: skip, reason: fixed legal string\n' > "$CASE_B_CONTENT"
make_write_json "$CASE_B_CONTENT" "$CASE_B_JSON" "$TARGET_FILE"
run_case "case (b) explicit skip with reason -> exit 0" "$CASE_B_JSON" 0

# (c) neither axis nor skip -> DENY exit 2, message names tone-axis + header
CASE_C_CONTENT="$WORKDIR/case_c.content"
CASE_C_JSON="$WORKDIR/case_c.json"
printf '## Copy string: Confirm dialog\n\nJust some body text with no tone information at all.\n' > "$CASE_C_CONTENT"
make_write_json "$CASE_C_CONTENT" "$CASE_C_JSON" "$TARGET_FILE"
run_case "case (c) neither present -> exit 2" "$CASE_C_JSON" 2
run_case_capture "case (c) message names tone-axis" "$CASE_C_JSON" 2 "tone-axis"
run_case_capture "case (c) message names section header" "$CASE_C_JSON" 2 "Copy string: Confirm dialog"

# (d) file_path outside scope -> PASS exit 0
CASE_D_JSON="$WORKDIR/case_d.json"
make_write_json "$CASE_C_CONTENT" "$CASE_D_JSON" "docs/issue-7/notes.md"
run_case "case (d) out of scope -> exit 0" "$CASE_D_JSON" 0

# (e) malformed JSON: truncated -> exit 2
CASE_E_JSON="$WORKDIR/case_e.json"
printf '{not valid json' > "$CASE_E_JSON"
run_case "case (e) malformed JSON (truncated) -> exit 2" "$CASE_E_JSON" 2

# (e2) malformed JSON: non-object top level -> exit 2
CASE_E2_JSON="$WORKDIR/case_e2.json"
printf '[1, 2, 3]' > "$CASE_E2_JSON"
run_case "case (e2) malformed JSON (non-object top level) -> exit 2" "$CASE_E2_JSON" 2

# (e3) malformed JSON: empty payload -> exit 2
CASE_E3_JSON="$WORKDIR/case_e3.json"
: > "$CASE_E3_JSON"
run_case "case (e3) malformed JSON (empty payload) -> exit 2" "$CASE_E3_JSON" 2

# (f) kill switch recognized on-value -> exit 0 unconditionally, even with bad content
CASE_F_JSON="$WORKDIR/case_f.json"
make_write_json "$CASE_C_CONTENT" "$CASE_F_JSON" "$TARGET_FILE"
run_case "case (f) kill switch set (1) -> exit 0 unconditionally" "$CASE_F_JSON" 0 env CONTENT_DESIGN_TONE_AXIS_GATE_OFF=1

# (g) kill switch set to an UNRECOGNIZED value -> gate stays active, bad content -> exit 2
run_case "case (g) kill switch unrecognized value ('typo') -> gate stays active -> exit 2" "$CASE_F_JSON" 2 env CONTENT_DESIGN_TONE_AXIS_GATE_OFF=typo

# (h) Edit with replace_all: true against a multiply-occurring old_string
#     ("formal" is the only axis word present, twice) -> replace_all removes
#     BOTH occurrences -> zero axis words left -> deny.
mkdir -p "$WORKDIR/$(dirname "$TARGET_FILE")"
EDIT_BASE_FILE="$WORKDIR/$TARGET_FILE"
printf '## Copy string: Save button\n\nformal note one\nformal note two\n' > "$EDIT_BASE_FILE"
CASE_H_JSON="$WORKDIR/case_h.json"
make_edit_json "$CASE_H_JSON" "$EDIT_BASE_FILE" "formal" "neutral" true
run_case "case (h) Edit replace_all=true on multiply-occurring axis word -> exit 2 (0 axis words left)" "$CASE_H_JSON" 2 env CLAUDE_PROJECT_DIR="$WORKDIR"

# (h2) same base file/edit but replace_all=false -> only FIRST occurrence
#      replaced, one "formal" remains -> pass, proving replace_all is honored
#      (not just always-first-occurrence).
CASE_H2_JSON="$WORKDIR/case_h2.json"
make_edit_json "$CASE_H2_JSON" "$EDIT_BASE_FILE" "formal" "neutral" false
run_case "case (h2) Edit replace_all=false leaves one axis word -> exit 0" "$CASE_H2_JSON" 0 env CLAUDE_PROJECT_DIR="$WORKDIR"

# (i) MultiEdit with mixed replace_all true/false in one call
printf '## Copy string: Save button\n\nformal note one\nformal note two\nOTHER OTHER\n' > "$EDIT_BASE_FILE"
CASE_I_JSON="$WORKDIR/case_i.json"
make_multiedit_json "$CASE_I_JSON" "$EDIT_BASE_FILE" \
  "formal" "neutral" false \
  "OTHER OTHER" "casual note" true
# first edit's replace_all=false only touches the FIRST "formal", leaving one
# "formal" occurrence -> axis word present -> pass
run_case "case (i) MultiEdit mixed replace_all true/false -> exit 0 (replace_all honored per-edit)" "$CASE_I_JSON" 0 env CLAUDE_PROJECT_DIR="$WORKDIR"

# (j) absolute file_path matching the same scope a relative fixture matches
CASE_J_CONTENT="$WORKDIR/case_j.content"
CASE_J_JSON="$WORKDIR/case_j.json"
printf '## Copy string: Save button\n\nformal tone chosen for legal copy\n' > "$CASE_J_CONTENT"
make_write_json "$CASE_J_CONTENT" "$CASE_J_JSON" "$REPO_ROOT/$TARGET_FILE"
run_case "case (j) absolute file_path in scope -> exit 0" "$CASE_J_JSON" 0

# (j2) ./-prefixed relative variant of the same in-scope target
CASE_J2_JSON="$WORKDIR/case_j2.json"
make_write_json "$CASE_J_CONTENT" "$CASE_J2_JSON" "./docs/issue-7/reports/content-design.md"
run_case "case (j2) ./-prefixed file_path in scope -> exit 0" "$CASE_J2_JSON" 0

# (k) Bash-tool write reaching the same target a Write-tool call would hit -> deny
CASE_K_JSON="$WORKDIR/case_k.json"
make_bash_json "$CASE_K_JSON" "printf 'stuff' > docs/issue-7/reports/content-design.md"
run_case "case (k) Bash-tool write to gated target -> exit 2" "$CASE_K_JSON" 2

# (l) no per-string section header at all -> must deny explicitly (defect 3 regression;
#     previously fell back to whole-document check-and-could-pass)
CASE_L_CONTENT="$WORKDIR/case_l.content"
CASE_L_JSON="$WORKDIR/case_l.json"
printf 'Just a document with no copy-string headers at all, no formal/casual mention either.\n' > "$CASE_L_CONTENT"
make_write_json "$CASE_L_CONTENT" "$CASE_L_JSON" "$TARGET_FILE"
run_case "case (l) no per-string section header -> exit 2 (defect 3 regression)" "$CASE_L_JSON" 2

# (m) axis word present but in a DIFFERENT section than the one missing it ->
#     must still deny (defect 4 adjacency regression -- section-scoped, not
#     a flat substring search across the whole doc)
CASE_M_CONTENT="$WORKDIR/case_m.content"
CASE_M_JSON="$WORKDIR/case_m.json"
printf '## Copy string: Confirm dialog\n\nno tone information here at all.\n## Copy string: Save button (unrelated)\n\nformal tone chosen deliberately\n' > "$CASE_M_CONTENT"
make_write_json "$CASE_M_CONTENT" "$CASE_M_JSON" "$TARGET_FILE"
run_case "case (m) axis word present but in a different section -> exit 2 (defect 4 regression)" "$CASE_M_JSON" 2

# (n) CLAUDE_PLUGIN_ROOT_CORE pointed nowhere -> guarded source must deny, not allow (issue-75/issue-13)
run_case "case (n) missing core (CLAUDE_PLUGIN_ROOT_CORE nonexistent) -> exit 2, not silent-allow" "$CASE_A_JSON" 2 env CLAUDE_PLUGIN_ROOT_CORE="$WORKDIR/no-such-core"

# (o) mktemp must not be invoked by the gate -- shadow it on PATH with a
#     marker-dropping fake and confirm the marker never appears (issue-16
#     mktemp-removal regression).
mkdir -p "$WORKDIR/fake-bin"
cat > "$WORKDIR/fake-bin/mktemp" <<EOF
#!/usr/bin/env bash
touch "$WORKDIR/mktemp-invoked.marker"
exit 1
EOF
chmod +x "$WORKDIR/fake-bin/mktemp"
run_case "case (o) mktemp shadowed on PATH -> gate still passes -> exit 0" "$CASE_A_JSON" 0 env PATH="$WORKDIR/fake-bin:$PATH"
if [ -e "$WORKDIR/mktemp-invoked.marker" ]; then
  echo "not ok - case (o) mktemp was invoked by the gate (marker present)"
  FAIL=1
fi
rm -f "$WORKDIR/mktemp-invoked.marker"

if [ "${DEBUG_KEEP_WORKDIR:-}" != "1" ]; then
  rm -rf "$WORKDIR"
else
  echo "WORKDIR=$WORKDIR" >&2
fi

if [ "$FAIL" -ne 0 ]; then
  exit 1
fi
exit 0
