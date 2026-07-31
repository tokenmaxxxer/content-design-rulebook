# Issue #1 — Phase 1 Proposal (role: content-design)

Subject: issue-1

Phase-1 only: this document is research + a recommended norm. No plugin
file changes happen here; phase 2 opens only on an Approve per contract
v3 s19, recorded in `docs/specs/approvers.md`.

Basis: `docs/issue-1/reports/content-design/survey.md` (current-state
survey) and `docs/issue-1/reports/content-design/scout-brief.md` (domain
scout: NN Group UX-writing framework, Mailchimp/Atlassian/Google style
guides, microcopy critique practice, A/B copy-testing methodology — full
source list in the brief).

## (a) Phase-1 proposal norm — methodology, required sections, evidence format

Every future content-design phase-1 proposal (this document included)
must:

1. **Run current-state survey before scout**, per the standing
   scout-directive — already enforced procedurally, not new to codify
   here, but stated for completeness.
2. **State a rationale per proposed copy/pattern change, tied to a named
   user decision** — not "sounds better" but "this string exists so the
   user can decide X; the proposed wording changes because Y." This is
   the single highest-consensus must-be across all four scouted sources
   (NN Group, Mailchimp, UX Content Collective, Smashing Magazine all
   independently converge on rationale-over-preference).
3. **Include required sections**: Basis (links to survey + scout brief),
   the adoption table itself, adoption rationale per row, and an
   evidence-format statement citing which scouted source backs each
   adopted practice (a claim with no traceable source is an assumption,
   labeled as such — carried over from scout-directive's own rule, made
   binding on phase-1 proposals specifically so it survives beyond this
   one issue).
4. **Evidence format**: cite by URL (not by vague "industry standard"
   language) for every adopted practice, consistent with the scout
   brief's own sourcing discipline.

## (b) Phase-2 deliverable norm — methodology, required components

Every content-design phase-2 record (a copy change delivered under this
role) must include, per copy string touched:

1. **Copy draft** — the proposed string(s) (already required by the
   existing `PRODUCES` directive line; retained).
2. **Rationale, structured as**: `[user decision this string serves] →
   [why the proposed wording serves it better than the status quo]`.
   Adopted from the must-be in scout-brief.md §"Must-bes" — generic
   rationale ("clearer", "more friendly") does not satisfy this; it must
   name the decision.
3. **Tone check against a named axis**, using NN Group's 4-dimension
   tone framework (Funny↔Serious, Formal↔Casual, Respectful↔Irreverent,
   Enthusiastic↔Matter-of-fact) — state which axis position the string
   targets and why, when tone is a live variable for that string (skip
   the check with a one-line reason when it plainly isn't, e.g. a fixed
   legal disclaimer string). Adopted because the field's highest-signal
   differentiator between structured and unstructured practice is
   exactly this dimensioning (scout-brief.md §"Performance axes" item 2).
4. **A/B alternative, as a testable-variant spec, when applicable** —
   already named in the existing directive; this proposal clarifies the
   bar: the variant must isolate exactly one changed element from the
   draft (per A/B-testing best practice: "make sure there is just one
   design element that differs") and state what user behavior the test
   would need to move to prefer the variant. This role does not require
   *running* the test — no experimentation infra exists in this repo —
   only that the artifact be structured so a test could be run later
   without rework.
5. **Self-critique note** — one paragraph checking the draft against
   items 2–4 before the record is filed, since this repo's lifecycle has
   no separate reviewer role before the phase-2 Approve gate. Adopted
   because the field treats critique as a required gate ("copy reviews
   should be included in your definition of done"), and the repo
   currently has no mechanism providing that gate for content-design.

## (c) Adoption rationale (why these, not alternatives)

| Adopted | Why it must follow from this role's stated value |
|---|---|
| Decision-tied rationale | `directive.sh`'s own YOU_DECIDE line is "문구가 사용자의 실제 결정을 돕는가" (does the copy help the user's actual decision). A rationale that doesn't name the decision cannot demonstrate the mandate was met — the field's practice and this role's charter are the same claim stated twice, so adopting it isn't a stylistic choice, it's making the charter checkable. |
| NN Group 4-axis tone check | The role's `USE_WHEN` is narrowly scoped to in-flow microcopy, not brand ownership — a lightweight per-string axis check fits that scope; a full voice-and-tone *document* (the field's other common artifact) would be scope creep into a program-level deliverable this role doesn't own. Skipped for that reason (see scout-brief.md §"Adopt/skip"). |
| Testable-variant spec without live execution | Matches this role's existing `PRODUCES` field ("A/B alternative (if applicable)") — the field's practice is adopted at the artifact level only, because adopting live test execution would require infra this repo doesn't have and would silently expand phase-2 scope beyond copy production into experimentation ops, which is a different role's concern. |
| Self-critique gate | The repo's lifecycle (per contract v3 s19) has exactly one human checkpoint (the Approve) and no reviewer role before it; without a self-critique step, "critique is a required gate" (the field's practice) would have zero representation in this repo's actual process. Adding it as a self-check is the only way to honor that must-be given the lifecycle as it exists. |

