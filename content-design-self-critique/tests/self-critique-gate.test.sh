#!/usr/bin/env bash
# TAP-ish test harness for hooks/self-critique-gate.sh
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GATE="$SCRIPT_DIR/../hooks/self-critique-gate.sh"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TARGET_FILE="docs/issue-7/reports/content-design.md"

# Local multi-repo dev layout: tokenmaxxxer-core is checked out as a sibling
# repo, not a sibling directory of this plugin (production installs core as
# an actual sibling plugin dir, matched by the gate's own "../../core"
# fallback). Point CLAUDE_PLUGIN_ROOT_CORE at it so this test suite runs
# without a live plugin install; override the env var to point elsewhere.
export CLAUDE_PLUGIN_ROOT_CORE="${CLAUDE_PLUGIN_ROOT_CORE:-$HOME/tokenmaxxxer/tokenmaxxxer-core/core}"

WORKDIR="${TMPDIR:-/tmp}/self-critique-gate-test.$$"
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

# --- case (a): full section, all markers present, self-critique last -> exit 0 ---
CASE_A_CONTENT="$WORKDIR/content_a.md"
cat > "$CASE_A_CONTENT" <<'EOF'
## Copy string: checkout-cta

Decision: rationale -> ties to user hesitation at checkout.
Tone axis: formal vs casual, chose casual for approachability.
A/B variant: measurable signal via click-through rate.

self-critique: rationale ties to the checkout decision correctly, tone axis formal/casual justified, A/B signal is measurable.
EOF
CASE_A_JSON="$WORKDIR/case_a.json"
make_write_json "$CASE_A_CONTENT" "$CASE_A_JSON" "$TARGET_FILE"
run_case "case (a) valid section passes -> exit 0" "$CASE_A_JSON" 0

# --- case (b): section missing self-critique entirely -> exit 2 ---
CASE_B_CONTENT="$WORKDIR/content_b.md"
cat > "$CASE_B_CONTENT" <<'EOF'
## Copy string: checkout-cta

Decision: rationale -> ties to user hesitation at checkout.
Tone axis: formal vs casual, chose casual for approachability.
A/B variant: measurable signal via click-through rate.
EOF
CASE_B_JSON="$WORKDIR/case_b.json"
make_write_json "$CASE_B_CONTENT" "$CASE_B_JSON" "$TARGET_FILE"
run_case "case (b) missing self-critique denied -> exit 2" "$CASE_B_JSON" 2

# --- case (c): self-critique appears before rationale marker (ordering violation) -> exit 2 ---
CASE_C_CONTENT="$WORKDIR/content_c.md"
cat > "$CASE_C_CONTENT" <<'EOF'
## Copy string: checkout-cta

self-critique: rationale ties to the checkout decision correctly, tone axis formal/casual justified, A/B signal is measurable.

Decision: rationale -> ties to user hesitation at checkout.
Tone axis: formal vs casual, chose casual for approachability.
A/B variant: measurable signal via click-through rate.
EOF
CASE_C_JSON="$WORKDIR/case_c.json"
make_write_json "$CASE_C_CONTENT" "$CASE_C_JSON" "$TARGET_FILE"
run_case "case (c) ordering violation denied -> exit 2" "$CASE_C_JSON" 2

# --- case (d): file_path outside scope -> exit 0 ---
CASE_D_CONTENT="$WORKDIR/content_d.md"
cat > "$CASE_D_CONTENT" <<'EOF'
## Copy string: checkout-cta

no self-critique here at all
EOF
CASE_D_JSON="$WORKDIR/case_d.json"
make_write_json "$CASE_D_CONTENT" "$CASE_D_JSON" "docs/issue-7/other/notes.md"
run_case "case (d) out of scope passes -> exit 0" "$CASE_D_JSON" 0

# --- case (e) malformed JSON: truncated -> exit 2 ---
CASE_E_JSON="$WORKDIR/case_e.json"
printf '{not valid json' > "$CASE_E_JSON"
run_case "case (e) malformed JSON (truncated) -> exit 2" "$CASE_E_JSON" 2

# --- case (e2) malformed JSON: non-object top level -> exit 2 ---
CASE_E2_JSON="$WORKDIR/case_e2.json"
printf '[1, 2, 3]' > "$CASE_E2_JSON"
run_case "case (e2) malformed JSON (non-object top level) -> exit 2" "$CASE_E2_JSON" 2

# --- case (e3) malformed JSON: empty payload -> exit 2 ---
CASE_E3_JSON="$WORKDIR/case_e3.json"
: > "$CASE_E3_JSON"
run_case "case (e3) malformed JSON (empty payload) -> exit 2" "$CASE_E3_JSON" 2

# --- case (f): kill switch set (recognized on-value), unconditional pass even for invalid content ---
CASE_F_CONTENT="$WORKDIR/content_f.md"
cat > "$CASE_F_CONTENT" <<'EOF'
## Copy string: checkout-cta

no self-critique here at all
EOF
CASE_F_JSON="$WORKDIR/case_f.json"
make_write_json "$CASE_F_CONTENT" "$CASE_F_JSON" "$TARGET_FILE"
run_case "case (f) kill switch set (1) -> exit 0 unconditionally" "$CASE_F_JSON" 0 env CONTENT_DESIGN_SELF_CRITIQUE_GATE_OFF=1

# --- case (g): kill switch set to an UNRECOGNIZED value -> gate stays active, bad content -> exit 2 ---
run_case "case (g) kill switch unrecognized value ('typo') -> gate stays active -> exit 2" "$CASE_F_JSON" 2 env CONTENT_DESIGN_SELF_CRITIQUE_GATE_OFF=typo

