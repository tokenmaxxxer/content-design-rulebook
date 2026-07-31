---
subject: issue-7
role: content-design
loop_state: scope-revision
---

# Proposal: a plugin set enforcing the issue-1 methodology (phase 1, rev. 2)

Phase-1 only: research + design. No plugin files change in this PR.
Phase 2 opens only on an Approve per contract v3 s19. Basis:
`docs/issue-7/reports/content-design/survey.md` (current-state survey)
and `docs/issue-7/reports/content-design/scout-brief.md` (internal
exemplar scout: `pricing-rulebook`'s `methodology-gate.sh`,
`implementation-rulebook`'s `coding-progress-gate.sh`/`state.sh`).

**Revision note**: this replaces the rev-1 design (a single
`content-design/hooks/methodology-gate.sh` inside the one existing
`content-design` plugin) per the approver's FEEDBACK on PR #8, itself
citing issue #7's '요구 정정' comment. The FEEDBACK's required shape:
the marketplace registers a **plugin set** — one independent,
freelunch-grade-complete plugin per adopted methodology, never a single
monolithic gate — and both the phase-1 proposal norm and the phase-2
record norm are specified as **combinations** of those plugins, with the
combination itself being the design's main content. §0 below is new;
§§1-4 are re-cut along plugin boundaries; the technical content (regex
scope, fail-closed shape, required elements, ordering check) carries over
unchanged from rev.1, now distributed one component per plugin instead of
concatenated in one script.

## Request (paraphrased intent)

Issue-1 adopted a five-component content-design methodology (copy draft,
decision-tied rationale, NN Group 4-axis tone check, testable A/B
variant spec, self-critique note) but reflected it as documentation only
— a one-line `PRODUCES` summary and a proposal-shaped handbook, with no
mechanical check. Issue #7 asks this maturation gap be closed to
`implementation-rulebook`'s hook-machine standard, and the approver's
FEEDBACK further specifies *how*: not one gate/directive deepened in
place, but a **plugin set** — each adopted methodology its own
independent plugin (freelunch/scout-style: self-contained, marketplace-
registered, one method each), with the phase-1 and phase-2 norms each
expressed as a named combination of those plugins. Canon scripts
referenced only, never copied (`docs/handbooks/canon-scripts.md`).

## (0) Plugin set (required by the FEEDBACK — the design's main content)

Five independent plugins, each owning exactly one issue-1 methodology
component, each freelunch/scout-grade self-contained (own
`.claude-plugin/plugin.json`, own `hooks/`, own gate script, own test
file, own `marketplace.json` entry). None invokes another's script; each
is independently disable-able via its own kill switch.

| Plugin | Methodology owned | Components | Fires on |
|---|---|---|---|
| `content-design-phase1-basis` | Phase-1 proposal must rest on a stated survey+scout basis (or documented skip), per the standing scout-directive | `hooks/phase1-basis-gate.sh` (PreToolUse) + `hooks/hooks.json` + `tests/phase1-basis-gate.test.sh` | `docs/issue-[0-9]+/proposals/.*content-design.*\.md` |
| `content-design-decision-rationale` | Decision-tied rationale: every rationale statement (phase-1: for the proposal as a whole; phase-2: per copy string) must name the user decision it serves before the wording rationale | `hooks/decision-rationale-gate.sh` (PreToolUse) + `hooks/hooks.json` + `tests/decision-rationale-gate.test.sh` | proposal path (phase-1 mode) **and** `docs/issue-[0-9]+/reports/content-design\.md` (phase-2 mode) — same script, mode selected by which regex matched |
| `content-design-tone-axis` | NN Group 4-axis tone check per copy string (Funny↔Serious / Formal↔Casual / Respectful↔Irreverent / Enthusiastic↔Matter-of-fact), present-or-skipped-with-reason | `hooks/tone-axis-gate.sh` (PreToolUse) + `hooks/hooks.json` + `tests/tone-axis-gate.test.sh` | `docs/issue-[0-9]+/reports/content-design\.md` |
| `content-design-ab-spec` | Testable A/B variant spec per copy string: exactly one varied element + the user-behavior signal it targets, or an explicit not-applicable + reason | `hooks/ab-spec-gate.sh` (PreToolUse) + `hooks/hooks.json` + `tests/ab-spec-gate.test.sh` | `docs/issue-[0-9]+/reports/content-design\.md` |
| `content-design-self-critique` | Self-critique note per copy string, genuinely checking the rationale/tone/A-B content already produced, and — the one real ordering constraint issue-1 defined — appearing *after* those sections in document order | `hooks/self-critique-gate.sh` (PreToolUse) + `hooks/hooks.json` + `tests/self-critique-gate.test.sh` | `docs/issue-[0-9]+/reports/content-design\.md` |

**Composition — this is what makes a plugin set, not five unrelated
gates:**

- **Phase-1 proposal norm** = `content-design-phase1-basis` +
  `content-design-decision-rationale` (proposal mode). A phase-1 write
  passes only when *both* fire clean; each still fires and denies
  independently — the norm is the AND of the two plugins' verdicts, not
  a merged script.
- **Phase-2 record norm** = `content-design-decision-rationale`
  (record mode) + `content-design-tone-axis` + `content-design-ab-spec`
  + `content-design-self-critique`. All four fire on the same file path
  (`docs/issue-<n>/reports/content-design.md`); each checks only its own
  component and stays silent about the others. The ordering constraint
  (self-critique last) is enforced by `content-design-self-critique`
  alone reading the *other three plugins' section markers* in the
  already-written document text — it does not call their scripts, it
  greps for the same section headers they themselves require, keeping
  the plugins independent while still letting one plugin check a
  cross-plugin ordering fact.
- No plugin depends on another's exit code or invokes another's file;
  composition is "same write surface, several independent PreToolUse
  entries in `hooks.json`, each plugin's own," exactly how core's
  `freelunch` and `scout` plugins compose today (per issue #7's own
  wording) — never a shared runtime dependency.
- `marketplace.json` gains five new entries (one per plugin above),
  alongside the existing single `content-design` plugin entry (directive/
  `SessionStart` only, unchanged) — six plugins total in this rulebook
  after phase 2, not one.

## (1) Per-plugin directive depth — per-facet steps, judgment criteria, prohibitions

`directive.sh`'s `PRODUCES` line stays a one-line summary — core canon's
`role-directive.sh` has no fifth slot (confirmed in issue-1's own
finding, unchanged since). Depth belongs in a new handbook,
`docs/handbooks/content-design/methodology.md`, mirroring
`docs/handbooks/pricing/methodology.md`'s pattern ("gate = mechanical
minimum, handbook = worked guidance"). Content (drawn from the already-
adopted issue-1 norm, not new field research — this issue enforces, it
does not re-adopt):

