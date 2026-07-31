# Issue #7 — Current-state survey (role: content-design)

Subject: issue-7. Scope: what enforcement machinery exists today for the
methodology adopted in issue-1, and what the two named reference points
(`pricing-rulebook`, `implementation-rulebook`/`coding`) actually
implement, before designing this role's own gate.

## 1. What issue-1 adopted and what phase-2 actually reflected

`docs/issue-1/proposals/content-design.md` adopted a phase-1 proposal
norm (a) and a phase-2 deliverable norm (b): five required components per
copy string — copy draft, decision-tied rationale, NN Group 4-axis tone
check (or a stated skip reason), testable A/B variant spec (if
applicable), self-critique note. Its own plugin-reflection plan (d)
explicitly chose **documentation-only**: expand `directive.sh`'s
`PRODUCES` line to name the five components, and deliberately **not**
add a mechanical gate, reasoning (i) core canon had no per-role
`REQUIRED_FIELDS` gate mechanism at the time, and (ii) phase-1
proposal-shape conformance is already checked by the human Approve read.
`docs/issue-1/reports/content-design.md` (phase-2 record) confirms this
was executed exactly as planned: only the `PRODUCES` string changed; no
gate, no agent, no `hooks.json` change.

Issue #7's problem statement is precisely that gap: the five components
exist only as a one-line summary inside `PRODUCES` and as prose in a
handbook-shaped proposal doc — nothing mechanically checks that a phase-1
proposal or phase-2 record actually contains them.

## 2. Current plugin state (this repo)

- `content-design/hooks/directive.sh` — `SessionStart` only, sources
  `core/hooks/lib/role-directive.sh`, calls `core_role_directive` with
  four fixed slots (YOU_DECIDE/USE_WHEN/PRODUCES/HAND_OFF). No fifth slot
  exists in the core lib (confirmed by issue-1's own finding, itself
  citing `docs/issue-2/proposals/core-canon-reference-switch.md`).
- `content-design/hooks/hooks.json` — one `SessionStart` entry only. No
  `PreToolUse` gate registered for this role anywhere in this repo.
- No `content-design/agents/` directory exists.
- No local copy of any `core/hooks/**` script exists in this tree —
  confirmed clean by `find`; nothing to reclaim per canon-scripts.md.
- No repo-root `tests/` directory exists yet (unlike `pricing-rulebook`
  and `implementation-rulebook`, which both carry one).
- Core canon (`tokenmaxxxer-core`) already ships a generic §20 gate,
  `core/hooks/record-fields-gate.sh` (PreToolUse, Write/Edit/MultiEdit,
  matcher-agnostic — reads `CLAUDE_ROLE` and checks
  `docs/issue-<n>/reports/${CLAUDE_ROLE}.md` for what-was-done / why /
  upstream-basis / loop_state / open-findings). This is **not** wired
  into `content-design/hooks/hooks.json` today — confirmed absent from
  `hooks.json` above. It is core-canon, invoked by path against the core
  plugin's install root, never vendored locally (per
  `docs/handbooks/canon-scripts.md`).

## 3. Reference implementation: `pricing-rulebook` (issue-1 there)

`pricing/hooks/methodology-gate.sh` (PreToolUse, `Write|Edit|MultiEdit`)
is the model issue #7 names directly. Its shape:

- Fail-closed trap-at-top (`__fc`/`trap ... EXIT`) forcing any abnormal
  exit to 2 (DENY), since PreToolUse treats non-2 as fail-open.
- Kill switch via env var (`PRICING_METHODOLOGY_GATE_OFF`), same
  off-value convention (`""|0|false|no|off` = not off) as every other
  canon gate.
- Scope: only fires on writes resolving under
  `docs/issue-<n>/proposals/*pricing*.md` or
  `docs/issue-<n>/reports/pricing.md` — everything else passes through
  untouched (`sys.exit(0)`).
- Reconstructs the **resulting** text for Write/Edit/MultiEdit (not just
  the diff fragment) so keyword checks run against the full document;
  denies with a specific reason if the resulting text can't be
  determined from the tool input.
- Checks a fixed list of required elements via keyword/phrase matching
  (`has_any(...)`) against the adopted proposal's own required-section
  list — method named (or an explicit early-exit), family named when
  conjoint language appears, inputs-needed stated, a gate-check result
  present, numbers carrying a label, a residual list. Missing elements
  are named explicitly in the denial message, one deny call for the
  whole batch of missing items (not one gate per element).
- No cross-file order/state tracking in this gate — the *checklist* is
  purely content-shape (are the required elements present in this one
  document), not sequencing.
- `docs/handbooks/pricing/methodology.md` restates the checklist as
  human-readable worked guidance, explicitly kept in sync with the
  gate's parser ("gate = mechanical minimum, handbook = worked
  guidance").
