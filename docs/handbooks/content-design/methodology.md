# Content-design methodology handbook

Gate = mechanical minimum (the five `content-design-*` plugins), this
handbook = worked guidance. Kept in sync with the gates' own parsers —
if a gate's check logic changes, this file changes with it. Basis:
`docs/issue-7/proposals/content-design.md` (0)-(1), itself carrying
forward issue-1's adopted methodology unchanged.

## Phase-1 proposal facet

**Steps**: current-state survey → scout (or stated skip) → proposal, per
the standing scout-directive (procedural, not duplicated here).

**Judgment criteria**: every proposed copy/pattern change states which
named user decision it serves before stating why the wording changes. A
rationale that doesn't name the decision fails regardless of how
well-written the prose is. Enforced mechanically by
`content-design-decision-rationale` (proposal mode) +
`content-design-phase1-basis` (survey/scout basis).

**Prohibitions**: no "sounds better"/"clearer"/"more friendly" as a
complete rationale; no unsourced "industry standard" claims; no
resurrecting practices the field has already refuted for this role.

## Phase-2 record facet, per copy string touched

**Steps**, in this order (self-critique's own definition — "check the
draft against items 2-4" — is not meaningful before they exist):
draft → rationale → tone-axis check (or skip-reason) → A/B spec (or
"not applicable" + why) → self-critique.

**Judgment criteria**:
- Tone-axis check names which of the 4 NN Group axes (Funny↔Serious,
  Formal↔Casual, Respectful↔Irreverent, Enthusiastic↔Matter-of-fact) is
  live for this string and where it targets; a skip is valid only with a
  one-line reason (e.g. fixed legal string).
- A/B spec, when given, isolates exactly one changed element and names
  the user-behavior signal that would prefer the variant.
- Self-critique is a genuine check, not a restatement — it must be able
  to say "this fails axis-check X" and not merely "looks good."

**Prohibitions**: no string ships with a tone-axis section that is
silently absent (must be present-or-skipped-with-reason, never just
missing); no self-critique note that doesn't reference the rationale/
tone/A-B content it's checking; no A/B spec with more than one varied
element.

## Which plugin checks what

| Facet | Plugin |
|---|---|
| Phase-1 survey+scout basis | `content-design-phase1-basis` |
| Decision-tied rationale (both phases) | `content-design-decision-rationale` |
| Tone-axis check | `content-design-tone-axis` |
| A/B variant spec | `content-design-ab-spec` |
| Self-critique + ordering | `content-design-self-critique` |

Section convention the four phase-2 gates all read: each copy string
gets its own `### Copy string: <name>` (or `##`/`####`, same regex)
header; each plugin scopes its check to that section's body, up to the
next same-or-higher-level header. `content-design-self-critique` is the
only one of the four that also reads the *other three's* section
markers (rationale/tone/A-B), to check ordering — it does not call
their scripts.
