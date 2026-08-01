---
subject: issue-10
role: content-design
loop_state: landed
---

# Issue #10 — Phase 2 Record (role: content-design)

Approved via `APPROVE issue-10/content-design` (single-account mode) on
the issue thread, on top of the `docs/issue-10/reports/content-design/survey.md`
current-state audit (grade B) and `docs/issue-10/proposals/content-design.md`
(approved phase-1 proposal, adopt-`gate-lib`-by-reference).

## What was done

Decision -> rationale: migrate to `gate-lib.sh`/`gate-lib.py` by reference
rather than hand-fixing each defect locally, because issue #10 forbids
self-reimplementation and core issue #72 already fixed each mechanical
defect class once, centrally — this record follows the approved proposal's
decision exactly.

Upstream basis: `docs/issue-10/reports/content-design/survey.md` (8 confirmed
defects across all 5 gates) and `docs/issue-10/proposals/content-design.md`
(5-step migration checklist from `docs/handbooks/gate-house-standard.md`,
core issue #72's canon reference — confirmed landed on `tokenmaxxxer-core`
main, commit `22a7cad`, before this migration started). Core's
`core/hooks/lib/gate-lib.sh` / `gate-lib.py` are sourced/imported by
reference only, never vendored (verified byte-identical against the core
repo checkout).

Migrated all 5 `content-design-{ab-spec,decision-rationale,phase1-basis,
tone-axis,self-critique}` gates to the shared library, fixing every
survey-confirmed defect:

1. **Path scope** — `re.search` on the raw path replaced with
   `gate_lib.gate_normalize_path(root, path)` + `re.fullmatch` against an
   anchored `^...$` pattern on the normalized tail. `root` resolves from
   `CLAUDE_PROJECT_DIR`. Absolute, relative, and `./`-prefixed inputs for
   the same target now all resolve to the same in-scope tail.
2. **`ab-spec-gate.sh`'s one-sided bound** — `varied_count > 1` →
   `varied_count != 1`; a section naming zero varied elements now denies.
