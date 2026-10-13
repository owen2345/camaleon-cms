---
name: review-loop
description: Run one pass of the review-fix loop on a PR of camaleon-cms or of a sibling plugin, theme or host app checkout (/code-review --fix with a ledger, verdict rules, the AGENTS.md checks and a PASS line). Use only when the user or an active /goal asks for the review loop.
---

# Review loop

Repeated `/code-review <effort> --fix` passes on a PR's local branch until they converge. Each pass reviews, applies what the verdicts allow, commits each fix after its checks, and ends its turn with a PASS line. To run passes until the loop stops, type this with the parameters filled in (a skill can't start a goal):

```text
/goal Run the review-loop skill with repo=<repo> pr=<number> effort=<level> decision=<stop or important>, one pass per turn. Continue until the latest PASS line's last field starts with STOP. Each turn ends with its PASS line, and a PASS line that ends in continue never meets this goal, whatever its state. A STOP for convergence counts only if the latest PASS line shows CLEAN and the one before it, from the same run, SETTLED or CLEAN. Both lines must show git status clean, rspec 0 failures and no errors, or n/a, and every check ok or n/a. A STOP for any other reason the skill gives counts as it stands. A STOP that pushed counts only if its checks field shows ci as ok or n/a, unless it stopped on a DECISION row.
```

The Skill tool loads this file live from the checkout, and the harness loads `AGENTS.md` live. So every run works from copies of its rule files, which this file makes at the start of the run. The rules of a run do not change while it runs. `procedure.md` beside this file holds the procedure of a run, and its copy is the one to follow.

## Parameters

Read them from the goal, the skill's arguments or the request; each has a default.

- **repo:** the checkout's directory name: `camaleon-cms` (default: the session's own checkout) or a sibling checkout, a plugin or theme such as `camaleon-cms-seo` or a host app such as `florsan`, at `../<repo>` from camaleon-cms. The session always runs in the main camaleon-cms checkout, where this harness and the ledgers live: from an app-made worktree of it (`.claude/worktrees/<name>`), `../<repo>` would resolve under `.claude/worktrees/` and the ledger inside the worktree, deleted with it. A core PR runs in that main checkout, which the user switches to its head branch (setup never does): the skill has no worktree option, by decision, since worktrees are very inconvenient in JetBrains IDEs.
- **pr:** the PR number in that repo's GitHub project. Default: the PR of the checkout's current branch.
- **effort:** the `/code-review` level: `low`, `medium`, `high` (default), `xhigh` or `max`. Not `ultra`: that cloud review can only be launched by the user.
- **decision:** `stop`, `important` or absent (default). `procedure.md`, Pass states and stop, says which DECISION row stops the run after its pass.

## Rules

The rule files, all of camaleon-cms, are:

- `procedure.md` and `trace.md` of this skill
- `docs/ai/workflows.md`
- `docs/ai/failures.md`
- `docs/ai/testing.md`
- `docs/ai/prose.md`
- `AGENTS.md`

The live files are the files of the checkout, and they change with it. A PR that edits them changes the rules with each fix. During a plugin run, another session or the IDE can switch the camaleon-cms checkout.

Each turn reads the last run header or PASS line of the ledger, `tmp/review-loop/<repo>/<pr>.md` in camaleon-cms (`procedure.md`, Setup): `grep -E '^(## Run|PASS )' <ledger> | tail -n 1`. Then it does one of these:

- The line is a run header, or a PASS line whose last field is `continue`: the last run is not over. Load the copy of `procedure.md` under `tmp/review-loop/<repo>/<pr>.rules/`, and follow it.
- Otherwise a new run starts: the line is a PASS line with a STOP, or there is no line. Remove `tmp/review-loop/<repo>/<pr>.rules/`, which lasts as long as the run (the scratchpad does not), and make it again (`mkdir -p`). Then save the head version of the rule files in it with one command in camaleon-cms: `set -o pipefail; git archive HEAD AGENTS.md docs/ai/workflows.md docs/ai/failures.md docs/ai/testing.md docs/ai/prose.md .claude/skills/review-loop/procedure.md .claude/skills/review-loop/trace.md | tar -x -C tmp/review-loop/<repo>/<pr>.rules`. Each copy is then at its path from the root of camaleon-cms, for example `.claude/skills/review-loop/procedure.md`. A failed `git archive` leaves no file, and with `pipefail` the command exits with its code. Then follow the copy of `procedure.md` from its Setup, which appends the run header.

Load the other rule files from the same directory when the procedure first needs them:

- `docs/ai/workflows.md`, `docs/ai/prose.md` and `AGENTS.md` at the first fix of the pass, or at a stop that pushes.
- `docs/ai/testing.md` before the first background task of the pass, a spec run included.
- `docs/ai/failures.md` at a failed check.
- `trace.md` at a failed suite job.

When a rule file and its copy differ, follow the copy, not the live text that the harness loads. When a copy does not exist, save only that copy then, as above.
