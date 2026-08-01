# Issue #10 survey — current-state audit of content-design's 5 gates

Scope: `content-design-{ab-spec,decision-rationale,phase1-basis,self-critique,tone-axis}/hooks/*.sh`
(the role's PreToolUse content gates) plus `README.md`. `content-design/hooks/directive.sh`
(SessionStart) and core canon gates (record-fields, trailer, handbook-trigger) are out of scope —
issue #10 targets this role's own 5 gates only.

## Structural shape (identical across all 5 scripts)

Each gate is a bash wrapper (`set -u`, `trap ... EXIT`, hand-rolled kill-switch case, `python3 -`
heredoc) duplicating the same shapes core/hooks/*.sh had before core issue #72 — confirmed by
`grep` across all 5: same `KILL_SWITCH_VAR` pattern, same `SCOPE_REGEX` `re.search` call, same
`reconstruct_text` function inlined per-file (4 of 5 gates; `ab-spec-gate.sh` has its own copy
too). No shared library file exists (`README.md`'s own note: "no inter-plugin source" was a
phase-2 design choice, not a constraint from core).

## Confirmed defects (matching issue #10's audit)

1. **Path scope: no normalization, `./`-bypass.** `re.search(SCOPE_REGEX, path)` is an
   unanchored substring search against the raw `file_path` string, never normalized
   (`ab-spec-gate.sh:118`, and identically in the other 4). A `file_path` containing extra
   path segments that resolve (via `..`/`.`) to the same in-scope file but do not literally
   contain the regex's exact adjacent substring — e.g. `docs/issue-10/x/../reports/content-design.md`
   — passes `re.search` as **out of scope** even though it resolves to the in-scope target,
   because the literal substring `issue-10/reports/content-design.md` never appears
   contiguously. This is a false-negative (bypass), not a false-positive: the semantic check
   never runs against a write that lands on the gated file. Absolute-path inputs happen to
   still match today only because `re.search` has no anchor at all — the fix must add
   anchoring/normalization without accidentally *tightening* into a new absolute-path miss.

2. **`ab-spec-gate.sh`'s "exactly one varied element" only rejects `>1`, silently accepts `0`.**
   `check_section` (`ab-spec-gate.sh:93-95`): `varied_count = sum(...); if varied_count > 1: return False`.
   A section with zero "varied element" mentions never trips this branch and falls through to
   the signal check, which can independently pass — so a spec naming zero varied elements is
   accepted as valid A/B spec. The doctrine requires *exactly one*; only one bound is checked.

3. **No-header documents get treated adversarially as one giant section.**
   `split_sections` (`ab-spec-gate.sh:68-78`, and the equivalent `HEADER_RE.finditer` pattern in
   `self-critique-gate.sh`/`tone-axis-gate.sh`): when `header_idxs`/`matches` is empty, the whole
   document becomes a single `("document", lines)` section, and `check_section` runs the full
   per-string A/B-spec requirement against the entire file as if it were one string's section.
   A record file with no matching `#{2,4} ... string` header (e.g. still using a different
   heading style, or genuinely has no string-level content yet) is denied for lacking an A/B
   spec that doctrine never asked it to have at the whole-document level — over-rejection driven
   by a header-detection failure, not a real doctrine violation.

4. **Semantic checks are all substring/mention checks, not section-scoped or adjacency-checked.**
   Beyond ab-spec's own three bugs above: `phase1-basis-gate.sh:54-62`'s `check()` passes if the
   string `scout-brief` (or a skip-phrase regex) appears *anywhere in the whole file*, with no
   requirement that it appear near, or under, the specific proposal/finding it's meant to
   justify. `decision-rationale-gate.sh` and `tone-axis-gate.sh`/`self-critique-gate.sh` follow
   the same shape (confirmed via `grep -n "def check("` across all 5 — each defines its own
   `check()`, each keyed on regex search over a flat string, none walk a header→body structure
   the way `ab-spec-gate.sh`'s `split_sections` partially attempts). This is issue #10 point 2's
   "판단이 '단어 언급'으로 통과" — a rationale/critique/tone-axis keyword mentioned once anywhere
   in a large record file satisfies the gate regardless of which section it sits in or whether it
   is adjacent to the artifact it is meant to justify.

5. **Kill-switch: unrecognized value silently disables (fail-open).** All 5 scripts:
   `case ... in ""|0|false|no|off) ;; *) exit 0 ;; esac` — every value that is not a recognized
   off-spelling, including a typo or an unrecognized on-spelling, takes the `*)` branch and
   bypasses the gate. This is the exact bug `gate-lib.sh`'s `gate_kill_switch_active` (and
   `docs/handbooks/gate-house-standard.md`'s "two bugs this issue fixed", bug 1) already fixed in
   core's own canon gates. Issue #10 does not list this explicitly among its 4 named defects, but
   it is the same defect class as core issue #72 section 2, present identically across all 5
   gates here, and directly in scope of "위 결함 전부 수정" + "fail-closed(... 킬스위치 비인식
   값=활성)" in issue #10's requirement 1.

6. **`Edit`/`MultiEdit` reconstruction: always `.replace(old, new, 1)`, `replace_all` never
   read.** All 5 `reconstruct_text` implementations hard-code `1` as the `count` argument to
   `str.replace`, and none read `tool_input.get("replace_all")`. This is exactly core issue #72's
   bug 2 (`record-fields-gate.sh` before migration), reproduced independently in each of the 5
   content-design gates. `NotebookEdit` is not handled by any of the 5 (falls through to the
   generic "unknown tool" deny path — fail-closed on that axis, but still not a real
   reconstruction).

7. **Bash-tool file writes are invisible to all 5 gates.** Every gate's `main()` only inspects
   `tool_input.file_path`; none call anything like `gate_bash_write_targets`. A `Bash` tool call
   that writes to `docs/issue-N/reports/content-design.md` (e.g. `printf ... > docs/issue-N/...`)
   never reaches any of the 5 gates' scope check at all — the PreToolUse hook registration
   (`hooks.json`, confirmed identical pattern per plugin) matches only `Write|Edit|MultiEdit`
   tool names.

8. **README omits all 5 gate plugins.** `README.md`'s "Layout" section (lines ~20-33) documents
   only `content-design/` (directive.sh) and states "The role-agnostic gates ... no longer have
   local copies here" — true for record-fields/trailer/handbook-trigger, but the doc never
   mentions `content-design-ab-spec/`, `content-design-decision-rationale/`,
   `content-design-phase1-basis/`, `content-design-self-critique/`, or `content-design-tone-axis/`
   at all, despite all 5 being real, merged, installed plugin directories with their own
   `.claude-plugin/plugin.json`. Matches issue #10's "README에 게이트 플러그인 5종 누락" exactly.

## What already exists to build on (core issue #72, landed on `tokenmaxxxer-core` main)

- `core/hooks/lib/gate-lib.sh` — `gate_trap_fail_closed`, `gate_kill_switch_active` (fixed
  semantics: only a recognized on-spelling disables), `gate_deny`/`gate_allow` (stderr-only deny
  protocol), `gate_bash_write_targets`.
- `core/hooks/lib/gate-lib.py` — `gate_parse_json_or_deny`, `gate_normalize_path(root, path)`
  (absolute/relative/`./`-prefixed → root-relative tail, or `None` if outside root — pure
  string-algebra, no filesystem touch), `gate_reconstruct_write(tool, tool_input,
  current_content)` (full `Write`/`Edit`/`MultiEdit`/`NotebookEdit`, honors `replace_all`
  per-edit).
- `docs/handbooks/gate-house-standard.md` — the adoption doctrine: reference-only (never copy,
  per `canon-scripts.md`), 6-case mandatory test harness shape, `compliance-check.sh` detector,
  and a 5-step per-repo migration checklist this proposal follows directly.
- No other rulebook repo (checked via `gh search code` for `gate_normalize_path` org-wide, and
  `gh api search/code`) has migrated to `gate-lib.sh` yet — content-design would be the first
  adopter. No exemplar migration diff exists to model against; this proposal is built directly
  from the library's own usage comments and the handbook's checklist.

## Existing test coverage

Each of the 5 gates has a same-named `tests/*.test.sh`. Not yet read line-by-line in this survey
pass (deferred to phase-2, where the mandatory new cases get added and the full suite must run
green) — the proposal's test-case section is scoped from issue #10 requirement 3 and the
handbook's 6-case list directly, not from reading current coverage gaps case-by-case.
