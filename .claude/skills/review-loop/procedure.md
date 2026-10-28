# Review loop procedure

The procedure of a run. `SKILL.md` gives the parameters and makes the copies of the rule files, and a run follows the copies.

## Pass start

Every pass starts with two reads of the ledger. `<this run>` is `tail -n +"$(grep -an '^## Run ' <ledger> | tail -n 1 | cut -d: -f1)" <ledger>`: the lines of this run, from its header on.

The first read is `LC_ALL=C awk -v V='REFUTED|DECISION|CONFLICT' '/^setup HEAD / {cur=$3; for (i=1;i<=nb;i++) print b[i] " | " cur; nb=0; next} $0 ~ "\\| (" V ") \\|" {m=$0; sub(" \\| [^|]* \\| (" V ") \\| .*$", "", m); match($0, "\\| (" V ") \\|"); v=substr($0, RSTART+2, RLENGTH-4); e=substr($0, RSTART+RLENGTH); h=""; while (match(e, /judged at [0-9a-f]+/)) { h=substr(e, RSTART+10, RLENGTH-10); e=substr(e, RSTART+RLENGTH) } if (h == "") h=cur; if (h == "") b[++nb]=m " | " v; else print m " | " v " | " h}' <ledger>`, redirected (`>`) to `tmp/review-loop/<repo>/<pr>.verdicts`, which **Verdicts** steps 1 to 3 and the finders grep. It prints the REFUTED, DECISION and CONFLICT rows of the whole ledger in a compact form that ends with the HEAD of the row. That HEAD is the `<sha>` after the last `judged at` in its evidence, else the `setup HEAD` of its run (the first run's for pass 0). The same awk with `-v V=DEFERRED`, with `<this run>` piped in and no `<ledger>` operand, appends (`>>`) the DEFERRED rows of this run.

The second read, `<this run> | LC_ALL=C awk '/^PASS /{p=NR} {l[NR]=$0} END{for(i=1;i<=NR;i++) if (l[i] ~ /^PASS /) {n=split(l[i], a, " \\| "); print a[1] " | " a[2] " | " a[n-1]} else if (i>p || l[i] ~ /^(## Run|setup |ci )/) print l[i]; else if (l[i] ~ /\| FIXED \|/) {s=l[i]; sub(/ \| FIXED \| .*$/, "", s); n=split(s, a, " \\| "); print a[1] " | " a[n-1] " | " a[n]}}'`, prints the state lines of this run and every line after its last PASS line. A PASS line prints as the pass, the HEAD pair and the state, a FIXED row as the pass, the location and the category. Read a whole row (`grep -aF -- '<text>' <ledger>`, with `'\''` for an apostrophe) only when a finding names its location or claim.

The `setup HEAD` line of this run gives `<checkout>`, `<project>`, `<head>`, `<base-ref>` and `<polished>`. A command on the branch runs against the checkout: `git -C <checkout> …`, `(cd <checkout> && bin/…)`, `gh … --repo <project>`. The ledger commands run in camaleon-cms, and a spec run in the spec clone (`spec-runs.md`).

A cut-off pass is a pass that an earlier turn left without its PASS line. In pass 1, the `setup HEAD` line takes its place, and the turn of its setup starts pass 1. Its open work is the lines after that line and a candidate file of this pass in `tmp/review-loop/<repo>/<pr>.candidates/`. It finishes as `resume.md` says.

Every pass runs the checkout test (**Checks**) first.

## Pass

Run `/code-review <effort> --fix --max-findings all` on the checkout: no target for camaleon-cms, the checkout path for another repo. Its scope is `git -C <checkout> diff <scope start>...HEAD`, whatever range `/code-review` picks on its own. `<scope start>` is `<base-ref>` in passes 1 and 2, and the `<before>` of the previous PASS line from pass 3 on. A pass with an empty scope is CLEAN with no review.

`@{upstream}...HEAD` lacks the pushed commits, and the PR number lacks the commits of this run. Without `all`, a stored cap bounds every pass. When the review cannot cover that range, stop and say so. Apply findings only as the verdicts allow.

A pass that applied a rework fix (**Pass states and stop**) runs the review once more before its PASS line, when each condition below holds:

- The previous pass is SETTLED, CLEAN or REWORK.
- Each correctness fix of this pass is rework.
- No DECISION or CONFLICT row of this pass stops the run.

The `<scope start>` of that review is `<before>`: its scope is the commits of this pass. Its candidate and verifier files take `<pass>r` in place of `<pass>`. Before it, both commands of the first read of **Pass start** run again, so the verdicts file holds the rows of this pass.

A correctness fix of that review is no rework, whatever sentence it fixes, and the pass is UNSETTLED. That review runs also in a resumed pass (`resume.md`), when no `review` line follows the FIXED rows of the rework fixes.

Before the review, save the diff without the added files: `git -C <checkout> diff --diff-filter=a <scope start>...HEAD > tmp/review-loop/<repo>/<pr>.diff`. The diff keeps the old text of a rewritten file: the removed-behavior angle reads it. The brief of the review:

- gives the finders that path, for the Read tool, and the paths of the added files (`git -C <checkout> diff --diff-filter=A --name-only <scope start>...HEAD`). A finder reads those files, and the sections of a changed file that hold its hunks, in the checkout.
- names the verdicts file of **Pass start**, with no copy of its rows. A finder greps it before it keeps a candidate: `grep -aiF -- '<claim word>' <verdicts file> | grep -aiF -- '<claim word>' | tail -n 30`, with `'\''` for an apostrophe, and a hit with the same claim is a match. A match on a REFUTED, DECISION or CONFLICT row drops the candidate when the HEAD of the row still has that code (**Verdicts** step 2). The test is `git -C <checkout> show <HEAD>:<path> | grep -cF -- '<fragment of the quote>'`, with the repository path of the row's file as `<path>`, on the newest such row: a count above 0 drops. A match whose candidate names evidence that the claim of the row does not keeps the candidate, and the finder quotes the row. Any other match keeps it, for **Verdicts** steps 1 and 2.
- tells each finder to append its candidates to `tmp/review-loop/<repo>/<pr>.candidates/<pass>-<angle>.md` in camaleon-cms, and to end the file with a line `done`. The brief and the prompt of a finder name no candidate file of an earlier pass, and no ledger.
- tells the finders not to review the message of a commit: the loop never rewrites a commit.
- tells the finders and the verifiers to leave the checkout as it is, apart from their candidate and verifier files. A probe runs in the scratchpad or on a scratch copy there, and starts no spec run.
- asks for two independent verifiers of a correctness finding on a Markdown file: CONFIRMED needs both, and one vote keeps it PLAUSIBLE. A correctness finding is one whose claim is a correctness defect (**Verdicts** step 5), whatever category the review gave it. A finding on any other file keeps the one vote of `/code-review`. Each verifier appends its votes to `tmp/review-loop/<repo>/<pr>.candidates/<pass>-verify-<n>.md`, which a resumed pass reads.
- tells the conventions angle to read the live `AGENTS.md` of camaleon-cms, not the copy, for every repo. A plugin, theme or host app checkout has no agent docs, and `AGENTS.md` "Support range" says which ground rules do not bind a host app.

## Ledger rows

pass | claim | file + function, spec example or doc section heading (no line numbers and no `|`) | category | verdict | evidence (fix SHA, then `fixes <sha>` for a failure fix of an earlier commit or `rework` for a rework fix, or reason + `judged at <sha>`)

Append the rows other than FIXED when their findings get a verdict, in one command. That command also appends the line `review` and one line `todo <claim> | <location> | <category>` per finding with the verdict FIXED. The `review` line records that the review ran, also with no finding. Append a FIXED row joined with `&&` to the commit of its fix, which gives the row its SHA. A SHA in a row has 12 characters (`git -C <checkout> rev-parse --short=12 <sha>`), and the `setup`, `ci` and `fix` lines keep the full value.

The message of a commit follows `docs/ai/prose.md`: a subject line and at most three sentences, with no pass number and no ledger label. `docs/ai/workflows.md` Phase 3 decides its skip marker, for the one push of the run at the STOP. Write it to a file outside the checkout, with an absolute path, for `git -C <checkout> commit -F <file>`. The message gate, ``ruby -E UTF-8 -e 'bad = false; ss = File.read(ARGV[0]).scrub.gsub(/(?<!`)(`+)(?!`).+?(?<!`)\1(?!`)/, "X").split(/(?<=[.!?])[*_")\]]*\s+(?=[^a-z\s])|\n\n+/); ss.each { |s| n = s.split.size; next if n <= 25; bad = true; puts "#{n}: #{s}" }; c = ss.drop(1).count { |s| s.rstrip.sub(/[*_")\]]+\z/, "").end_with?(".", "!", "?") }; if c > 3 then bad = true; puts "#{c} sentences" end; exit(bad ? 1 : 0)' <file>``, prints each sentence over 25 words and the sentence count when over three, and exits with 1. Reword the message when the gate prints a line. Join the gate with `&&` to `git -C <checkout> commit -F <file>`.

The Markdown gate of `docs/ai/prose.md` reads the staged diff, `git -C <checkout> add -A && git -C <checkout> diff --cached -U0 -- '*.md'`, before each append of `fix` lines, and the diff of the fold (`stop.md`). Judge its output as that document says.

A failure fix (`docs/ai/workflows.md` Phase 3) also gets a FIXED row, with the check as its category. The category is `ci` for a failed suite job and `flake` for a flake. A repair of a failure that the uncommitted fix caused is part of that fix, with no row. The loop never rewrites a commit: a rewrite gives commits new SHAs, which the rows no longer match. A failure that an earlier commit of the branch caused gets a fixup commit (Phase 3). The user folds the fixup commits with `GIT_SEQUENCE_EDITOR=true git rebase -i --autosquash <sha>~1`, where `<sha>` is the oldest fixed commit, and the report names the fixup commits and `<sha>`.

## Verdicts

Check the steps in order. The pass applies only FIXED and leaves no finding without a verdict.

1. Check every finding against the code yourself, whether or not the review verified it. Refuted → REFUTED. PLAUSIBLE, only when that check can neither confirm nor refute it → DEFERRED, with evidence that starts with `PLAUSIBLE`. A correctness finding on a Markdown file with one vote (**Pass**) stays PLAUSIBLE: this check can refute it, not confirm it. A finding with the claim and the location of a DEFERRED row of this run is DEFERRED again without this check. That holds unless the row's evidence starts with `PLAUSIBLE` or its code changed (step 2).
2. Same claim as a DECISION or REFUTED row, on code that the row's HEAD also has → REPEAT if DECISION, CONFLICT if REFUTED. A REPEAT row names the new evidence of the finding, if any. The row's HEAD is the last field of its line in the verdicts file. When that code changed, or the repository no longer has that HEAD (`git -C <checkout> rev-parse -q --verify '<sha>^{commit}'` exits with 1), the claim is new. A sentence that a commit of the run added, reworded, split or moved, and that keeps the decided meaning, is the same code.
3. A fix that contradicts a DECISION row on the same code, as step 2 defines it, gives CONFLICT. A fix that re-adds what the PR removed on purpose gives DECISION (step 4). The saved description, `tmp/review-loop/<repo>/<pr>.description.md`, and the `design.md` of each OpenSpec change of the branch record what the PR removed on purpose. The changes are the directories `openspec/changes/<name>/` and `openspec/changes/archive/<date>-<name>/` of the paths that `git -C <checkout> diff --name-only <base-ref>...HEAD -- openspec/changes/` lists, and the pass reads each `design.md` that HEAD has. Any other fix that undoes a commit of this branch (`<base-ref>..HEAD`) gives CONFLICT. A CONFLICT row has the category that step 5 gives its finding.
4. Needs a design trade-off or the user's call → DECISION, also a fix of `SKILL.md` Rules, which every turn follows live. The `decision` parameter says whether the row stops the run after this pass (**Pass states and stop**).
5. A correctness or security defect → FIXED, with the spec that reproduces it (`AGENTS.md` "Specs" and Phase 3 give the exceptions). In a Markdown file, a correctness defect is two rules that give different actions in one concrete flow, and the row names that flow. A command and the sentence that describes it are two such rules. A sentence that a probe, a run of its command or tool with throwaway input, shows false is a defect too. In another file, text that gives a wrong outcome when followed literally is a defect. The row, and its `todo` line, have the category correctness or security, whatever category the review gave the finding.
6. A cleanup (reuse, simplification or efficiency), conventions (a `CLAUDE.md` or `AGENTS.md` rule broken), coverage-only, altitude or wording → FIXED, or DEFERRED once frozen. **Pass states and stop** gives the freeze. A fix needs a spec as `AGENTS.md` "Specs" says, a coverage-only fix is the new spec, and a conventions fix can change behavior. A cleanup is also DEFERRED when a cleanup of an earlier pass of this run reshaped that function, spec example or doc section. In a Markdown file, an ambiguity, a dangling pointer, a missing case or an imprecise term is wording.

## Checks

The checks are the four of camaleon-cms `AGENTS.md` "Verify before pushing", in the form of the table for each kind of checkout. A check from which `AGENTS.md` exempts the branch or the commit is n/a too.

| | camaleon-cms | plugin or theme | host app (PostgreSQL) |
|---|---|---|---|
| suite workflows | `Audit`, `Test supported versions` | `CI` | `test-on-push` |
| brakeman | as `AGENTS.md` | n/a | as `AGENTS.md` |
| zeitwerk:check | as `AGENTS.md` | the same | `bin/rails zeitwerk:check` |

The loop runs the checks before each commit, the lint first, as `docs/ai/workflows.md` Phase 3 says. The PASS line reports the last run of each check in the pass, or n/a. Every spec run, every ci poll and any other command that can outlast the timeout is a background task (`docs/ai/testing.md` "Long commands"). When the tool returns the id and the log, append `task <id> <log> <command>` to the ledger.

The checkout test holds when the checkout is as the pass left it:

- `git -C <checkout> branch --show-current` prints the head branch.
- `git -C <checkout> rev-parse HEAD` starts with the fix SHA of the last FIXED row of the pass, or with `<before>` (**PASS line**) when the pass has none.
- While a `fix` line of the pass is open, `(export GIT_INDEX_FILE=<tmp>; git -C <checkout> read-tree HEAD && git -C <checkout> add -A && git -C <checkout> write-tree)` prints the `<tree>` of the last `fix` line (`<tmp>`: an absolute path outside the checkout). Otherwise `git -C <checkout> status --porcelain` prints nothing.

The test runs before the first edit of the pass, before each commit and before the first edit after it. It runs at the end of the pass too, unless a stop left the uncommitted fix in the tree. When it fails, another writer changed the checkout: stop the run and report the output. When the commits of the branch changed, tell the user to push the branch (Phase 3) before the next run.

After each lint run, before the other checks, append one line `fix <tree> | <claim> | <location> | <category>` per FIXED row that the uncommitted fix gets. The Markdown gate runs before the append (**Ledger rows**). A fix that runs no lint gets the lines after each change of the tree. `<tree>` comes from `git -C <checkout> add -A && git -C <checkout> write-tree`. The lines of one `<tree>`, appended in one command, are a batch. Append a batch also before a failure fix: the trees before and after it hold its hunks (`resume.md`).

A `fix` line is open until a row with its claim and location follows it. That row is its FIXED row, or the row of the verdict that replaced FIXED after the edit, with the fix undone. A batch is open while one of its lines is open, and the open lines are the open lines of the last batch. The pass undoes a dropped fix first, stages the undo with `git -C <checkout> add -A`, and appends the row of the fix. The checks of the other fixes then run again. Before the commit, the checkout test (above) must hold, or the run stops.

Judge a command by its result (`docs/ai/testing.md` "Long commands"), and with no result start it again once. A hang, or any other second start with no result, stops the run: report the command with its log. A sync or a `gh` command that fails has no result too, and the report gives its output. A `gh run rerun` that GitHub refuses, with `cannot be rerun` or an HTTP 4xx error, has a result: the refusal (`ci.md`). A gone log has a result too (`trace.md`).

The fifth check, **ci**, follows `ci.md`: setup reads it for the `setup HEAD`, and a stop that pushes for the pushed commit (`stop.md`). The spec runs, the failed checks and the fixup commit follow `spec-runs.md`.

## Pass states and stop

- **SETTLED:** the pass ran to the end and applied no correctness fix: a FIXED row whose category is correctness, security, flake or a check name. Every check passed or was n/a, and the tree of the checkout is clean. The ci read of a push (`stop.md`) comes after the state and does not change it.
- **CLEAN:** SETTLED, and applied nothing at all (`<after>` equals `<before>`).
- **REWORK:** as SETTLED, except that the pass applied correctness fixes, each of them rework. A correctness fix is rework when a commit of the previous pass added or changed the sentence that it fixes. That sentence is then on an added line of `git -C <checkout> diff <before> <after>`, with the HEAD pair of the previous PASS line. The evidence of its FIXED row ends with `rework`. Pass 1 has no previous pass in this run, so none of its fixes is rework.
- **UNSETTLED:** anything else.

Step 6 freezes after pass 1 when it is SETTLED, and after pass 2 whatever its state. From then on, step 6 gives DEFERRED: a pass applies only correctness and security fixes, failure fixes among them. A `<polished>` of `none` freezes nothing. Otherwise `<polished>` freezes from pass 1 each sentence that `git -C <checkout> diff --word-diff <polished> HEAD` shows with no `[-`, `-]`, `{+` or `+}` mark in it. Step 6 gives DEFERRED to a finding on such a sentence, with evidence that starts with `polished`.

Stop and push in these cases:

- The latest pass is CLEAN or REWORK and the run's pass before it SETTLED, CLEAN or REWORK (converged). The reason of a REWORK pass is `converged on rework`: the run fixed only its own text.
- Pass 8 did not converge. Report it as not converged.
- A second CONFLICT on the same claim. Show both sides.
- A review cannot cover its range.
- A DECISION row in this pass that the `decision` parameter names. The pass applies its other verdicts and commits first. The user answers the rows before the next run, each answer a commit pushed before that run. The values:
  - `stop`: any DECISION row.
  - `important`: a decision on the design of the PR, or on a rule that the later fixes follow. A decision on a sentence, a term or a bound does not count, also when the later fixes follow it. The evidence of a row that counts starts with `important`.
  - absent (default): none, and the rows wait for the STOP.
- A CONFLICT row in this pass whose finding is a correctness or security defect, when `decision` is `stop` or `important`. The finding contradicts a REFUTED row, a DECISION row or a commit of the branch. The user answers the row before the next run, as a DECISION row.

When more than one stop holds, the pass reports the first of these: the DECISION stop, a stop on a CONFLICT row, any other stop. A stop outside the list above pushes nothing, also when a reason to push applies. No stop pushes while the run has a fixup commit: the user folds it first (Phase 3). The user pushes the commits of the run before the next run. The file where each happens defines it:

- A setup stop, also on a ci read of setup with `no jobs`, `pending` or `cancelled` (`setup.md`).
- A checkout that changed between passes or during one, or a pass that ends with uncommitted changes (**Checks**).
- A fixup commit, or a host-app wait that ends after its hour (`spec-runs.md`).
- A failure whose cause `docs/ai/failures.md` does not find, or that was there before the branch (`spec-runs.md`).
- A CI failure that the spec clone does not show and that a rerun shows again or replaces with another failure (`trace.md`).
- A hang, or a command with no result twice (**Checks**).
- A resume whose open lines do not tell the hunks of a fixup commit apart, or whose fixup command fails (`resume.md`).
- A merge conflict in the trace, or a merge that caused the failure (`trace.md`).
- A failed suite job of a host app, or a host-app spec run that fails again (`trace.md`, `spec-runs.md`).

Commit but do not push during the run. A stop that pushes follows `stop.md`. After a stop, the pass switches, pulls, resets, stashes and commits nothing. The next turn sets up a new run, after the answers of a DECISION or CONFLICT stop.

Every STOP adds the new REFUTED, DECISION and CONFLICT rows to the PR's memory entry, if any, after the ci read when it pushed. Report the DEFERRED, DECISION, REPEAT and CONFLICT rows of the run (`<this run> | grep -aE '\| (DEFERRED|DECISION|REPEAT|CONFLICT) \|'`) and the advisory notes of its `ci` lines. A stop before the run header, in a `PASS 0/8` line, has no rows to add or to report. The report also names the stored `--max-findings all`, which `--max-findings default` resets, and each trace step that ran with the Ruby of the clone (`docs/ai/failures.md`).

## PASS line

End every turn with the line below, and append it to the ledger. The reason of a convergence, DECISION or CONFLICT stop starts with `converged`, `DECISION row` or `CONFLICT row`, and a convergence reason names no DECISION or CONFLICT row. The STOP field ends with `pushed` when the run made a commit and `origin/<head>` holds HEAD after the stop, else `not pushed`. A STOP for convergence quotes the previous PASS line (`grep -a '^PASS ' <ledger> | tail -n 1`, run before the append) just above its own.

```text
PASS <n>/8 <repo> PR <pr> | HEAD <before> → <after> | git status: <clean, or the dirty paths> | rspec: <summary line> | checks: <ok, n/a, no jobs, pending, cancelled or what failed, per check> | fixed: <x> correctness/security, <y> other | step 6: <on or frozen> | deferred <b>, repeat <c>, decision <d>, conflict <e> | <CLEAN, SETTLED, REWORK or UNSETTLED> | <continue, or STOP: reason, pushed or not pushed>
```

`<before>` is the `<after>` of the previous PASS line, or the `setup HEAD` in pass 1. `<after>` is the HEAD of the checkout at the end of the pass. The first count of the `fixed` field is the correctness fixes of **SETTLED**, and the second the other FIXED rows of the pass. The other four counts are the rows of the pass with those verdicts. The `step 6` field is the state of step 6 during the pass, and the `polished` freeze shows in the rows, not in this field. A `PASS 0/8` line has the HEAD of the checkout as `<before>` and `<after>`, or `none` when the stop comes before setup resolves the checkout.
