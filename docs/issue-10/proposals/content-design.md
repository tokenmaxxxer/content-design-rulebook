# Issue #10 proposal — content-design gate remediation to A+

Basis: `docs/issue-10/reports/content-design/survey.md` (current-state audit of all 5 gates),
`docs/issue-10/reports/content-design/scout-brief.md` (scouting skip record — this is a
fixed-API standard adoption, not a product-shaped design space). Phase-1 proposal only; no
execution in this PR.

**Decision -> rationale**: adopt `gate-lib.sh`/`gate-lib.py` by reference in every gate below,
because issue #10 forbids self-reimplementation and core issue #72 already fixed each mechanical
defect class once, centrally.

## Governing constraint

Issue #10's precondition: core issue #72's `core/hooks/lib/gate-lib.sh` /
`core/hooks/lib/gate-lib.py` have landed on `tokenmaxxxer-core` main
(`docs/handbooks/gate-house-standard.md`, confirmed present). Issue #10 explicitly forbids
self-reimplementation ("자체 재구현 금지") — every mechanical defect (path normalization,
kill-switch, Edit/MultiEdit/NotebookEdit reconstruction, deny protocol) gets fixed by **sourcing**
that library, never by hand-writing an equivalent fix locally. This proposal follows the
handbook's 5-step per-repo migration checklist verbatim.

## 1. Migrate all 5 gates to source `gate-lib.sh` / load `gate-lib.py`

Applies identically to `content-design-{ab-spec,decision-rationale,phase1-basis,self-critique,
tone-axis}/hooks/*.sh` (survey confirmed all 5 share the same pre-migration shape).

- Bash preamble: replace the hand-rolled `trap '__fc_deny ...' EXIT` + `case ... esac` kill-switch
  block with:
  ```bash
  . "${CORE_PLUGIN_ROOT:-$CLAUDE_PLUGIN_ROOT/../core}/hooks/lib/gate-lib.sh"
  gate_trap_fail_closed
  set -uo pipefail
  gate_kill_switch_active "${CONTENT_DESIGN_<PLUGIN>_GATE_OFF:-}" || { trap - EXIT; exit 0; }
  ```
  This decision -> because the library's `gate_kill_switch_active` narrows the disabling set to
  only recognized on-spellings, fixing defect 5 (unrecognized kill-switch value currently
  disables the gate), per `gate-house-standard.md`'s bug-1 writeup.
- Python payload: load via `importlib` per the library's own usage comment
  (`GATE_LIB_PY` env var, already exported by `gate-lib.sh`), then:
  - `event = gate_lib.gate_parse_json_or_deny(raw, deny)` replaces each gate's local
    `json.loads` try/except — deny becomes uniform across empty/non-JSON/non-object payloads.
  - `tail = gate_lib.gate_normalize_path(root, ti.get("file_path", ""))` replaces the raw
    `re.search(SCOPE_REGEX, path)` call. Each gate's `SCOPE_REGEX` is rewritten to anchor against
    the normalized tail (`^docs/issue-[0-9]+/reports/content-design\.md$`, etc.) and matched with
    `re.fullmatch` (or `re.match` against the full tail) instead of unanchored `re.search`.
    Decision -> because normalization collapses `./`-segments, `..`-traversal, and
    absolute-vs-relative input to the same tail before the regex ever runs, so a write that
    *resolves* to the gated file can no longer evade the literal-substring match survey.md
    documented (defect 1). `root` is the repo root, resolved once via `CLAUDE_PROJECT_DIR`
    (already available in the hook environment) — no gate currently reads this variable; adding
    it is new, in-scope wiring, not a reimplementation of `gate_normalize_path` itself.
  - `text, ok = gate_lib.gate_reconstruct_write(tool_name, ti, current_content)` replaces each
    gate's own `reconstruct_text`. Fixes defect 6 (`replace_all` ignored,
    hard-coded `.replace(old, new, 1)`) and extends coverage to `NotebookEdit` (currently
    unhandled by all 5 — falls through to a generic deny today, which stays safe but is not real
    coverage).
  - Deny path: `deny(msg)` is the `gate_lib.gate_deny`-shaped callback (stderr, exit 2) — every
    gate's existing `print(f"DENY:{msg}"); sys.exit(2)` shape is preserved for the outer bash
    wrapper's parsing, but the *reason text* now always reaches the model via stderr, closing any
    residual stdout-JSON risk issue #10 requirement 1 names.

## 2. Bash-tool write coverage (defect 7)

