#!/usr/bin/env bash
# Test harness for hooks/self-critique-gate.sh
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GATE="$SCRIPT_DIR/../hooks/self-critique-gate.sh"

TMPDIR="${TMPDIR:-/tmp}"
WORKDIR="$(mktemp -d "${TMPDIR%/}/self-critique-gate-test.XXXXXX")"

FAIL=0

pass_count=0
fail_count=0

report() {
  local desc="$1" expected="$2" actual="$3"
  if [ "$expected" -eq "$actual" ]; then
    echo "ok - $desc"
    pass_count=$((pass_count + 1))
  else
    echo "not ok - $desc (expected exit $expected, got $actual)"
    fail_count=$((fail_count + 1))
    FAIL=1
  fi
}

json_write_payload() {
  # $1 = file_path, $2 = content-file path
  local file_path="$1" content_file="$2"
  python3 - "$file_path" "$content_file" <<'PY'
import json, sys
file_path, content_file = sys.argv[1], sys.argv[2]
with open(content_file, "r", encoding="utf-8") as f:
    content = f.read()
print(json.dumps({"tool_name": "Write", "tool_input": {"file_path": file_path, "content": content}}))
PY
}

IN_SCOPE_PATH="docs/issue-7/reports/content-design.md"

# --- case (a): full section, all markers present, self-critique last ---
CONTENT_A="$WORKDIR/content_a.md"
cat > "$CONTENT_A" <<'EOF'
## Copy string: checkout-cta

Decision: rationale -> ties to user hesitation at checkout.
Tone axis: formal vs casual, chose casual for approachability.
A/B variant: measurable signal via click-through rate.

self-critique: rationale ties to the checkout decision correctly, tone axis formal/casual justified, A/B signal is measurable.
EOF
PAYLOAD_A="$(json_write_payload "$IN_SCOPE_PATH" "$CONTENT_A")"
printf '%s' "$PAYLOAD_A" | bash "$GATE" > "$WORKDIR/out_a.log" 2>&1
report "case a: valid section passes" 0 $?

# --- case (b): section missing self-critique entirely ---
CONTENT_B="$WORKDIR/content_b.md"
cat > "$CONTENT_B" <<'EOF'
## Copy string: checkout-cta

Decision: rationale -> ties to user hesitation at checkout.
Tone axis: formal vs casual, chose casual for approachability.
A/B variant: measurable signal via click-through rate.
EOF
PAYLOAD_B="$(json_write_payload "$IN_SCOPE_PATH" "$CONTENT_B")"
printf '%s' "$PAYLOAD_B" | bash "$GATE" > "$WORKDIR/out_b.log" 2>&1
report "case b: missing self-critique denied" 2 $?

# --- case (c): self-critique appears before rationale marker (ordering violation) ---
CONTENT_C="$WORKDIR/content_c.md"
cat > "$CONTENT_C" <<'EOF'
## Copy string: checkout-cta

self-critique: rationale ties to the checkout decision correctly, tone axis formal/casual justified, A/B signal is measurable.

Decision: rationale -> ties to user hesitation at checkout.
Tone axis: formal vs casual, chose casual for approachability.
A/B variant: measurable signal via click-through rate.
EOF
PAYLOAD_C="$(json_write_payload "$IN_SCOPE_PATH" "$CONTENT_C")"
printf '%s' "$PAYLOAD_C" | bash "$GATE" > "$WORKDIR/out_c.log" 2>&1
report "case c: ordering violation denied" 2 $?

# --- case (d): file_path outside scope ---
CONTENT_D="$WORKDIR/content_d.md"
cat > "$CONTENT_D" <<'EOF'
## Copy string: checkout-cta

no self-critique here at all
EOF
PAYLOAD_D="$(json_write_payload "docs/issue-7/other/notes.md" "$CONTENT_D")"
printf '%s' "$PAYLOAD_D" | bash "$GATE" > "$WORKDIR/out_d.log" 2>&1
report "case d: out of scope passes" 0 $?

# --- case (e): malformed JSON ---
printf '{not valid json' | bash "$GATE" > "$WORKDIR/out_e.log" 2>&1
report "case e: malformed JSON denied" 2 $?

# --- case (f): kill switch set, unconditional pass even for invalid content ---
CONTENT_F="$WORKDIR/content_f.md"
cat > "$CONTENT_F" <<'EOF'
## Copy string: checkout-cta

no self-critique here at all
EOF
PAYLOAD_F="$(json_write_payload "$IN_SCOPE_PATH" "$CONTENT_F")"
export CONTENT_DESIGN_SELF_CRITIQUE_GATE_OFF=1
printf '%s' "$PAYLOAD_F" | bash "$GATE" > "$WORKDIR/out_f.log" 2>&1
report "case f: kill switch bypasses gate" 0 $?
unset CONTENT_DESIGN_SELF_CRITIQUE_GATE_OFF

echo "---"
echo "$pass_count passed, $fail_count failed"

rm -rf "$WORKDIR"

exit $FAIL
