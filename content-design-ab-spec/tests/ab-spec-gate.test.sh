#!/usr/bin/env bash
# TAP-ish test harness for hooks/ab-spec-gate.sh
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GATE="$SCRIPT_DIR/../hooks/ab-spec-gate.sh"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TARGET_FILE="docs/issue-7/reports/content-design.md"

# Local multi-repo dev layout: tokenmaxxxer-core is checked out as a sibling
# repo, not a sibling directory of this plugin (production installs core as
# an actual sibling plugin dir, matched by the gate's own "../../core"
# fallback). Point CLAUDE_PLUGIN_ROOT_CORE at it so this test suite runs
# without a live plugin install; override the env var to point elsewhere.
export CLAUDE_PLUGIN_ROOT_CORE="${CLAUDE_PLUGIN_ROOT_CORE:-$HOME/tokenmaxxxer/tokenmaxxxer-core/core}"

WORKDIR="${TMPDIR:-/tmp}/ab-spec-gate-test.$$"
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

# (a) exactly one varied element + signal -> PASS exit 0
CASE_A_CONTENT="$WORKDIR/case_a.content"
CASE_A_JSON="$WORKDIR/case_a.json"
printf '## copy string one\nA/B: varied element = CTA color; signal = click-through rate\n' > "$CASE_A_CONTENT"
make_write_json "$CASE_A_CONTENT" "$CASE_A_JSON" "$TARGET_FILE"
run_case "case (a) valid A/B spec with varied element and signal -> exit 0" "$CASE_A_JSON" 0

# (b) explicit not-applicable + reason -> PASS exit 0
CASE_B_CONTENT="$WORKDIR/case_b.content"
CASE_B_JSON="$WORKDIR/case_b.json"
printf '## copy string two\nA/B: not applicable, reason: legal disclaimer text is fixed\n' > "$CASE_B_CONTENT"
make_write_json "$CASE_B_CONTENT" "$CASE_B_JSON" "$TARGET_FILE"
run_case "case (b) explicit not-applicable + reason -> exit 0" "$CASE_B_JSON" 0

# (c) two 'varied element' lines -> DENY exit 2
CASE_C_CONTENT="$WORKDIR/case_c.content"
CASE_C_JSON="$WORKDIR/case_c.json"
printf '## copy string three\nA/B: varied element = CTA color\nvaried element = button size\nsignal = click-through rate\n' > "$CASE_C_CONTENT"
make_write_json "$CASE_C_CONTENT" "$CASE_C_JSON" "$TARGET_FILE"
run_case "case (c) more than one varied element -> exit 2" "$CASE_C_JSON" 2

# (d) no A/B mention and no not-applicable -> DENY exit 2 (silently absent)
CASE_D_CONTENT="$WORKDIR/case_d.content"
CASE_D_JSON="$WORKDIR/case_d.json"
printf '## copy string four\nJust some prose describing the copy with no spec at all.\n' > "$CASE_D_CONTENT"
make_write_json "$CASE_D_CONTENT" "$CASE_D_JSON" "$TARGET_FILE"
run_case "case (d) missing A/B spec, silently absent -> exit 2" "$CASE_D_JSON" 2

# (e) file_path outside scope -> PASS exit 0
CASE_E_CONTENT="$WORKDIR/case_e.content"
CASE_E_JSON="$WORKDIR/case_e.json"
printf '## copy string five\nno a/b spec here either\n' > "$CASE_E_CONTENT"
make_write_json "$CASE_E_CONTENT" "$CASE_E_JSON" "docs/issue-7/reports/other-file.md"
run_case "case (e) file_path outside scope -> exit 0" "$CASE_E_JSON" 0

# (f) malformed JSON: truncated -> exit 2
CASE_F_JSON="$WORKDIR/case_f.json"
printf '{not valid json' > "$CASE_F_JSON"
run_case "case (f) malformed JSON (truncated) -> exit 2" "$CASE_F_JSON" 2

# (f2) malformed JSON: non-object top level -> exit 2
CASE_F2_JSON="$WORKDIR/case_f2.json"
printf '[1, 2, 3]' > "$CASE_F2_JSON"
run_case "case (f2) malformed JSON (non-object top level) -> exit 2" "$CASE_F2_JSON" 2

# (f3) malformed JSON: empty payload -> exit 2
CASE_F3_JSON="$WORKDIR/case_f3.json"
: > "$CASE_F3_JSON"
run_case "case (f3) malformed JSON (empty payload) -> exit 2" "$CASE_F3_JSON" 2

# (g) kill switch recognized on-value -> exit 0 unconditionally, even with bad content
CASE_G_CONTENT="$WORKDIR/case_g.content"
CASE_G_JSON="$WORKDIR/case_g.json"
printf '## copy string six\nJust prose with no A/B spec at all.\n' > "$CASE_G_CONTENT"
make_write_json "$CASE_G_CONTENT" "$CASE_G_JSON" "$TARGET_FILE"
run_case "case (g) kill switch set (1) -> exit 0 unconditionally" "$CASE_G_JSON" 0 env CONTENT_DESIGN_AB_SPEC_GATE_OFF=1

# (h) kill switch set to an UNRECOGNIZED value -> gate stays active, bad content -> exit 2
run_case "case (h) kill switch unrecognized value ('typo') -> gate stays active -> exit 2" "$CASE_G_JSON" 2 env CONTENT_DESIGN_AB_SPEC_GATE_OFF=typo