Each `hooks.json`'s PreToolUse matcher currently lists `Write|Edit|MultiEdit` only. Proposal:
extend the matcher to include `Bash`, and in each gate's Python payload, when `tool_name ==
"Bash"`, call `gate_lib.gate_bash_write_targets(ti.get("command", ""))` (bash-side helper —
invoked from the bash wrapper before handing off to Python, output piped in as an extra env var)
and apply the same normalized-scope check to each candidate token. Decision -> because a
`Bash`-tool write landing on the gated file must be denied the same as an equivalent `Write`
call, and today it silently is not.

## 3. Semantic check upgrade: substring -> section/adjacency/structure (issue #10 requirement 2)

Survey defects 2-4. Each gate keeps its own `check()` (design choice from README's "no
inter-plugin source" — preserved; the semantic doctrine differs per plugin and gate-lib.sh/py
covers only the mechanical shapes, not per-role content rules), but every `check()` is
restructured to the same three-part shape:

1. **Section boundary is mandatory, not best-effort.** If no per-string header
   (`HEADER_RE`-equivalent) is found in the reconstructed text, deny explicitly —
   `"no per-string section header found -- cannot verify per-string spec"` — instead of
   silently falling back to treating the whole document as one section (defect 3). Decision ->
   because an adversarial mis-fire (denying real content over a header-detection miss) is worse
   than an honest, fixable deny reason naming exactly what is missing.
2. **The checked signal must be found *within* the owning section's line range**, not via a
   flat `re.search` over the whole file or the whole section-joined string. Concretely: locate
   the string-record header, take only the lines up to the next header (already `ab-spec-gate.sh`'s
   `split_sections` shape) as the search window, and require the keyword regex to match a line
   *inside* that window — never a substring hit anywhere else in the document. This is the fix for
   defect 4 (`phase1-basis-gate.sh` et al. currently accept a mention anywhere in the file).
3. **Bound checks state both edges, not one.** `ab-spec-gate.sh`'s "exactly one varied element"
   becomes `if varied_count != 1: deny(f"expected exactly one varied element, found {varied_count}")`
   — replacing the current `if varied_count > 1`. Decision -> because the 0 case currently passes
   silently (defect 2), and any other plugin found during phase-2 line-reading to have the same
   one-sided-bound shape gets the same fix; phase-2's `compliance-check.sh` run (checklist step 1)
   is also where any such shape would surface, since an unreachable deny branch on one side of a
   bound is the same defect class as a kill switch that never disables.

Adjacency, concretely, means: the section window is `lines[header_idx:next_header_idx]`
(unchanged data already computed by `split_sections`), and every regex that today runs against
`section_text` (the whole-section join) keeps doing so — the fix is that *no* check may run
`re.search` against the *whole-document* `text` variable directly; every check must first select
its section window. This is a mechanical grep-able invariant for phase-2's own self-check: no
`check()`/`check_section()` function may reference the raw `text`/`payload` string after section
splitting.

## 4. Mandatory test cases (issue #10 requirement 3 + handbook's 6-case list)

Per gate, phase-2 adds a `run-gate-lib-tests.sh`-equivalent covering, at minimum:

- `Edit` with `replace_all: true` against a multiply-occurring `old_string`.
- `MultiEdit` with mixed `replace_all: true`/`false` edits in one call.
- Malformed JSON: truncated, non-object top level, empty payload.
- Kill-switch set to an unrecognized value (e.g. a typo) — must assert the gate **stays active**.
- Absolute `file_path` matching the same scope a relative-path fixture already matches, plus a
  `./`-prefixed variant of the same target.
- A `Bash`-tool file write reaching the same target a `Write`-tool call would hit.

Content-design-specific, added on top of the shared six:

- `ab-spec-gate.sh`: a section with zero "varied element" mentions must **deny** (defect 2's
  regression fixture — the case the current code silently passes).
- Every semantic gate: a document with no per-string header must deny with the explicit
  no-header reason (defect 3's regression fixture), not silently full-document-check.
- Every semantic gate: a keyword match that exists in the document but *outside* the relevant
  section's line range must still **deny** (defect 4's regression fixture — proves the check is
  section-scoped, not a flat substring search).

Phase-2 ships only when the full suite (existing `tests/*.test.sh` per plugin, plus the added
cases above) is green.

## 5. README (defect 8)

Add all 5 plugin directories to the "Layout" section, each with: purpose (one line, from its
gate script's own header comment), install name, and its `SCOPE_REGEX` target in prose. Keep the
existing "role-agnostic gates ... no local copies" note — it is accurate for record-fields/
trailer/handbook-trigger and should not be touched; the gap is purely the omission of the 5
content-design-owned plugins.

## 6. Compliance evidence (handbook checklist steps 1, 4, 5)

Phase-2 runs `core/hooks/tests/compliance-check.sh` against this repo's `content-design*/hooks/`
before migration (recorded as the violation baseline) and again after (must be clean), citing
both outputs in the phase-2 record (`docs/issue-10/reports/content-design.md`) as the completion
evidence issue #10 requires ("배송 상태에서 전 스위트 green").

## Explicitly out of scope for this proposal

- Any change to `content-design/hooks/directive.sh` or core canon's own gates — issue #10 targets
  this role's 5 content gates only.
- Redesigning the "no inter-plugin source" rule itself (README's existing design choice) — each
  plugin keeps its own `check()`; only the shared *mechanical* layer (path/kill-switch/
  reconstruct/deny) is migrated to `gate-lib.sh`/`gate-lib.py`, per issue #10's own
  "자체 재구현 금지" instruction being about not re-deriving what core already fixed, not about
  merging the 5 plugins' distinct doctrines into one shared file.
- Actual code changes — this PR stops at the proposal. Phase-2 begins only after an
  `approvers.md` account's Approve.
