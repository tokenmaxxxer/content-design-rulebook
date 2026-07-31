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

exit "$fail"