**Phase-1 proposal facet:**
1. *Steps*: current-state survey → scout (or stated skip) → proposal,
   per the standing scout-directive (procedural, not duplicated here).
2. *Judgment criteria*: every proposed copy/pattern change states which
   named user decision it serves before stating why the wording changes
   (issue-1 (a)2) — a rationale that doesn't name the decision fails
   this facet regardless of how well-written the prose is.
3. *Prohibitions*: no "sounds better"/"clearer"/"more friendly" as a
   complete rationale; no unsourced "industry standard" claims; no
   resurrecting practices the field has already refuted for this role
   (issue-1 scout-brief's refuted-claims list, if any resurface).

**Phase-2 record facet, per copy string touched:**
1. *Steps*: draft → rationale → tone-axis check (or skip-reason) → A/B
   spec (or "not applicable" + why) → self-critique, in that order,
   because self-critique's own definition (issue-1 (b)5) is "check the
   draft against items 2-4" — it is not meaningful before they exist.
2. *Judgment criteria*: tone-axis check names which of the 4 NN Group
   axes (Funny↔Serious, Formal↔Casual, Respectful↔Irreverent,
   Enthusiastic↔Matter-of-fact) is live for this string and where it
   targets; a skip is valid only with a one-line reason (e.g. fixed
   legal string). A/B spec, when given, isolates exactly one changed
   element and names the user-behavior signal that would prefer the
   variant. Self-critique is a genuine check, not a restatement — it
   must be able to say "this fails axis-check X" and not merely "looks
   good."
3. *Prohibitions*: no string ships with a tone-axis section that is
   silently absent (must be present-or-skipped-with-reason, never just
   missing); no self-critique note that doesn't reference the rationale/
   tone/A-B content it's checking; no A/B spec with more than one varied
   element.

## (2) Each plugin's gate — mechanical, single-component check

All five gates share one proven shape, each in its own plugin's
`hooks/<name>-gate.sh`, none invoking another's file — modeled on
`pricing/hooks/methodology-gate.sh` (survey.md §3), never copied
(canon-scripts.md's clause applies to files under `core/hooks/`;
`pricing/hooks/methodology-gate.sh` is a per-role file in another
rulebook, referenced here only as a design model).

**Shared shape, present in every one of the five gates:**
- Fail-closed trap-at-top (`__fc`/`trap ... EXIT` → exit 2 on any
  abnormal termination); own kill switch per plugin
  (`CONTENT_DESIGN_PHASE1_BASIS_GATE_OFF`,
  `CONTENT_DESIGN_DECISION_RATIONALE_GATE_OFF`,
  `CONTENT_DESIGN_TONE_AXIS_GATE_OFF`,
  `CONTENT_DESIGN_AB_SPEC_GATE_OFF`,
  `CONTENT_DESIGN_SELF_CRITIQUE_GATE_OFF`), standard
  `""|0|false|no|off` = not-off convention; `python3` required with an
  explicit deny (not a silent skip); full resulting-text reconstruction
  for Write/Edit/MultiEdit, denying with a specific "cannot determine
  resulting content" message when unresolvable — identical to the
  pricing gate's proven shape (survey.md's kill-switch/fail-closed
  section), replicated independently per plugin rather than shared via
  a common library file (each plugin stays self-contained; no
  inter-plugin `source`).

