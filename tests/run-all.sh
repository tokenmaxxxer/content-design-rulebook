#!/usr/bin/env bash
# Thin sourcing wrapper: runs every content-design plugin's own gate-test
# harness. Each plugin owns its tests/ directory (per-plugin independence);
# this file only aggregates the exit codes, it contains no test logic.
set -u
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"

TESTS=(
  content-design-phase1-basis/tests/phase1-basis-gate.test.sh
  content-design-decision-rationale/tests/decision-rationale-gate.test.sh
  content-design-tone-axis/tests/tone-axis-gate.test.sh
  content-design-ab-spec/tests/ab-spec-gate.test.sh
  content-design-self-critique/tests/self-critique-gate.test.sh
)

fail=0
for t in "${TESTS[@]}"; do
  echo "== $t =="
  if bash "$t"; then
    echo "PASS: $t"
  else
    echo "FAIL: $t"
    fail=1
  fi
done

# compliance-check.sh (core canon, issue-72/issue-75): structural check that
# every *-gate.sh here is on the guarded gate-lib.sh source form. Referenced
# from core, never vendored (docs/handbooks/canon-scripts.md).
CORE_COMPLIANCE_CHECK="${CLAUDE_PLUGIN_ROOT_CORE:-$HOME/tokenmaxxxer/tokenmaxxxer-core/core}/hooks/tests/compliance-check.sh"
if [ -x "$CORE_COMPLIANCE_CHECK" ] || [ -f "$CORE_COMPLIANCE_CHECK" ]; then
  for plugin in content-design content-design-ab-spec content-design-decision-rationale content-design-phase1-basis content-design-self-critique content-design-tone-axis; do
    echo "== compliance-check.sh: $plugin/hooks =="
    if bash "$CORE_COMPLIANCE_CHECK" "$plugin/hooks"; then
      echo "PASS: compliance-check.sh $plugin/hooks"
    else
      echo "FAIL: compliance-check.sh $plugin/hooks"
      fail=1
    fi
  done
else
  echo "FAIL: compliance-check.sh not found at $CORE_COMPLIANCE_CHECK" >&2
  fail=1
fi

exit "$fail"
