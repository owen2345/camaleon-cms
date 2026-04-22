# Quality Gate and System Review

## Quality Gate
Before marking any task complete, evaluate it against `quality/criteria.md`.

## Criteria Maintenance
After evaluation:
- If a criterion catches a real issue, update its `Last triggered` date.
- If a criterion triggers 3+ times, promote it to an always-check item.
- If a criterion never triggers after 10+ evaluations, suggest pruning it.
- If you find a new failure pattern, flag it and propose a new criterion; do not add it silently.

## If `docs/ai/quality/criteria.md` Is Missing
- Create it with initial criteria based on the project domain and current standards.
- Ask the user to review the initial criteria.

## System Review Schedule
Last system review: not yet

Do not run a full system review automatically. Suggest one when **any** of these triggers fires:

**Time-based:**
- 2+ weeks have passed since the last review date above.

**Trigger-based:**
- The project hits a milestone (e.g., first successful AIS flow, first TPP registration).
- A quality criterion fires 3+ times in a short period.
- A knowledge rule gets contradicted by new evidence.
- A decision record is superseded.

Suggested review scope:
- Prune stale rules in `docs/ai/knowledge/` that have not been applied in 30+ days.
- Check whether any hypothesis has enough evidence to promote or enough contradictions to discard.
- Review decision outcomes and whether their trade-offs played out as expected.
- Evaluate quality criteria: promote frequent triggers and flag never-triggered criteria for pruning.
- Report what changed and why.
- Update the `Last system review` date above.