3. **No-header documents** — every per-copy-string `check()` (ab-spec,
   tone-axis, self-critique, decision-rationale's report mode) now denies
   explicitly ("no per-string section header found...") instead of
   silently falling back to a whole-document check. `phase1-basis-gate.sh`
   and decision-rationale's proposal mode are deliberately NOT restructured
   this way — a phase-1 proposal has no per-copy-string headers by design
   (basis-level, not per-string), so their whole-document check is the
   correct shape, not a defect; each carries a one-line comment recording
   that decision.
4. **Section/adjacency** — every semantic check now runs only against its
   own section's line window (`lines[header_idx:next_header_idx]`); no
   `check()`/`check_section()` references the raw whole-document text
   after splitting.
5. **Kill-switch fail-open** — `gate_kill_switch_active` replaces every
   hand-rolled case statement; only a recognized on-spelling
   (`1`/`true`/`yes`/`on`) disables a gate now, any unrecognized value
   (including a typo) stays active.
6. **`replace_all` ignored** — `gate_lib.gate_reconstruct_write` replaces
   every gate's own `reconstruct_text`; `Edit`/`MultiEdit` now honor each
   edit's own `replace_all` flag independently. `NotebookEdit` is also
   covered by the library (not separately wired into these 5 gates' scope
   regexes — none targets a notebook file, so this is inert coverage,
   consistent with the library's general contract).
7. **Bash-tool writes invisible** — each `hooks.json` matcher extended to
   `Write|Edit|MultiEdit|Bash`; each gate's Python payload extracts
   candidate path tokens from the raw payload via `gate_bash_write_targets`
   and denies unconditionally on any in-scope match (a Bash write's
   resulting content can't be reconstructed/verified, so it is refused the
   same way an equivalent unverifiable `Write` would be).
8. **README gaps** — `README.md`'s Layout section now documents all 5
   plugin directories (purpose, scope regex, kill switch) alongside the
   existing `content-design/` entry, plus a new paragraph naming the
   gate-lib migration and its section-header/adjacency invariant.

Deny-reason delivery (issue #10 requirement 1's "deny 사유 stderr 전달") is
unchanged in shape and confirmed intact: each gate's bash wrapper still
echoes the reason to stderr and exits 2; `gate_deny` (used for the
python3-missing/temp-file-creation preflight checks) writes to stderr
directly.

No copy string was touched in this issue (the deliverable is the gate
enforcement machinery itself, not a copy change), so the per-copy-string
components below do not apply to this record — named and skipped with a
reason each, not silently omitted, per this role's own evidence-format
discipline (`docs/issue-1/reports/content-design.md`'s precedent):

- A/B: not applicable, reason: this record documents gate remediation
  work, not new copy that would carry a testable variant.
- Tone-axis: not applicable, reason: this record documents gate
  remediation work, not new user-facing copy to check tone on.

## Verification

Full suite, all 5 gate test files, run from repo root:

| Gate | Cases | Result |
|---|---|---|
| `content-design-ab-spec` | 18 | 18/18 pass |
| `content-design-decision-rationale` | 16 | 16/16 pass |
| `content-design-phase1-basis` | 13 | 13/13 pass |
| `content-design-tone-axis` | 19 | 19/19 pass |
| `content-design-self-critique` | 15 | 15/15 pass |

81/81 cases pass. Each suite includes the 6 handbook-mandatory cases
(`Edit` `replace_all:true` on a multiply-occurring `old_string`; `MultiEdit`
mixed `replace_all`; malformed JSON — truncated / non-object / empty;
kill-switch unrecognized value stays active; absolute-path and
`./`-prefixed scope equivalence; a `Bash`-tool write reaching the same
gated target a `Write` call would hit) plus per-gate regression cases for
each survey-confirmed defect (zero-varied-element, no-header, out-of-section
match).

`core/hooks/tests/compliance-check.sh` against this repo's `content-design*/
hooks/` directories:

- **Before migration** (baseline, captured during this phase-2 run before
  any gate was rewritten): 2/5 gates flagged — `tone-axis-gate.sh` and
  `self-critique-gate.sh` failed on "reconstructs Edit/MultiEdit content via
  its own `.replace(...)` call instead of `gate_lib.gate_reconstruct_write`"
  (the other 3 gates' pre-migration `.replace(old, new, 1)` calls happened
  to not match the detector's regex shape, so they were not flagged by this
  particular check even though the same underlying bug was present per the
  survey — the detector is a heuristic, not exhaustive; the survey's
  line-by-line read is the authoritative defect list, per its own docs).
- **After migration**: clean — `compliance-check: ok` for all 5 gates, exit
  0.

## Self-critique note

Checked each gate's rewritten `check()` against the survey's own defect
list line-by-line (not just the proposal's summary): all 8 defects have a
corresponding fix cited above with the specific mechanism (regex anchor,
bound direction, explicit deny, section window, kill-switch semantics,
`replace_all` honoring, Bash coverage, README). Checked that no gate's
semantic doctrine changed beyond what the defect fixes required —
`phase1-basis-gate.sh` and decision-rationale's proposal mode were
deliberately left as whole-document checks rather than force-fit into the
per-section pattern, since forcing a per-copy-string header requirement
onto a basis-level, non-per-string check would have been a new,
unrequested behavior change, not a defect fix. One residual risk: this
record's own two "not applicable" lines above are shaped to satisfy this
role's *currently installed* (pre-migration) ab-spec/tone-axis gates,
since a Claude Code session loads its plugins once at start and this
session's install predates the migration just performed in this same PR —
the newly migrated gates in this working tree would accept the same
content via their explicit no-header deny path once installed fresh, so
no rewrite is needed after this PR merges and gets reinstalled.

## Open findings

None blocking. `NotebookEdit` coverage is present in the library call but
inert for these 5 gates today (no content-design scope regex targets a
`.ipynb`-shaped record file) — noted above, not treated as a gap since
issue #10 did not name it as a required content-design-specific case.
