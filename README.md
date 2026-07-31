# content-design-rulebook

Rulebook for the `content-design` role (contract v3 role-handoff protocol), split off
per `docs/issue-160/proposals/role-taxonomy.md`'s round-3 promotion and
generated as skeleton scaffolding by issue-170.

- **decides**: 문구가 사용자의 실제 결정을 돕는가
- **use_when**: 플로우에 새 카피/마이크로카피가 걸릴 때
- **produces**: copy draft, rationale per string, A/B alternative (if applicable)
- **write_scope**: []
- **hand-off**: 화면/플로우 구조 자체가 바뀌어야 하면 → interaction-design

## Install

```
claude plugin marketplace add tokenmaxxxer/content-design-rulebook
claude plugin install content-design
```

## Layout

- `content-design/.claude-plugin/plugin.json` — plugin manifest
- `content-design/hooks/hooks.json` — SessionStart wiring (directive.sh only)
- `content-design/hooks/directive.sh` — SessionStart role directive; stub that
  sources core canon's `core/hooks/lib/role-directive.sh` and passes this
  role's four unique values (core issue #66)
- `docs/specs/approvers.md` — Approve-authority allowlist (see below)

The role-agnostic gates (record-fields, trailer, handbook-trigger) and the
warrant-hunt background agent no longer have local copies here — they are
core canon, registered globally via `core/hooks/hooks.json` (core issue #66)
and the `warrant/` plugin (core issue #63) and fire for every role through
`CLAUDE_ROLE` injection. This role's required-record-field list (copy draft,
rationale per string, A/B alternative) lives only in `directive.sh`'s
PRODUCES line — core's `record-fields-gate.sh` checks contract §20's
generic fields (what-was-done/why/upstream-basis/loop_state/open-findings),
not a per-role field list, so no separate config file is needed for it.

This is scaffolding, not a finished rulebook: fill in doctrine detail,
handoff enforcement, and any role-specific progress gate before treating
it as load-bearing.