# --- case (h): Edit with replace_all: true against a multiply-occurring old_string ---
mkdir -p "$WORKDIR/$(dirname "$TARGET_FILE")"
EDIT_BASE_FILE="$WORKDIR/$TARGET_FILE"
cat > "$EDIT_BASE_FILE" <<'EOF'
## Copy string: checkout-cta

Decision: rationale -> ties to user hesitation at checkout.
Tone axis: formal vs casual, chose casual for approachability.
A/B variant: measurable signal via click-through rate.

TODO self-critique
TODO self-critique
EOF
CASE_H_JSON="$WORKDIR/case_h.json"
make_edit_json "$CASE_H_JSON" "$EDIT_BASE_FILE" "TODO self-critique" "self-critique: rationale, tone, and A/B all check out" true
# replace_all=true replaces BOTH placeholder lines -> two genuine self-critique
# notes remain, both after the rationale/tone/A-B content -> passes. A buggy
# first-occurrence-only implementation would leave one bare "TODO
# self-critique" line with no genuine reference, and would deny.
run_case "case (h) Edit replace_all=true on multiply-occurring old_string -> exit 0 (both replaced)" "$CASE_H_JSON" 0 env CLAUDE_PROJECT_DIR="$WORKDIR"

# --- case (i): MultiEdit with mixed replace_all true/false in one call ---
cat > "$EDIT_BASE_FILE" <<'EOF'
## Copy string: checkout-cta

PLACEHOLDER
Decision: rationale -> ties to user hesitation at checkout.
Tone axis: formal vs casual, chose casual for approachability.
A/B variant: measurable signal via click-through rate.

TODO self-critique
TODO self-critique
EOF
CASE_I_JSON="$WORKDIR/case_i.json"
make_multiedit_json "$CASE_I_JSON" "$EDIT_BASE_FILE" \
  "PLACEHOLDER" "" false \
  "TODO self-critique" "self-critique: rationale, tone, and A/B all check out" true
# second edit's replace_all=true must replace BOTH TODO lines with genuine
# self-critique text ordered after the rationale/tone/A-B content -> passes.
run_case "case (i) MultiEdit mixed replace_all true/false -> exit 0 (replace_all honored per-edit)" "$CASE_I_JSON" 0 env CLAUDE_PROJECT_DIR="$WORKDIR"

# --- case (j): absolute file_path matching the same scope a relative fixture matches ---
CASE_J_CONTENT="$WORKDIR/content_j.md"
cat > "$CASE_J_CONTENT" <<'EOF'
## Copy string: checkout-cta

Decision: rationale -> ties to user hesitation at checkout.
Tone axis: formal vs casual, chose casual for approachability.
A/B variant: measurable signal via click-through rate.

self-critique: rationale ties to the checkout decision correctly, tone axis formal/casual justified, A/B signal is measurable.
EOF
CASE_J_JSON="$WORKDIR/case_j.json"
make_write_json "$CASE_J_CONTENT" "$CASE_J_JSON" "$REPO_ROOT/$TARGET_FILE"
run_case "case (j) absolute file_path in scope -> exit 0" "$CASE_J_JSON" 0

# --- case (j2): ./-prefixed relative variant of the same in-scope target ---
CASE_J2_JSON="$WORKDIR/case_j2.json"
make_write_json "$CASE_J_CONTENT" "$CASE_J2_JSON" "./$TARGET_FILE"
run_case "case (j2) ./-prefixed file_path in scope -> exit 0" "$CASE_J2_JSON" 0

# --- case (k): Bash-tool write reaching the same target a Write-tool call would hit -> deny ---
CASE_K_JSON="$WORKDIR/case_k.json"
make_bash_json "$CASE_K_JSON" "printf 'stuff' > docs/issue-7/reports/content-design.md"
run_case "case (k) Bash-tool write to gated target -> exit 2" "$CASE_K_JSON" 2

# --- case (l): no per-string header at all -> must now deny explicitly (defect 3 regression) ---
CASE_L_CONTENT="$WORKDIR/content_l.md"
cat > "$CASE_L_CONTENT" <<'EOF'
Just a document with no copy-string headers at all.

self-critique: this used to silently pass via whole-doc fallback with
ordering skipped -- rationale, tone, A/B are all mentioned here too.
EOF
CASE_L_JSON="$WORKDIR/case_l.json"
make_write_json "$CASE_L_CONTENT" "$CASE_L_JSON" "$TARGET_FILE"
run_case "case (l) no per-string section header -> exit 2 (defect 3 regression)" "$CASE_L_JSON" 2

# --- case (m): CLAUDE_PLUGIN_ROOT_CORE pointed nowhere -> guarded source must deny, not allow (issue-75/issue-13) ---
run_case "case (m) missing core (CLAUDE_PLUGIN_ROOT_CORE nonexistent) -> exit 2, not silent-allow" "$CASE_A_JSON" 2 env CLAUDE_PLUGIN_ROOT_CORE="$WORKDIR/no-such-core"

# --- case (n): mktemp must not be invoked by the gate (no-mktemp regression, issue-16) ---
mkdir -p "$WORKDIR/fake-bin"
cat > "$WORKDIR/fake-bin/mktemp" <<EOF
#!/usr/bin/env bash
touch "$WORKDIR/mktemp-invoked.marker"
exit 1
EOF
chmod +x "$WORKDIR/fake-bin/mktemp"
run_case "case (n) gate does not invoke mktemp -> exit 0" "$CASE_A_JSON" 0 env PATH="$WORKDIR/fake-bin:$PATH"
if [ -e "$WORKDIR/mktemp-invoked.marker" ]; then
  echo "not ok - case (n2) mktemp marker must be absent after gate run"
  FAIL=1
else
  echo "ok - case (n2) mktemp marker absent after gate run"
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
