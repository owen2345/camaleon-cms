---
name: review-loop
description: Run one pass of the review-fix loop on a PR of camaleon-cms or of a sibling plugin, theme or host app checkout (/code-review --fix with a ledger, verdict rules, the AGENTS.md checks and a PASS line). Use only when the user or an active /goal asks for the review loop.
---

# Review loop

Repeated `/code-review <effort> --fix` passes on a PR's local branch until they converge. Each pass reviews, applies what the verdicts allow, commits each fix after its checks, and ends its turn with a PASS line. To run passes until the loop stops, type this with the parameters filled in (a skill can't start a goal):

```text
/goal Run the review-loop skill with repo=<repo> pr=<number> effort=<level> decision=<stop or important>, one pass per turn. Continue until the latest PASS line's last field starts with STOP. Each turn ends with its PASS line, and a PASS line that ends in continue never meets this goal, whatever its state. A STOP for convergence counts only if the latest PASS line shows CLEAN and the one before it, from the same run, SETTLED or CLEAN. Both lines must show git status clean, rspec 0 failures and no errors, or n/a, and every check ok or n/a. A STOP for any other reason that the skill gives meets the goal, with one exception. A STOP that pushed counts only if its checks field shows ci as ok or n/a, unless it stopped on a DECISION or CONFLICT row.
```

The Skill tool loads this file live from the checkout, and the harness loads `AGENTS.md` when the session starts. So every run works from copies of its rule files, which this file makes at the start of the run. The rules of a run do not change while it runs. `procedure.md` beside this file holds the procedure of a run. `setup.md`, `resume.md`, `ci.md`, `spec-runs.md` and `trace.md` hold the parts that a pass follows only at the step that names them. The copies of these files are the ones to follow.

## Parameters

Read them from the goal, the skill's arguments or the request; each has a default.

- **repo:** the checkout's directory name: `camaleon-cms` (default: the session's own checkout) or a sibling checkout, a plugin or theme such as `camaleon-cms-seo` or a host app such as `florsan`, at `../<repo>` from camaleon-cms. The session always runs in the main camaleon-cms checkout, where this harness and the ledgers live: from an app-made worktree of it (`.claude/worktrees/<name>`), `../<repo>` would resolve under `.claude/worktrees/` and the ledger inside the worktree, deleted with it. A core PR runs in that main checkout, which the user switches to its head branch (setup never does): the skill has no worktree option, by decision, since worktrees are very inconvenient in JetBrains IDEs.
- **pr:** the PR number in that repo's GitHub project. Default: the PR of the checkout's current branch.
- **effort:** the `/code-review` level: `low`, `medium`, `high` (default), `xhigh` or `max`. Not `ultra`: that cloud review can only be launched by the user.
- **decision:** `stop`, `important` or absent (default). `procedure.md`, Pass states and stop, says which DECISION or CONFLICT row stops the run after its pass.

## Rules

The rule files are `AGENTS.md`, the files under `docs/ai` and the other files of this skill, all in camaleon-cms. The live files are the files of the checkout, and they change with it. A PR that edits them changes the rules with each fix. During a plugin run, another session or the IDE can switch the camaleon-cms checkout.

Each turn reads the last run header or PASS line of the ledger, `tmp/review-loop/<repo>/<pr>.md` in camaleon-cms (`procedure.md`, Setup): `grep -aE '^(## Run|PASS )' <ledger> | tail -n 1`. Then it does one of these:

- The line is a run header, or a PASS line whose last field is `continue`: the last run is not over. Load the copy of `procedure.md`, at its path under `tmp/review-loop/<repo>/<pr>.rules/`, with the Read tool, and follow it from Pass start.
- Otherwise a new run starts: the line is a PASS line with a STOP, or there is no line. Remove `tmp/review-loop/<repo>/<pr>.rules/` and `tmp/review-loop/<repo>/<pr>.candidates/`, which last as long as the run (the scratchpad does not), and make both again (`mkdir -p`). Then run this in camaleon-cms, which saves the head version of `AGENTS.md`, `docs/ai` and this skill at their paths: `set -o pipefail; git archive HEAD AGENTS.md docs/ai .claude/skills/review-loop | tar -x -C tmp/review-loop/<repo>/<pr>.rules`. A failed `git archive` leaves no file, and with `pipefail` the command exits with its code. When the exit code is not 0, stop and say so in a `PASS 0/8` line (`procedure.md`, PASS line). Otherwise load the copies of `procedure.md` and `setup.md` with the Read tool, and follow `setup.md`, then `procedure.md` from Pass start.

Load the other rule files from the copy, at their paths under `tmp/review-loop/<repo>/<pr>.rules/`, when a step of the procedure first names them. `resume.md`, `ci.md`, `spec-runs.md` and `trace.md` load that way too, at the step that sends the run to them. When a rule file and its copy differ, follow the copy, not the text that the harness loaded. When a copy does not exist, stop and say so in the PASS line. The copies of the run are incomplete.
