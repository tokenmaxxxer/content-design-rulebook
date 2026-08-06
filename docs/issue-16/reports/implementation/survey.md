# Survey — issue #16: remove temp-file dependency from content-design gates

## Write set (confirmed by reading each file)

All five gates share an identical structure end to end (same lines 24-25,
same trailing invocation block):

- `content-design-ab-spec/hooks/ab-spec-gate.sh`
- `content-design-phase1-basis/hooks/phase1-basis-gate.sh`
- `content-design-decision-rationale/hooks/decision-rationale-gate.sh`
- `content-design-tone-axis/hooks/tone-axis-gate.sh`
- `content-design-self-critique/hooks/self-critique-gate.sh`

Each has this exact shape:

```bash
INPUT_JSON="$(cat)"

# python3 is invoked against a temp script + temp input file (not
# "python3 - <<PYEOF" piped from stdin) because a heredoc attached to the
# same command clobbers the process's stdin, leaving nothing for a
# sys.stdin.read() call inside the script to see (verified in the
# pre-migration scripts this replaces).
PY_SCRIPT="$(mktemp "${TMPDIR:-/tmp}/<gate>.XXXXXX.py")" || gate_deny ...
INPUT_JSON_FILE="$(mktemp "${TMPDIR:-/tmp}/<gate>-input.XXXXXX.json")" || gate_deny ...
printf '%s' "$INPUT_JSON" > "$INPUT_JSON_FILE"

... GATE_BASH_TARGETS export ...

cat > "$PY_SCRIPT" <<'PYEOF'
... python body, reads sys.argv[1] as the input JSON file path ...
main()
PYEOF

RESULT="$(python3 "$PY_SCRIPT" "$INPUT_JSON_FILE")"
PY_EXIT=$?
rm -f "$PY_SCRIPT" "$INPUT_JSON_FILE"
```

The python body's `main()` in every gate opens `sys.argv[1]` for the raw
JSON — none of them read stdin today.

Corresponding test files (one suite per gate, same directory layout,
`run_case` harness that accepts an `env_prefix` array — already supports
prepending `env PATH=... VAR=...` ahead of the gate invocation):

- `content-design-ab-spec/tests/ab-spec-gate.test.sh`
- `content-design-phase1-basis/tests/phase1-basis-gate.test.sh`
- `content-design-decision-rationale/tests/decision-rationale-gate.test.sh`
- `content-design-tone-axis/tests/tone-axis-gate.test.sh`
- `content-design-self-critique/tests/self-critique-gate.test.sh`

No other file in the repo references `mktemp` inside a gate hook path (core
`gate-lib.sh` does not create scratch files at all). No sibling gate in
*this* repo already avoids mktemp — the reference implementation is external
(product-discovery-rulebook#54's sibling gates: `product-one-pager`,
`product-guardrail-metrics`, `product-opportunity-solution-tree`), whose
PR body is the only available description of the house pattern:

> payload/root via env vars into a `python3 <<'PYEOF' … PYEOF` heredoc piped
> to stdin

## The one real design point

The comment already present in all five local scripts says the *opposite*
of #54's pattern is necessary — that a heredoc attached to `python3`
clobbers stdin so `sys.stdin.read()` sees nothing, hence the intermediate
files. This is not actually a contradiction once resolved: in the house
pattern, the heredoc IS what supplies the python *program* to stdin
(`python3 <<'PYEOF' ... PYEOF` is equivalent to `python3 -`, reading the
script from stdin). The **input JSON** then has nowhere left on stdin to
travel — so it must go through an environment variable instead, and the
python body reads `os.environ[...]` rather than `sys.argv[1]` or
`sys.stdin.read()`. That fully resolves the local comment's stated
constraint: stdin only ever carries the program text, never the payload,
so there is no clobber.

## Scout-directive skip condition

This is the **no-design-decision-open** skip condition: the issue names the
exact source pattern to adopt (env vars + heredoc-to-stdin, no scratch
files), enumerates the five files and lines, and states the acceptance
criteria including the exact regression-test shape (mktemp-shadow on PATH,
scoped to the gate subprocess, fails pre-fix / passes post-fix). The only
open question was mechanical (how to route the JSON payload once stdin is
claimed by the heredoc), and it is resolved above by reading the current
files plus the #54 PR body — no product-facing or architectural choice
remains. No web scout was run; this is bugfix-shaped code migration, not a
product-shaped surface.