- Order constraint example ("조사→근거→채택") is NOT implemented as a
  state-tracking gate in this rulebook; pricing's own procedure is
  linear inside one document (scope-gate → routing → six-element
  report), so content-shape checking on the finished document is
  suffinal. No precedent here for stateful gates.

## 4. Reference implementation: `implementation-rulebook` (`coding` plugin)

This is the "hook-machine at implementation-rulebook level" issue #7
cites as the bar. Two relevant mechanisms:

- **`coding/hooks/coding-progress-gate.sh`** (PreToolUse, `Bash` matcher
  on `git commit`): a genuine **order/state-tracking** gate. It reads a
  *different* role's record (`docs/issue-<n>/reports/verify.md`), parses
  inline `finding` blocks for `severity: blocking` +
  `addressed_to: coding`, and refuses the commit unless coding's own
  record carries a `resolved_findings` entry (naming the finder's path +
  a commit sha) **and** the verifier's record `loop_state` is currently
  `cleared`. This is the shape of a genuine ordering enforcement:
  state lives in the *other* role's own record file (`loop_state:`
  frontmatter/field), and the gate cross-reads it rather than
  maintaining separate state on disk.
- **`core/hooks/warrant/hooks/state.sh`** (`SessionStart`, not
  `PreToolUse`): rebuilds work-unit state by scanning
  `docs/proposals/*.md` frontmatter `status:` fields and git log, and
  *prints* an advisory ("AWAITING APPROVAL" / "APPROVED, in progress")
  — it does not block anything; it is a read-only status surface, not a
  gate.
- Neither mechanism keeps a separate state file on disk; both derive
  state by reading existing record frontmatter/fields + git, matching
  this repo's existing pattern (`loop_state:` frontmatter already used
  in `docs/issue-1/reports/content-design.md`).

## 5. Content-design's own order constraint, if any

Content-design's adopted methodology (issue-1 (a)/(b)) is **not**
multi-stage across separate documents the way coding/verify is — it is a
single-document, single-role checklist (five components inside one
phase-2 record, one string at a time). The closest analogue to an
"order constraint" is intra-document: the self-critique note is defined
(issue-1 proposal (b)5) as checking the draft *against items 2-4*
(rationale, tone, A/B) — i.e., self-critique is only meaningful once the
other three exist. There is no cross-role, cross-document sequencing
requirement analogous to coding/verify's blocking-finding handoff.
Phase-1's own procedural order (current-state survey → scout →
proposal) is already enforced by the standing `scout-directive`
(session-level, not plugin-level) — issue #7's own text calls this "이미
강제됨" implicitly by not asking to duplicate it in a gate.

## Gaps this issue's proposal must close

1. No `PreToolUse` gate exists on `content-design`'s own write surfaces
   (`docs/issue-<n>/proposals/*content-design*.md`,
   `docs/issue-<n>/reports/content-design.md`) checking the five adopted
   components — content-shape check, modeled directly on
   `pricing/hooks/methodology-gate.sh`.
2. No mechanical check that self-critique textually follows (references)
   the rationale/tone/A-B content it is required to check against — the
   one genuine intra-document ordering constraint this role's adopted
   methodology carries.
3. `directive.sh`'s `PRODUCES` line is already at its ceiling (one
   summary line, core lib has no fifth slot) — the "directive 심화" issue
   #7 asks for has to live in a handbook (worked guidance, per-facet
   steps/criteria/prohibitions), not in `directive.sh` itself. No
   `docs/handbooks/content-design/` directory exists yet.
4. No repo-root `tests/` directory; no gate-test harness exists for this
   role to extend.
5. No `content-design/agents/` directory; issue-1's adopted methodology
   has no repeated multi-step procedure that plausibly needs an agent —
   evaluated below in the proposal.

## Kill-switch / fail-closed conventions to preserve (constraint, not gap)

Every canon gate examined (`record-fields-gate.sh`,
`pricing/hooks/methodology-gate.sh`, `coding-progress-gate.sh`) shares:
trap-at-top fail-closed (`__fc`/`trap EXIT`), an env-var kill switch read
with the `""|0|false|no|off` = not-off convention, `python3` required
with an explicit deny (never a silent skip) if absent, project-root
resolution via `CLAUDE_PROJECT_DIR` with a git-toplevel fallback, and
`sys.exit(0)` (pass-through) the instant the write target is outside the
gate's own scope. Any new gate for `content-design` must match this
shape exactly — divergence here is exactly the kind of copy-paste drift
`docs/handbooks/canon-scripts.md` and the record-fields-gate promotion
history (issue-66) were written to stop.
