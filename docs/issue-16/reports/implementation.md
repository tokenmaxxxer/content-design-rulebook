---
code_under_review:
  - content-design-ab-spec/hooks/ab-spec-gate.sh
  - content-design-ab-spec/tests/ab-spec-gate.test.sh
  - content-design-phase1-basis/hooks/phase1-basis-gate.sh
  - content-design-phase1-basis/tests/phase1-basis-gate.test.sh
  - content-design-decision-rationale/hooks/decision-rationale-gate.sh
  - content-design-decision-rationale/tests/decision-rationale-gate.test.sh
  - content-design-tone-axis/hooks/tone-axis-gate.sh
  - content-design-tone-axis/tests/tone-axis-gate.test.sh
  - content-design-self-critique/hooks/self-critique-gate.sh
  - content-design-self-critique/tests/self-critique-gate.test.sh
loop_state: landed
---

# Issue #16 — Phase 2 Record (role: implementation)

## What was done

Executing the approved phase-1 proposal
(`docs/issue-16/proposals/issue-16-remove-mktemp-dependency.md`, approved
via `APPROVE issue-16/implementation`) across all five content-design gate
hooks (`ab-spec`, `phase1-basis`, `decision-rationale`, `tone-axis`,
`self-critique`):

- Remove both `mktemp "${TMPDIR:-/tmp}/..."` calls and the
  `printf '%s' "$INPUT_JSON" > "$INPUT_JSON_FILE"` write in each
  `hooks/<gate>-gate.sh`.
- `export GATE_INPUT_JSON="$INPUT_JSON"` alongside the existing
  `GATE_BASH_TARGETS` export.
- Replace `cat > "$PY_SCRIPT" <<'PYEOF' ... PYEOF` +
  `python3 "$PY_SCRIPT" "$INPUT_JSON_FILE"` with
  `RESULT="$(python3 <<'PYEOF' ... PYEOF\n)"` (the heredoc feeds the python
  program to `python3`'s own stdin; no scratch file).
- In each gate's `main()`: `open(sys.argv[1], ...)` becomes
  `os.environ["GATE_INPUT_JSON"]`.
- Drop the `rm -f "$PY_SCRIPT" "$INPUT_JSON_FILE"` cleanup line and the
  stale stdin-clobber comment.
- Add one mktemp-shadow regression test per `tests/<gate>-gate.test.sh`
  (PATH-shadowed `mktemp` that exits non-zero and touches a marker;
  known-allow payload; assert exit 0 and marker absent — fails pre-fix,
  passes post-fix).

Pure plumbing migration; no gate policy/behavior change.

## Why

Under a Claude Code sandboxed role session, `mktemp`'s `${TMPDIR:-/tmp}`
fallback can resolve outside the sandbox's writable set, failing gates
closed (exit 2) regardless of content — the same failure class
product-discovery-rulebook#54 fixed for `product-hypothesis-testing`.
Adopting that fix's house pattern (env-var payload + `python3 <<'PYEOF'`
heredoc-from-stdin) here removes the sandbox-dependent scratch-file writes
from all five gates' runtime paths.

## Upstream basis

- Issue: #16 (this repo)
- Approval: issue-level comment `APPROVE issue-16/implementation` (contract
  v3 s19 single-account mode)
- Phase-1 proposal:
  `docs/issue-16/proposals/issue-16-remove-mktemp-dependency.md`
- Phase-1 survey: `docs/issue-16/reports/implementation/survey.md`
- Reference fix pattern: product-discovery-rulebook#54
  (`product-hypothesis-testing` gate)

## What did not work

None.

## Open findings

None outstanding. Open-finding resolution path: n/a — no finding is open
against this record; if `verify` raises one during phase-2 review, it
will be closed here as a `closed_checks:` entry before the next commit.

## Next steps

None — all five items below are done; `loop_state: landed`.

## Verification (evidence)

- `grep -rn mktemp content-design-*/hooks/` → no matches (confirmed
  post-migration, all five gates).
- Ran all five test suites locally
  (`bash content-design-<gate>/tests/<gate>-gate.test.sh` per gate, core
  path resolved via each test file's own `CLAUDE_PLUGIN_ROOT_CORE`
  default fallback): all pre-existing cases pass plus the new
  mktemp-shadow regression case per gate — zero `not ok` lines across all
  five suites (ab-spec: 20/20, phase1-basis: 15/15, decision-rationale:
  19/19, tone-axis: 21/21, self-critique: 18/18).