**Per-plugin scope and check:**
- `content-design-phase1-basis`: fires on
  `docs/issue-[0-9]+/proposals/.*content-design.*\.md`; denies unless a
  stated survey+scout basis reference is present (or a documented skip
  per the standing scout-directive).
- `content-design-decision-rationale`: fires on the same proposal regex
  (phase-1 mode: one basis-level rationale statement required) **and**
  on `docs/issue-[0-9]+/reports/content-design\.md` (phase-2 mode: a
  `[decision] → [why]` construction required per copy string — checked
  structurally, an arrow-shaped or "because"/"so that" construction
  tied to a named decision keyword, not full NLP judgment). One script,
  branching on which regex matched, still one plugin, one component.
- `content-design-tone-axis`: fires on the phase-2 record path only;
  denies unless each copy string's section names one of the four NN
  Group axis pairs, **or** carries an explicit skip phrase + reason.
- `content-design-ab-spec`: fires on the phase-2 record path only;
  denies unless each copy string's section states exactly one varied
  element and the user-behavior signal it targets, **or** an explicit
  "not applicable" + reason.
- `content-design-self-critique`: fires on the phase-2 record path only;
  denies unless a self-critique section is present per string, **and**
  — the one real ordering constraint issue-1 defined (survey.md §5,
  self-critique's own definition is "check the draft against items
  2-4", not meaningful before they exist) — that section's start
  position is *after* the rationale, tone-axis, and A/B sections'
  start positions for the same string (line-offset check against the
  same section headers the other three plugins require; this plugin
  reads the document text directly, it does not call the other
  plugins' scripts).
- Each gate names its own missing/misordered element in its own deny
  message (no gate speaks for another's component).
- **Not duplicated**: core's `record-fields-gate.sh` (§20 generic
  fields) stays wired in at the core-canon level, referenced by path;
  these five gates are additive on top of it, each checking exactly one
  domain-specific component — never re-checking what §20 already
  covers (what-was-done/why/upstream-basis/loop_state/open-findings).

## (3) Gate tests — one test file per plugin

Each plugin owns `tests/<name>-gate.test.sh` inside its own plugin
directory (no shared root `tests/` — this repo currently has none;
per-plugin test ownership mirrors the per-plugin independence the
FEEDBACK asks for), following the convention both reference repos use
(`pricing-rulebook`'s `hooks/tests/stub-check.sh`,
`implementation-rulebook`'s `tests/run-gate-tests.sh`): construct sample
`Write`/`Edit` tool-call JSON payloads on stdin, invoke that plugin's own
gate script directly, assert exit code. A thin repo-root
`tests/run-all.sh` (new) sources all five, so `implementation-rulebook`-
style single-command test running still works across the set.

Required cases per plugin, phase 2 will implement all of them:
- `phase1-basis`: (a) proposal with basis reference → exit 0; (b) missing
  → exit 2; (c) outside scope regex → exit 0 (gate silent); (d) malformed
  JSON → exit 2; (e) kill switch set → exit 0 unconditionally.
- `decision-rationale`: (a) phase-1 proposal with rationale statement →
  exit 0; (b) missing → exit 2; (c) phase-2 record, all strings with
  `[decision] → [why]` → exit 0; (d) one string missing it → exit 2,
  message names the string.
- `tone-axis`: (a) axis named → exit 0; (b) explicit skip + reason →
  exit 0; (c) silently absent → exit 2, message names `tone-axis`.
- `ab-spec`: (a) one varied element + signal → exit 0; (b) "not
  applicable" + reason → exit 0; (c) more than one varied element →
  exit 2; (d) silently absent → exit 2.
- `self-critique`: (a) present, after the other three sections → exit 0;
  (b) missing → exit 2; (c) present but textually *before* rationale →
  exit 2 (ordering check).
- Shared across all five: malformed/unparseable JSON → exit 2
  (fail-closed); each plugin's own kill switch set → exit 0
  unconditionally; write outside that plugin's scope regex → exit 0.

Test harnesses are new to this repo but copy no `core/hooks/tests/*`
file — shape/convention referenced only, same "referenced, never
copied" clause applied one level down.

## (4) Agents / checklists

No new `agents/` directory in any of the five plugins. Issue-1's adopted
methodology has exactly one repeated procedure per plugin (one component,
checked once per string) — small enough to live inside each plugin's own
one-paragraph doc/handbook entry; no multi-turn, stateful, or
tool-driven loop exists that an agent definition would add value over
a static per-plugin checklist (contrast `pricing-research`'s multi-gate
skill, which genuinely branches on method family — none of these five
components branch). `docs/handbooks/content-design/methodology.md`
(new, shared across the set — see (1)) doubles as the checklist
artifact issue #7 item 4 asks for, conditioned on "if the methodology
requires one" — it does not, beyond the handbook, for any of the five.

## Rejected alternatives

- **A single monolithic `methodology-gate.sh` inside the one existing
  `content-design` plugin** (this proposal's own rev.1): rejected per
  the approver's FEEDBACK — it concatenates five methodology components
  into one script instead of registering them as independent,
  freelunch/scout-grade plugins; a gate wired this way cannot be
  disabled, tested, or reused per-component, and the FEEDBACK is
  explicit that "단일 게이트/디렉티브 심화" is not the required shape.
- **Cross-role `loop_state` state-tracking gate** (coding-progress-gate
  pattern): rejected because content-design's methodology has no
  cross-role handoff to track (survey.md §5) — building one would
  invent an ordering constraint the adopted methodology never specified,
  the same overreach issue-1's own proposal explicitly avoided when it
  chose not to force live A/B execution.
- **Expanding `directive.sh`'s `PRODUCES` line further**: rejected,
  unchanged from issue-1's finding — no fifth slot exists in
  `core_role_directive`; depth belongs in the handbook + plugin set, not
  in a longer single line.
- **Vendoring `pricing/hooks/methodology-gate.sh` and role-token-swapping
  it**: rejected — it is not a `core/hooks/**` canon file so
  canon-scripts.md's manifest mechanism doesn't cover it directly, but
  copying another rulebook's per-role file verbatim would recreate
  exactly the copy-paste drift class record-fields-gate's promotion
  history (issue-66) was written to stop; each of the five new plugins
  writes its own file scoped to its own regex/element, modeled on it,
  not copied from it.
- **One shared library script sourced by all five gates**: rejected —
  a shared `source`d file would make the five plugins depend on each
  other's presence, contradicting "each is independently disable-able";
  the shared *shape* (fail-closed trap, kill-switch convention) is
  duplicated per plugin instead, the same tradeoff core canon itself
  makes across its own independent plugins.

## Plugin reflection plan (phase 2 — not applied in this PR)

- `content-design-phase1-basis/` — new plugin directory: `.claude-plugin/
  plugin.json`, `hooks/phase1-basis-gate.sh`, `hooks/hooks.json`,
  `tests/phase1-basis-gate.test.sh` (per (0)-(3)).
- `content-design-decision-rationale/` — new plugin directory, same
  internal shape, `hooks/decision-rationale-gate.sh`.
- `content-design-tone-axis/` — new plugin directory, same shape,
  `hooks/tone-axis-gate.sh`.
- `content-design-ab-spec/` — new plugin directory, same shape,
  `hooks/ab-spec-gate.sh`.
- `content-design-self-critique/` — new plugin directory, same shape,
  `hooks/self-critique-gate.sh`.
- `.claude-plugin/marketplace.json` — edited: five new plugin entries
  added alongside the existing `content-design` entry (unchanged).
- `content-design/hooks/directive.sh` — unchanged (per (1), no fifth
  slot to fill; the existing plugin keeps owning only `SessionStart`).
- `docs/handbooks/content-design/methodology.md` — new (per (1) and
  (4)), shared reference doc across the plugin set.
- `tests/run-all.sh` — new, thin sourcing wrapper across the five
  per-plugin test files (per (3)).
- `docs/issue-7/reports/content-design.md` — phase-2 record, opened
  only after Approve.

## How success will be judged

- A phase-2 record missing tone-axis (and no skip reason) or
  self-critique is rejected by `content-design-tone-axis` /
  `content-design-self-critique` respectively, before it can be
  committed — each plugin denying independently, on its own component.
- A record with self-critique appearing before the rationale/tone
  sections it claims to check is rejected by
  `content-design-self-critique`'s ordering check.
- All required cases in (3), across all five plugins, pass against the
  implemented gates.
- `marketplace.json` lists six `content-design*` plugin entries after
  phase 2 (the original `content-design` plus the five new ones), each
  independently loadable and independently kill-switchable.
- `docs/issue-7/reports/content-design.md` (phase 2, once approved)
  records each plugin's implementation and its own test run's pass/fail
  output.

## Files (write set, once approved)

- `content-design-phase1-basis/.claude-plugin/plugin.json`,
  `hooks/phase1-basis-gate.sh`, `hooks/hooks.json`,
  `tests/phase1-basis-gate.test.sh` (new)
- `content-design-decision-rationale/.claude-plugin/plugin.json`,
  `hooks/decision-rationale-gate.sh`, `hooks/hooks.json`,
  `tests/decision-rationale-gate.test.sh` (new)
- `content-design-tone-axis/.claude-plugin/plugin.json`,
  `hooks/tone-axis-gate.sh`, `hooks/hooks.json`,
  `tests/tone-axis-gate.test.sh` (new)
- `content-design-ab-spec/.claude-plugin/plugin.json`,
  `hooks/ab-spec-gate.sh`, `hooks/hooks.json`,
  `tests/ab-spec-gate.test.sh` (new)
- `content-design-self-critique/.claude-plugin/plugin.json`,
  `hooks/self-critique-gate.sh`, `hooks/hooks.json`,
  `tests/self-critique-gate.test.sh` (new)
- `.claude-plugin/marketplace.json` (edited — five new entries)
- `docs/handbooks/content-design/methodology.md` (new)
- `tests/run-all.sh` (new)
- `docs/issue-7/reports/content-design.md` (phase-2 record)

## Open questions for phase 2

1. Exact keyword/phrase list the gate matches for "decision-tied
   rationale" structure (arrow/because/so-that constructions) is a
   phase-2 implementation detail; the required *presence and shape* is
   fixed by this proposal, exact regex is mechanical.
2. Whether `RECORD_FIELDS_TERMINAL_STATES` needs a content-design-
   specific value (core gate already supports per-role config via env
   var, per `record-fields-gate.sh`'s own header) — current default
   (`landed`) appears sufficient per issue-1's precedent; phase 2
   confirms no change needed unless a concrete conflict surfaces.