# (i) Edit with replace_all: true against a multiply-occurring old_string
mkdir -p "$WORKDIR/$(dirname "$TARGET_FILE")"
EDIT_BASE_FILE="$WORKDIR/$TARGET_FILE"
printf '## copy string seven\nA/B: variant note\nvaried element = X\nvaried element = X\nsignal = conv rate\n' > "$EDIT_BASE_FILE"
CASE_I_JSON="$WORKDIR/case_i.json"
make_edit_json "$CASE_I_JSON" "$EDIT_BASE_FILE" "varied element = X" "handled" true
# replace_all=true must replace BOTH occurrences -> zero "varied element" lines left -> deny
run_case "case (i) Edit replace_all=true on multiply-occurring old_string -> exit 2 (0 varied left)" "$CASE_I_JSON" 2 env CLAUDE_PROJECT_DIR="$WORKDIR"

# (j) MultiEdit with mixed replace_all true/false in one call
printf '## copy string eight\nA/B: variant test planned\nvaried element = A\nvaried element = A\nsignal = conv rate\n' > "$EDIT_BASE_FILE"
CASE_J_JSON="$WORKDIR/case_j.json"
make_multiedit_json "$CASE_J_JSON" "$EDIT_BASE_FILE" \
  "varied element = A" "fixed variant note" false \
  "A/B: variant test planned" "A/B: variant test planned (updated)" true
# first edit's replace_all=false must touch only the FIRST occurrence, leaving
# exactly one "varied element" line -> passes
run_case "case (j) MultiEdit mixed replace_all true/false -> exit 0 (replace_all honored per-edit)" "$CASE_J_JSON" 0 env CLAUDE_PROJECT_DIR="$WORKDIR"

# (k) absolute file_path matching the same scope a relative fixture matches
CASE_K_CONTENT="$WORKDIR/case_k.content"
CASE_K_JSON="$WORKDIR/case_k.json"
printf '## copy string nine\nA/B: varied element = CTA text; signal = click-through rate\n' > "$CASE_K_CONTENT"
make_write_json "$CASE_K_CONTENT" "$CASE_K_JSON" "$REPO_ROOT/$TARGET_FILE"
run_case "case (k) absolute file_path in scope -> exit 0" "$CASE_K_JSON" 0

# (k2) ./-prefixed relative variant of the same in-scope target
CASE_K2_CONTENT="$WORKDIR/case_k2.content"
CASE_K2_JSON="$WORKDIR/case_k2.json"
printf '## copy string ten\nA/B: varied element = CTA text; signal = click-through rate\n' > "$CASE_K2_CONTENT"
make_write_json "$CASE_K2_CONTENT" "$CASE_K2_JSON" "./docs/issue-7/reports/content-design.md"
run_case "case (k2) ./-prefixed file_path in scope -> exit 0" "$CASE_K2_JSON" 0

# (l) Bash-tool write reaching the same target a Write-tool call would hit -> deny
CASE_L_JSON="$WORKDIR/case_l.json"
make_bash_json "$CASE_L_JSON" "printf 'stuff' > docs/issue-7/reports/content-design.md"
run_case "case (l) Bash-tool write to gated target -> exit 2" "$CASE_L_JSON" 2

# (m) zero 'varied element' mentions (defect 2 regression: only >1 was rejected before)
CASE_M_CONTENT="$WORKDIR/case_m.content"
CASE_M_JSON="$WORKDIR/case_m.json"
printf '## copy string eleven\nA/B: variant test planned; signal = click-through rate\n' > "$CASE_M_CONTENT"
make_write_json "$CASE_M_CONTENT" "$CASE_M_JSON" "$TARGET_FILE"
run_case "case (m) zero varied-element mentions -> exit 2 (defect 2 regression)" "$CASE_M_JSON" 2

# (n) no per-string header at all -> must deny explicitly (defect 3 regression)
CASE_N_CONTENT="$WORKDIR/case_n.content"
CASE_N_JSON="$WORKDIR/case_n.json"
printf 'Just a document with no copy-string headers at all, no A/B mention either.\n' > "$CASE_N_CONTENT"
make_write_json "$CASE_N_CONTENT" "$CASE_N_JSON" "$TARGET_FILE"
run_case "case (n) no per-string section header -> exit 2 (defect 3 regression)" "$CASE_N_JSON" 2

# (o) keyword match exists in the document but outside the relevant section -> must still deny (defect 4 regression)
CASE_O_CONTENT="$WORKDIR/case_o.content"
CASE_O_JSON="$WORKDIR/case_o.json"
printf '## copy string twelve\nno spec here at all.\n## copy string thirteen (unrelated)\nvaried element = X; signal = Y\n' > "$CASE_O_CONTENT"
make_write_json "$CASE_O_CONTENT" "$CASE_O_JSON" "$TARGET_FILE"
run_case "case (o) A/B spec present but in a different section -> exit 2 (defect 4 regression)" "$CASE_O_JSON" 2

# (p) CLAUDE_PLUGIN_ROOT_CORE pointed nowhere -> guarded source must deny, not allow (issue-75/issue-13)
run_case "case (p) missing core (CLAUDE_PLUGIN_ROOT_CORE nonexistent) -> exit 2, not silent-allow" "$CASE_G_JSON" 2 env CLAUDE_PLUGIN_ROOT_CORE="$WORKDIR/no-such-core"

if [ "${DEBUG_KEEP_WORKDIR:-}" != "1" ]; then
  rm -rf "$WORKDIR"
else
  echo "WORKDIR=$WORKDIR" >&2
fi

if [ "$FAIL" -ne 0 ]; then
  exit 1
fi
exit 0
