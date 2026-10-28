---
name: review-loop
description: Run one pass of the review-fix loop on a PR of camaleon-cms or of a sibling plugin, theme or host app checkout. Use only when the user or an active /goal asks for the review loop.
---

# Review loop

Repeated `/code-review <effort> --fix` passes on the local branch of a PR until they converge. Each pass reviews, applies what the verdicts allow, commits each fix after its checks, and ends its turn with a PASS line. To run passes until the loop stops, type this with the parameters filled in (a skill cannot start a goal):

```text
/goal Run the review-loop skill with repo=<repo> pr=<number> effort=<level> decision=<stop or important>, one pass per turn. Continue until the latest PASS line's last field starts with STOP. Each turn ends with its PASS line, and a PASS line that ends in continue never meets this goal, whatever its state. A STOP for convergence counts only if the latest PASS line shows CLEAN or REWORK. The PASS line before it, from the same run, must show SETTLED, CLEAN or REWORK. Both lines must show git status clean, rspec 0 failures and no errors, or n/a, and every check ok or n/a. A STOP for any other reason that the skill gives meets the goal, with one exception. A STOP that pushed counts only if its checks field shows ci as ok or n/a, unless it stopped on a DECISION or CONFLICT row.
```

This file copies the rule files at the start of a run, and the run follows the copies. `procedure.md` holds the procedure, and the other files of this skill the parts of one step each.

## Parameters

Read them from the goal, the skill's arguments or the request.

- **repo:** the directory name of the checkout: `camaleon-cms` (default) or a sibling plugin, theme or host app checkout at `../<repo>`, such as `camaleon-cms-seo` or `florsan`. The session runs in the main camaleon-cms checkout, where the ledgers live, never in a worktree of it (the user's decision). The user switches that checkout to the head branch of a camaleon-cms PR. Setup never switches the checkout.
- **pr:** the PR number in the GitHub project of that repo. Default: the PR of the current branch of the checkout.
- **effort:** the `/code-review` level: `low`, `medium`, `high` (default), `xhigh` or `max`. Only the user can launch `ultra`.
- **decision:** `stop`, `important` or absent (default): which DECISION or CONFLICT row stops the run after its pass (`procedure.md`, Pass states and stop).

## Rules

The rule files are `AGENTS.md`, the files under `docs/ai` and the other files of this skill, all in camaleon-cms. Each turn reads the last run header or PASS line of the ledger, `tmp/review-loop/<repo>/<pr>.md` in camaleon-cms: `grep -aE '^(## Run|PASS )' <ledger> | tail -n 1`. A run header, or a PASS line whose last field is `continue`, means that the run is not over. Then follow the copy of `procedure.md` under `tmp/review-loop/<repo>/<pr>.rules/` from Pass start.

Otherwise a new run starts. Remove `tmp/review-loop/<repo>/<pr>.rules/` and `tmp/review-loop/<repo>/<pr>.candidates/`, make both again (`mkdir -p`), and copy the rule files at HEAD: `set -o pipefail; git archive HEAD AGENTS.md docs/ai .claude/skills/review-loop | tar -x -C tmp/review-loop/<repo>/<pr>.rules`. An exit code other than 0 stops the turn in a `PASS 0/8` line, in the form of the live `procedure.md`. Otherwise load the copies of `procedure.md` and `setup.md` with the Read tool, and follow `setup.md`, then `procedure.md` from Pass start.

A step that sends the run to another rule file loads its copy the same way. A turn loads a copy only when its context holds no Read of it from this run. A pointer that only names a file loads nothing. When a rule file and its copy differ, follow the copy. When a copy does not exist, stop and say so in the PASS line of the live `procedure.md`.
