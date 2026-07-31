# Issue #1 — Scout Brief (role: content-design)

Mode: batched-sequential fallback (4 WebSearch calls issued in one turn;
session had no parallel-subagent dispatch available for this step, so
angles ran as concurrent tool calls in a single message). Stages used: 1
sweep, saturation reached — no deepening round needed (all 4 angles
converged on the same handful of concepts: voice/tone framework, rationale
discipline, critique-as-gate, controlled-comparison testing).

## Search angles run
1. UX writing process / NN Group standard
2. Enterprise content style guides (Mailchimp, Atlassian, Google)
3. Microcopy rationale + critique practice
4. A/B copy-testing methodology

## Must-bes (Kano) the field converges on
- **Rationale is mandatory, not optional.** "As a UX writer you should
  always be able to explain the rationale behind your copy choices" —
  every strong source treats an un-justified copy choice as incomplete
  work, not a style preference.
- **Voice vs. tone distinction.** Voice = fixed brand identity; tone =
  context-dependent modulation. Mailchimp's guide names this explicitly
  as the organizing axis of their whole style guide.
- **Critique is a gate, not a courtesy.** "Copy reviews should be included
  in your definition of done ... microcopy should be treated as a
  first-class design element" — review/critique is load-bearing, not a
  nice-to-have.
- **Claims about what copy does must be testable.** A/B / controlled
  comparison is the field's standard mechanism for turning "I think this
  copy is better" into evidence — isolate one variable per test.

## Performance axes (where strong practice visibly competes)
1. **Specificity of rationale** — generic ("sounds better") vs. tied to a
   named user decision/task the string unblocks.
2. **Tone dimensioning** — NN Group's 4-axis framework (Funny↔Serious,
   Formal↔Casual, Respectful↔Irreverent, Enthusiastic↔Matter-of-fact) vs.
   unstructured "sound friendly" guidance.
3. **Evidence tier for claims** — pre-registered A/B/test plan vs. no plan
   at all vs. post-hoc anecdote.

## Adopt / skip
- **Adopt:** per-string rationale requirement tied to a user decision
  (maps directly to this role's own YOU_DECIDE line: "문구가 사용자의 실제
  결정을 돕는가").
  **Skip:** requiring a full brand voice-and-tone document per proposal —
  that's a program-level artifact (owned once, referenced many times), not
  a per-flow copy deliverable; mandating it per issue would be scope
  creep beyond what a single content-design pass produces.
- **Adopt:** critique/review as a required proposal step (self-critique
  checklist, since no separate reviewer role exists in this repo's
  lifecycle before phase-2 Approve).
  **Skip:** mandating live A/B test execution as a phase-2 required
  component — this repo has no experimentation infra; instead adopt the
  *artifact* (a testable hypothesis / variant spec) without the
  infrastructure dependency.

## Segment fit
This repo's content-design role is scoped to microcopy inside existing
flows (per plugin.json: "플로우에 새 카피/마이크로카피가 걸릴 때"), not
full brand-voice ownership — so the field's per-string/per-flow practices
(rationale, critique, testable-variant) fit directly; program-level
artifacts (full style guide, brand voice doc) are out of scope and
correctly skipped.

## Gap line
Current state (`content-design/hooks/directive.sh`) already requires
`PRODUCES: copy draft, rationale per string, A/B alternative (if
applicable)` — this already covers 2 of 4 must-bes (rationale, testable
variant) as directive text, but:
- **Missing:** no *method* for producing the rationale (nothing ties it to
  a named user decision) — directive says "rationale" but not what makes
  one adequate.
- **Missing:** no critique/review step before a copy draft is considered
  proposal-ready.
- **Present but implicit:** tone is not dimensioned — "A/B alternative"
  exists as a field but nothing structures *what axis* the alternative
  varies on.
- **Not gated:** contract v3 record-fields (§20 generic fields) apply, but
  no role-specific mechanical check enforces content-design's PRODUCES
  list (confirmed by issue-2's phase-2 record: core's record-fields-gate
  has no per-role `REQUIRED_FIELDS` concept).

## Sources
- https://www.nngroup.com/articles/
- https://medium.com/design-bootcamp/my-top-free-selection-of-ux-study-guides-from-nielsen-norman-group-nn-group-79d51858f510
- https://styleguide.mailchimp.com/voice-and-tone/
- https://github.com/mailchimp/content-style-guide/blob/master/02-voice-and-tone.html.md
- https://uxcontent.com/what-is-microcopy/
- https://www.smashingmagazine.com/2024/06/how-improve-microcopy-ux-writing-tips-non-ux-writers/
- https://unbounce.com/a-b-testing/examples/
