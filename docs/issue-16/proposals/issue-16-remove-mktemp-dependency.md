files:
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

## Request

Issue #16: all five content-design gate hooks (`ab-spec`, `phase1-basis`,
`decision-rationale`, `tone-axis`, `self-critique`) each create two
`mktemp "${TMPDIR:-/tmp}/..."` scratch files (a python script + an input
JSON file) before running the gate's python payload. Under a Claude Code
sandboxed role session, `mktemp`'s fallback path (`/tmp` when `$TMPDIR` is
unset) can resolve outside the sandbox's writable set, failing the gate
closed regardless of content — the same failure class product-discovery-
rulebook#54 fixed for its `product-hypothesis-testing` gate. Adopt that
fix's house pattern here: payload/root via env vars into a
`python3 <<'PYEOF' … PYEOF` heredoc piped to stdin, no scratch files. Add a
mktemp-shadowing regression test per gate, in #54's style.

## Constraints

- No `mktemp` (or any tmp-dir write) may remain in gate hook runtime paths.
- Existing gate behavior (allow/deny decisions, all current test cases)
  must be unchanged — this is a plumbing migration, not a policy change.
- Each gate's `gate_trap_fail_closed` / kill-switch / `GATE_BASH_TARGETS`
  scaffolding stays as-is; only the python-invocation mechanism changes.
- Regression test must actually prove the fix: fails pre-fix, passes
  post-fix, per gate (per #54's own verified-both-directions bar).

## Rationale

Chosen approach: env-var payload + `python3 <<'PYEOF' ... PYEOF` (heredoc
supplies the python program on stdin) + python reads the JSON payload from
`os.environ[...]` instead of `sys.argv[1]`/`sys.stdin.read()`.

Alternative considered and rejected: keep passing the JSON via `sys.argv`
but read the python *program* from a `-c` string instead of a heredoc file.
Rejected because the python bodies here run 60-150+ lines with embedded
single-quotes and regex literals — an inline `-c` string would require
fragile shell-quoting/escaping of the entire program, whereas the
`<<'PYEOF'` heredoc (quoted delimiter, no interpolation) already lets the
existing python bodies move over byte-for-byte. This also matches the
literal fix direction the issue specifies, so it is not just locally
preferable but the actual target pattern.

A second alternative — leave `sys.argv[1]`/file-based input alone and only
mktemp-free the *python script* — was rejected because it still touches
`/tmp`/`$TMPDIR` for the input JSON, leaving the acceptance criterion ("no
mktemp / no tmp-dir write remains") unmet.

## What will be done

For each of the five gates:

1. Remove both `mktemp` lines and the `printf '%s' "$INPUT_JSON" > ...`
   write.
2. `export GATE_INPUT_JSON="$INPUT_JSON"` (alongside the existing
   `GATE_BASH_TARGETS` export) so the payload reaches python via
   environment, not stdin or a file.
3. Replace `cat > "$PY_SCRIPT" <<'PYEOF' ... PYEOF` with
   `RESULT="$(python3 <<'PYEOF' ... PYEOF\n)"` — the heredoc now feeds the
   python program directly to `python3`'s stdin (`python3 -` semantics),
   capturing its stdout into `RESULT` in one step.
4. In the python body's `main()`, replace
   `open(sys.argv[1], "r", encoding="utf-8")` with
   `os.environ["GATE_INPUT_JSON"]` (already-decoded string, so
   `json.loads`/`gate_parse_json_or_deny` takes the string directly instead
   of a file handle's `.read()`).
5. Drop the `rm -f "$PY_SCRIPT" "$INPUT_JSON_FILE"` cleanup line (nothing
   left to remove) and the stale comment explaining the old stdin-clobber
   constraint, replacing it with a short note on why the payload travels
   via env var (stdin is claimed by the heredoc carrying the program).
6. Keep `PY_EXIT=$?` immediately after the `python3` invocation and the
   rest of the trap/exit-code handling unchanged.

For each of the five test files:

7. Add one regression test case per gate: create a shadow directory on
   `PATH` containing an executable named `mktemp` that always exits
   non-zero and touches a marker file when invoked; run the gate with that
   directory prepended to `PATH` (via the harness's existing `env_prefix`
   support) against a known-valid, known-allow JSON payload; assert exit 0
   and that the marker file is absent. This fails against the current
   (pre-fix) script — which calls the shadowed `mktemp` and gets exit 2 —
   and passes post-fix.

8. Run each gate's test suite locally (`bash tests/<gate>.test.sh` per
   plugin) before considering the migration done, confirming all existing
   cases plus the five new regression cases pass.

## Out of scope

- Any change to gate *policy* (what content passes/fails) — pure plumbing.
- Migrating other plugins' gates (e.g. product-discovery-rulebook's own
  gates are already fixed upstream in #54; nothing else in this repo uses
  the old pattern per the survey).
- Touching `core/hooks/lib/gate-lib.sh` — it already writes no scratch
  files.

## How you'll know it worked

- `grep -rn mktemp content-design-*/hooks/` returns nothing.
- Each of the five test suites passes in full, including the new
  mktemp-shadow regression case, run as
  `CLAUDE_PLUGIN_ROOT_CORE=<core> bash content-design-<x>/tests/<x>-gate.test.sh`.
- Manually confirmed: the new regression test fails when run against a
  `git stash`-restored pre-fix copy of the corresponding gate script (exit
  2, marker file present) and passes against the fixed script (exit 0,
  marker absent) — matching #54's verified-both-directions bar.
