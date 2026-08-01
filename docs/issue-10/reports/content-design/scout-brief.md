# Issue #10 scout — skip record

**Skip condition:** "the spec literally leaves no design decision open" (scout-directive's second
skip condition). This is an internal-standard-adoption task: issue #10's mandatory prerequisite is
core issue #72's `gate-lib.sh`/`gate-lib.py` (landed on `tokenmaxxxer-core` main), and issue #10's
own text forbids self-reimplementation ("자체 재구현 금지") — the mechanics (path normalization,
kill-switch semantics, Write/Edit/MultiEdit/NotebookEdit reconstruction, deny protocol) are fixed
by that library's API, not by a product-shaped design space with external exemplars to compare.
The one open design axis — how to upgrade the 5 gates' semantic checks from substring/mention to
section/adjacency/structure — is specific to this repo's own doctrine text (survey.md sections 3-4)
and has no comparable external product to scout against; a search for prior migrations
(`gh search code gate_normalize_path --owner tokenmaxxxer`, `gh api search/code` for the same) came
back empty — no other rulebook has done this migration yet, so there is no in-org exemplar either.

Per the directive, this record substitutes for the sweep; the proposal is built on
`core/hooks/lib/gate-lib.sh`/`gate-lib.py`'s own usage comments and
`docs/handbooks/gate-house-standard.md`'s migration checklist directly (see survey.md's "what
already exists" section for what was read).
