#!/usr/bin/env bash
# TAP-ish test harness for hooks/ab-spec-gate.sh
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GATE="$SCRIPT_DIR/../hooks/ab-spec-gate.sh"
TARGET_FILE="docs/issue-7/reports/content-design.md"

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
  "${env_prefix[@]}" bash "$GATE" < "$json_file" >/dev/null 2>"$WORKDIR/stderr.$$"
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

# (f) malformed JSON -> exit 2
CASE_F_JSON="$WORKDIR/case_f.json"
printf '{not valid json' > "$CASE_F_JSON"
run_case "case (f) malformed JSON -> exit 2" "$CASE_F_JSON" 2

# (g) kill switch set -> exit 0 unconditionally, even with bad content
CASE_G_CONTENT="$WORKDIR/case_g.content"
CASE_G_JSON="$WORKDIR/case_g.json"
printf '## copy string six\nJust prose with no A/B spec at all.\n' > "$CASE_G_CONTENT"
make_write_json "$CASE_G_CONTENT" "$CASE_G_JSON" "$TARGET_FILE"
run_case "case (g) kill switch set -> exit 0 unconditionally" "$CASE_G_JSON" 0 env CONTENT_DESIGN_AB_SPEC_GATE_OFF=1

if [ "${DEBUG_KEEP_WORKDIR:-}" != "1" ]; then
  rm -rf "$WORKDIR"
else
  echo "WORKDIR=$WORKDIR" >&2
fi

if [ "$FAIL" -ne 0 ]; then
  exit 1
fi
exit 0