## (d) Plugin reflection plan (phase 2 target — directive / record fields / gates)

To be executed only after Approve, against `content-design/hooks/`:

1. **`directive.sh` — `PRODUCES` line**: expand from `"copy draft,
   rationale per string, A/B alternative (if applicable)"` to name the
   four phase-2 components from (b): `"copy draft, decision-tied rationale
   per string, tone-axis check (NN Group 4-axis, skip with reason if
   inapplicable), testable A/B variant spec (if applicable),
   self-critique note"`. Mechanical text edit, matching this repo's
   existing directive-as-documentation pattern (confirmed in
   `survey.md` — no per-role mechanical gate exists in core canon for
   `REQUIRED_FIELDS` today, per issue-2's phase-2 record finding).
2. **Record-fields gate**: no local gate exists today and none is
   proposed — per issue-2 precedent, core's `record-fields-gate.sh` only
   enforces contract §20 generic fields, not per-role produces-lists.
   This proposal does **not** invent a new local gate for this (would
   duplicate the issue-2-established anti-pattern of vendoring
   role-specific mechanics locally); the PRODUCES line stays
   documentation-only, enforced by self-critique + phase-2 record
   author's own filing discipline, exactly as `implementation`'s does
   today.
3. **New gate to add — proposal-shape check**: none proposed as a
   mechanical hook; phase-1 proposal-shape conformance (required
   sections in (a)) is checked by the human Approve step itself, since
   contract v3 s19 already routes every phase-1 proposal through a human
   read before Approve — adding a redundant mechanical gate would not
   change what's enforced, only add a second copy of the same check.
4. **warrant-hunter**: no change. Confirmed in `survey.md` that no local
   warrant-hunter file exists to duplicate; core canon (issue #63)
   already covers this role with zero local registration, matching
   `implementation`'s post-issue-2 state exactly.
5. **`hooks.json`**: no change — already minimal (`SessionStart` only),
   matching the target state `implementation` converged to after its own
   issue-2 cleanup.

## File-by-file summary (phase 2, pending Approve)

| File | Action |
|---|---|
| `content-design/hooks/directive.sh` | edit `PRODUCES` line to the 5-part list in (d)1 |
| `content-design/hooks/hooks.json` | no change |
| `content-design/agents/` | no change (does not exist; not created) |
| `content-design/.claude-plugin/plugin.json` | no change |
| `docs/issue-1/reports/content-design.md` | new — phase-2 record, opened only after Approve |

## Open questions for phase 2

1. Whether any future core-canon enhancement adds a per-role
   `REQUIRED_FIELDS` gate mechanism (per issue-2's open item on this) —
   if it lands before this issue's phase 2, wire content-design's 5-part
   PRODUCES list into it instead of leaving it documentation-only.
2. Exact wording polish of the expanded `PRODUCES` line is a phase-2
   editorial detail, not a phase-1 decision — the 5 required components
   and their order are fixed by this proposal; exact phrasing is
   mechanical.
