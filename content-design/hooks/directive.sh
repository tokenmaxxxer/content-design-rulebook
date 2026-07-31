#!/usr/bin/env bash
# SessionStart: content-design's role directive — how this role fills the core
# lifecycle. Kill switch: export CONTENT_DESIGN_CYCLE_OFF=1
. "${CLAUDE_PLUGIN_ROOT_CORE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../core" && pwd -P)}/hooks/lib/role-directive.sh"
YOU_DECIDE="YOU DECIDE: 문구가 사용자의 실제 결정을 돕는가"
USE_WHEN="USE_WHEN: 플로우에 새 카피/마이크로카피가 걸릴 때"
PRODUCES="PRODUCES (required record fields): copy draft, decision-tied rationale per string, tone-axis check (NN Group 4-axis, skip with reason if inapplicable), testable A/B variant spec (if applicable), self-critique note"
HAND_OFF="HAND-OFF: 화면/플로우 구조 자체가 바뀌어야 하면 → interaction-design"
core_role_directive "$YOU_DECIDE" "$USE_WHEN" "$PRODUCES" "$HAND_OFF"
