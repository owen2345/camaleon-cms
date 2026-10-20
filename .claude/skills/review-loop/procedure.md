# Review loop procedure

The procedure of a run of the review loop. The live `SKILL.md` of the skill gives the parameters and makes the copies of the rule files. A run follows the copy of this file. The files `setup.md`, `resume.md`, `ci.md`, `spec-runs.md` and `trace.md` beside it hold the parts that a pass follows only at the step that names them.

## Setup (first pass of a run)

The first pass of a run follows `setup.md` before this file. Setup resolves the target, reads the PR, makes the ledger ready, appends the run header and reads the ci check of the PR head. Pass 1 then continues at **Pass start**.

## Pass start

Every pass starts with one step, after `SKILL.md` loaded `procedure.md`: it reads the lines of the ledger that the rules below use, with two commands. `<this run>` stands for `tail -n +"$(grep -an '^## Run ' <ledger> | tail -n 1 | cut -d: -f1)" <ledger>`, which prints the lines of this run, from its header on. `LC_ALL=C awk '/^setup / {print; next} /\| (REFUTED|DECISION|CONFLICT) \|/ {m=$0; sub(/ \| [^|]* \| (REFUTED|DECISION|CONFLICT) \| .*$/, "", m); match($0, /\| (REFUTED|DECISION|CONFLICT) \|/); v=substr($0, RSTART+2, RLENGTH-4); e=substr($0, RSTART+RLENGTH); h=""; while (match(e, /judged at [0-9a-f]+/)) { h=substr(e, RSTART+10, RLENGTH-10); e=substr(e, RSTART+RLENGTH) } print m " | " v " | " h}' <ledger>` prints the `setup` lines of every run, and the verdict rows in a compact form. Of each REFUTED, DECISION or CONFLICT row, it prints the pass, the claim, the location, the verdict and the HEAD. `<this run> | LC_ALL=C awk '/^PASS /{p=NR} {l[NR]=$0} END{for(i=1;i<=NR;i++) if (i>p || l[i] ~ /^(## Run|setup |ci |PASS )/) print l[i]; else if (l[i] ~ /\| FIXED \|/) {s=l[i]; sub(/ \| FIXED \| .*$/, "", s); n=split(s, a, " \\| "); print a[1] " | " a[n-1] " | " a[n]}}'` prints the state lines of this run and every line after its last PASS line. Of each FIXED row of this run, it prints the pass, the location and the category.

The output of the first command goes to `tmp/review-loop/<repo>/<pr>.verdicts` (`> <file>`): it can be above the output cap of a Bash command. In **Verdicts** steps 2 and 3, grep that file for each finding. The brief of the review names it (**Pass**). The file also holds the `setup` lines of every run, which step 2 reads there with `grep -an`. The one rerun of `ci.md` reads the `rerun` lines in the ledger itself (`grep -a '^rerun ' <ledger>`): the file lacks a line that this pass appends.

Read a whole FIXED row of this run only when a finding names its location: `<this run> | grep -aF -- '<location>' | grep -a '| FIXED |'`. Read a whole verdict row the same way when a finding matches its claim or its location: `grep -aF -- '<text>' <ledger> | grep -aE '\| (REFUTED|DECISION|CONFLICT) \|'`. Write `'\''` for an apostrophe of the text. `-a` lets `grep` read a ledger with invalid UTF-8, and `-F` reads a backslash of the text as a character. `LC_ALL=C` does the same for `awk`. Do not read the other lines.

The PASS, `setup` and `ci` lines give the pass count and the state of each pass. The rows after its last PASS line, the `review`, `task`, `todo` and `fix` lines among them, are the open work of a cut-off pass. A pass with open work finishes as `resume.md` says, instead of a new pass. In pass 1, the `setup HEAD` line takes the place of the PASS line. The verdicts check the REFUTED, DECISION and CONFLICT rows of the whole ledger, the seed of pass 0 included. Step 5 checks the location of the FIXED rows of this run.

The `setup target` line of this run gives `<checkout>`, `<project>`, `<head>` and `<base-ref>`, which the commands of this file use.

From pass 2 on, and in a resumed pass 1, the pass also runs the checkout test of **Checks**. Each commit past the `<before>` of the pass (**PASS line**) needs a FIXED row (`resume.md`). Other sessions and the IDE share the checkout. Without the checkout test, the pass reviews and commits a switch, an edit or a commit made between passes as the work of the run. The push can also carry such a change, under checks that ran on another tree.

## Pass

Run `/code-review <effort> --fix` on the local branch of the checkout against the base, unpushed commits included. Give it no target for camaleon-cms, and the checkout path for another repo. Its scope is `git -C <checkout> diff <base-ref>...HEAD`, whatever range `/code-review` picks on its own. On its own, it can pick `@{upstream}...HEAD`, which holds only the commits not yet pushed. Never target the PR number: that can review the pushed head, which lacks the commits of this run. When the review cannot cover that whole range, stop and say so.

The brief of the review tells each finder to append each candidate that it keeps to `tmp/review-loop/<repo>/<pr>.candidates/<pass>-<angle>.md` in camaleon-cms. The file ends with a line `done`. A resumed pass reads those files (`resume.md`), and a new run removes the directory (`SKILL.md`). The brief names the verdicts file of **Pass start**, and holds no copy of the rows. A finder greps it for its claim before it keeps a candidate. The brief gives the finders the diff without the added files, `git -C <checkout> diff --diff-filter=a <base-ref>...HEAD`, and the paths of those files (`git -C <checkout> diff --diff-filter=A --name-only <base-ref>...HEAD`), to read in the checkout.

The brief tells the finders not to review the message of a commit: the loop never rewrites a commit (**Ledger rows**). For a changed file, a finder reads the sections that hold its hunks, not the whole file.

The conventions angle of the review reads the live `AGENTS.md` of camaleon-cms from the camaleon-cms checkout, not the copy of the run. The brief tells it so, because the harness loaded its own `AGENTS.md` when the session started. For another repo, the conventions angle of the review holds the code to the `CLAUDE.md` of camaleon-cms (`AGENTS.md`). Plugin, theme and host app checkouts carry no agent docs of their own. A CLAUDE.md governs only the files at or below its directory, so the angle finds none otherwise.

`AGENTS.md` "Support range" says which ground rules do not bind a host app. Apply findings only as the verdicts allow.

## Ledger rows

pass | claim | file + function, spec example or doc section heading (no line numbers and no `|`) | category | verdict | evidence (fix SHA, then `fixes <sha>` for a failure fix, or reason + `judged at <sha>`)

Append the rows other than FIXED when their findings get a verdict. Append them in one command, with one line `todo <claim> | <location> | <category>` per finding with the verdict FIXED, and the line `review`. The `review` line records that the review ran, also when it found nothing. Append a FIXED row joined with `&&` to the commit of its fix, which gives the row its SHA. A SHA in a row has 12 characters (`git rev-parse --short=12 <sha>`). The `setup`, `ci` and `fix` lines keep the full value, which `gh` and the checkout test need.

The message of a commit follows `docs/ai/prose.md`: a subject line and at most three sentences, with no pass number and no ledger label. Write it to a file outside the checkout, which `git commit -F` reads.

The message gate prints each sentence of the message over 25 words, and its sentence count when over three: ``ruby -E UTF-8 -e 'bad = false; ss = File.read(ARGV[0]).scrub.gsub(/(?<!`)(`+)(?!`).+?(?<!`)\1(?!`)/, "X").split(/(?<=[.!?])[*_")\]]*\s+(?=[^a-z])|\n\n+/); ss.each { |s| n = s.split.size; next if n <= 25; bad = true; puts "#{n}: #{s}" }; c = ss.drop(1).count { |s| s.rstrip.sub(/[*_")\]]+\z/, "").end_with?(".", "!", "?") }; if c > 3 then bad = true; puts "#{c} sentences" end; exit(bad ? 1 : 0)' <file>``. When it prints, it exits with 1: reword the message. Join it to the commit with `&&`, before `git commit -F <file>`, so that no commit gets a message that it refused. The gate takes a code span as one word (`docs/ai/prose.md`). A sentence ends at its mark, also before a closing `**`, `"`, `)` or `]`.

The Markdown gate is a `ruby` command that reads a unified diff: ``ruby -E UTF-8 -e 'bad = false; b = []; f = false; chk = lambda { next if b.empty?; t = b.join(" "); b = []; ss = t.split(/(?<=[.!?])[*_")\]]*\s+(?=[^a-z])/); ss.each { |s| n = s.split.size; next if n <= 25; bad = true; puts "#{n} words: #{s[0, 70]}" }; next if ss.size <= 6; bad = true; puts "#{ss.size} sentences: #{t[0, 70]}" }; ARGF.each_line { |l| l = l.scrub; if l !~ /\A\+(?!\+\+)/ then chk.call; f = false; next; end; s = l[1..].chomp.sub(/\A\s*>\s?/, ""); if s =~ /\A\s*(```|~~~)/ then chk.call; f = !f; next; end; next if f; if s.strip.empty? || s =~ /\A\s*(\||#+\s|---)/ then chk.call; next; end; chk.call if s =~ /\A\s*(?:[-*+]|\d+\.)\s/; b << s.sub(/\A\s*(?:[-*+]|\d+\.)\s+/, "").gsub(/(?<!`)(`+)(?!`).+?(?<!`)\1(?!`)/, "X") }; chk.call; exit(bad ? 1 : 0)'``. It prints each added Markdown sentence over 25 words and each paragraph over six sentences. Its input before an append of `fix` lines is `git -C <checkout> add -A && git -C <checkout> diff --cached -U0 -- '*.md'`, so every `fix` line records a tree whose text it read (**Checks**). For a failure fix beside an uncommitted fix, the input is `git -C <checkout> add -A && git -C <checkout> diff --cached -U0 <tree> -- '*.md'`, with the `<tree>` of the batch before the failure fix. The gate of the batch before the failure fix read the uncommitted fix, which the diff from `<tree>` leaves out. The input of the fold is in **Pass states and stop**.

The Markdown gate joins the added lines of a paragraph, so it reads a hard-wrapped paragraph when the diff holds all its lines. It skips a table row, a heading and a fenced block, when the diff holds its opening fence. It counts a code span and a sentence end as the message gate does. Judge its output: the fragments of a changelog entry and a template line are no sentences.

Both gates run `ruby -E UTF-8` and `scrub` their input. Without a locale, Ruby reads a file as US-ASCII and fails on a character such as `→`.

The commit of a failure fix (`docs/ai/workflows.md` Phase 3) also gets a FIXED row, with the check as its category. The category is `ci` for the fix of a failed suite job, and `flake` for a flake fix. A repair of a failure that the uncommitted fix caused (`docs/ai/failures.md`) is part of that fix. The repair gets no row of its own. Because each commit command appends its rows, a pass cut off before its PASS line leaves every commit that it made on record.

The loop never rewrites a commit. A rewrite gives commits new SHAs, which the rows and PASS lines no longer match. A failure that an earlier commit of the branch caused gets a `fixup!` commit (`docs/ai/workflows.md` Phase 3). The user folds the fixup commits with `GIT_SEQUENCE_EDITOR=true git rebase -i --autosquash <sha>~1` (`docs/ai/workflows.md` Phase 3), where `<sha>` is the oldest commit that they fix. The report names the fixup commits and `<sha>`.

## Verdicts

Check the steps in order. A finding that is also a correctness or security defect skips steps 5 and 6 and goes to step 7, whatever its category. The pass applies only FIXED and leaves no finding without a verdict. Commit the fixes as `docs/ai/workflows.md` Phase 3 says.

1. Check every finding against the code yourself, whether or not the review verified it. Refuted → REFUTED. PLAUSIBLE, only when that check can neither confirm nor refute it → DEFERRED. Low severity or a loud failure is no reason to defer a confirmed defect.
2. Same claim as a DECISION or REFUTED row, on code that the row's HEAD also has → REPEAT if DECISION, CONFLICT if REFUTED. A REPEAT row names the new evidence of the finding, if any, for the user. The row's HEAD is the `<sha>` after the last `judged at` in its evidence, or the `setup HEAD` of its run when it names none. That is the run header after a pass 0 seed, and the header before any other row. If that code changed, treat the claim as new. A sentence that a commit of the run added, reworded, split or moved, and that keeps the decided meaning, counts as the same code.

   Also treat it as new when the repository no longer has that HEAD: `git -C <checkout> rev-parse -q --verify '<sha>^{commit}'` exits with 1. A rewrite leaves the old HEAD off the branch, but the repository keeps it.
3. A fix that goes against a DECISION row on the same code, as step 2 defines it, gives CONFLICT. Otherwise a fix that re-adds what the PR removed on purpose is the user's call (step 4). The saved description and the `design.md` of each OpenSpec change of the branch record that (`setup.md`). Any other fix that undoes a commit already on this branch (`<base-ref>..HEAD`) gives CONFLICT.
4. Needs a design trade-off or the user's call → DECISION. The `decision` parameter says whether the row stops the run after this pass (see **Pass states and stop**).
5. Reuse, simplification or efficiency (the cleanups), conventions (code that breaks a `CLAUDE.md` or `AGENTS.md` rule) or coverage-only → FIXED. A fix needs a spec as `AGENTS.md` "Specs" says, and a conventions fix can change behavior. A coverage-only fix is the new spec.

   Once step 5 is frozen (see below), the findings of step 5 are DEFERRED instead. A cleanup is also DEFERRED when a cleanup of an earlier pass of this run reshaped that function, spec example or doc section.
6. Altitude or wording → FIXED in pass 1, DEFERRED after. Wording is text that still gives the right outcome when a reader follows it literally. Text that gives a wrong outcome is a defect.
7. A correctness or security defect → FIXED, with the spec that reproduces it. `AGENTS.md` "Specs" and `docs/ai/workflows.md` Phase 3 give the exceptions. The row, and the `todo` line before it, have the category correctness or security, whatever category the review gave the finding.

## Checks

The checks are the four in camaleon-cms `AGENTS.md` "Verify before pushing", in the form of the table for each kind of checkout. When `AGENTS.md` "Verify before pushing" exempts the branch or the commit from a check, that check is n/a too.

| | camaleon-cms | plugin or theme | host app (PostgreSQL) |
|---|---|---|---|
| suite workflows | `Audit`, `Test supported versions` | `CI` | `test-on-push` |
| brakeman | as `AGENTS.md` | n/a | as `AGENTS.md` |
| zeitwerk:check | as `AGENTS.md` | the same | `bin/rails zeitwerk:check` |
| spec database | the SQLite file of the spec clone | the same | its own test database, shared with every checkout of the app |
| spec runs | the spec clone | the same | the checkout, under the other-run wait |

The loop runs the checks before each commit, the lint first, as `docs/ai/workflows.md` Phase 3 says. The PASS line reports the last run of each check in the pass, or n/a when the pass did not run it.

Every spec run, every ci poll and any other command that can outlast the timeout is a background task (`docs/ai/testing.md` "Long commands"). When the tool answers, append `task <id> <log> <command>` to the ledger.

The checkout test holds when the checkout is as the pass left it:

- `git -C <checkout> branch --show-current` prints the head branch.
- `git -C <checkout> rev-parse HEAD` starts with the fix SHA of the last FIXED row of the pass, or with `<before>` (**PASS line**) when the pass has none. The fix SHA is the first word of the evidence field (**Ledger rows**).
- The tree is the run's own when a `fix` line of the pass is open. Then `(export GIT_INDEX_FILE=<tmp>; git -C <checkout> read-tree HEAD && git -C <checkout> add -A && git -C <checkout> write-tree)` prints the `<tree>` of the last `fix` line. `<tmp>` is an absolute path outside the checkout, and the index of the checkout stays as it is. Otherwise the tree is clean: `git -C <checkout> status --porcelain` prints nothing.

The test runs before the first edit of the pass and before the first edit after each commit. It runs before each commit, the fixup chain included. It runs at the end of the pass too, unless a stop left the uncommitted fix in the tree (`spec-runs.md`). When it fails, another writer changed the checkout: stop the run and report the output.

After that stop, do not switch, pull, reset, stash or commit. When the commits of the branch changed, also tell the user to start a new run. A rebase onto the base changes the commits of the branch. The user must push the branch before that run, because setup stops on a checkout that is not at `origin/<head>`. A rewrite of pushed commits needs the lease of `docs/ai/workflows.md` Phase 3.

After each lint run, before the other checks, append one line `fix <tree> | <claim> | <location> | <category>` per FIXED row of every uncommitted fix. The Markdown gate runs before each append of `fix` lines (**Ledger rows**). A fix that runs no lint gets the lines at once, and again after a repair. The claim, the location and the category of the row follow `<tree>`, for the resume of a cut-off pass (`resume.md`). `<tree>` comes from `git -C <checkout> add -A && git -C <checkout> write-tree`: the tree of the checkout with the uncommitted fix. The `add` stages the fix, which its commit needs.

The `fix` lines appended together, with one `<tree>`, are a batch. A `fix` line is open until a row with its claim and location follows it. That row is its FIXED row, or the row of the verdict that replaced FIXED after the edit, with the files restored. A batch is open while one of its lines is open, and the open lines are the open lines of the last batch.

Append the `fix` lines also before a failure fix: the trees before and after it hold its hunks (`resume.md`). Append the lines of a batch in one command.

Before the commit, the checkout test (above) must hold, or the run stops.

Judge the command by its result, as `docs/ai/testing.md` "Long commands" says. With no result, start the command again once. A second spec run that ends with the same summary line and exit code is a failure: `docs/ai/failures.md` traces it. A hang, or any other second start with no result, stops the run: report the command with its log. A sync or a `gh` command that fails has no result too, and the report gives its output in place of a log. A `gh run rerun` that GitHub refuses, with `cannot be rerun` or an HTTP 4xx error in its output, has a result: the refusal (`ci.md`).

The fifth check is **ci**, the GitHub workflow runs of a commit: `ci.md` says how to read them and when to rerun one. Setup reads them for the `setup HEAD`, and a stop that pushes reads them again for the pushed commit (see **Pass states and stop**).

The spec runs, the failed checks and the fixup commit of a failure fix follow `spec-runs.md`. It holds the spec clone and its sync, the openspec commands, the trace of a failed check and the host-app wait.

## Pass states and stop

- **SETTLED:** the pass ran to the end and applied no correctness or security fix. Every check passed or was n/a, and the checkout's tree is clean. The ci read of a push comes after the state (below), and the goal text judges that ci. A correctness fix is a FIXED row whose category is correctness, security, flake or a check name. Step 5 and step 6 fixes can go in.
- **CLEAN:** SETTLED, and applied nothing at all (`<after>` equals `<before>`).
- **UNSETTLED:** anything else.

Step 5 freezes after the first SETTLED pass of the run, and in pass 8: from then on, its findings are DEFERRED. A converged run therefore ends on a pass that applied nothing, and a later pass reviewed every change that the run made.

Stop and push in these cases:

- The latest pass is CLEAN and the run's pass before it SETTLED or CLEAN (converged).
- Pass 8 did not converge. Report it as not converged.
- A second CONFLICT on the same claim. Show both sides.
- A review cannot cover its range.
- A DECISION row in this pass that the `decision` parameter names. The pass applies its other verdicts and commits first. The user answers the rows before the next run, and each answer goes in as a commit, pushed before that run. The values:
  - `stop`: any DECISION row.
  - `important`: a decision on the design of the PR, or on a rule that the later fixes follow. A decision on one sentence, a term or a bound does not count.
  - absent (default): no DECISION row stops the run, and the rows wait for the STOP.
- A CONFLICT row in this pass whose finding is a correctness or security defect, when `decision` is `stop` or `important`. Such a row says that a REFUTED row or a decision was wrong, and every later pass builds on the text that it keeps. The stop pushes, and the user answers the row before the next run, as a DECISION row.

When a DECISION stop holds with another stop, the pass reports the DECISION stop. When a CONFLICT stop holds with another stop that is no DECISION stop, the pass reports the CONFLICT stop.

The stops of the list below push nothing, also when a reason to push applies. A stop that neither list names pushes nothing too. Each of these stops is defined where it happens:

- A setup stop, also on a ci read of setup with `no jobs`, `pending` or `cancelled` (`setup.md`).
- A checkout that changed between passes (**Pass start**) or during one (**Checks**), or a pass that ends with uncommitted changes, which can be another writer's.
- A second CONFLICT on a fix that undoes an earlier commit of the branch (**Verdicts** step 3).
- A `fixup!` commit (`spec-runs.md`).
- A failure whose cause the trace does not find, or that was there before the branch (`spec-runs.md`).
- A CI failure that the spec clone does not show and that a rerun shows again (`trace.md`).
- A hang, or a command with no result twice (**Checks**).
- The wait of a host app that ends after its hour (`spec-runs.md`).

`AGENTS.md` wants the checks before a push, and the user judges an undo, another writer's change or a fold. A stop without a push leaves the commits of the run for the user to push before the next run (`setup.md`).

Commit but do not push during the run. The STOP push carries every commit of the run. Decide the skip marker for the whole push: GitHub reads it off the last commit alone (`docs/ai/workflows.md` Phase 3). A marked docs-only last commit also skips CI for the code commits of the run. The checks ran before each commit of the run, so the push needs no other check run (`AGENTS.md` "Verify before pushing").

A stop that pushes has these steps, in this order:

1. Fetch `origin/<head>`, and read the `state` of the PR again. A merged or closed PR stays unpushed and unfolded: say so, and skip the other steps.
2. When `origin/<head>` holds HEAD (`git -C <checkout> merge-base --is-ancestor HEAD origin/<head>` exits with 0), skip the push and compare HEAD with the `setup HEAD`:
   - HEAD is the `setup HEAD`: the run made no commit. Skip the other steps.
   - HEAD is past the `setup HEAD`: a pass cut off after its push made the commits. Continue with step 4.
3. Push with `git -C <checkout> push origin <head>`, and once more when it fails without a rejection. When git rejects the push, or the second push fails, the stop stays unpushed and unfolded. Say so, and skip the other steps. Do not pull, rebase or force past a rejection. After a pull or a rebase, the push carries a tree that the checks never ran on. A forced push drops the other commits.
4. Start the ci read of HEAD (`ci.md`). A poll, when `ci.md` starts one, runs as a background task, and the fold runs meanwhile.
5. Fold the PR description (`docs/ai/workflows.md` Phase 4). Save the live description with `gh pr view <pr> --repo <project> --json body --template '{{.body}}' > tmp/review-loop/<repo>/<pr>.live.md`, and copy it to `tmp/review-loop/<repo>/<pr>.fold.md`. Fold the run into `tmp/review-loop/<repo>/<pr>.fold.md`. Run the Markdown gate (**Ledger rows**) with the input `diff -U0 --strip-trailing-cr tmp/review-loop/<repo>/<pr>.live.md tmp/review-loop/<repo>/<pr>.fold.md`: a description edited on GitHub can have CRLF line ends. Then run `gh pr edit <pr> --repo <project> --body-file tmp/review-loop/<repo>/<pr>.fold.md`.
6. End the ci read: wait for the poll, if any (`docs/ai/testing.md` "Long commands"), and read its result as `ci.md` says. The run is over, so the loop does not trace a failure there. It reruns once each run in which a suite job did not pass, as `ci.md` says. A job that fails again is the failed job that ci reports. After a DECISION or CONFLICT stop, it reads ci and reruns nothing.

A STOP that pushed does not meet the goal when its ci is neither ok nor n/a (see the goal text). A DECISION or CONFLICT stop meets the goal whatever its ci: the user answers the rows first.

The next turn sets up a new run. After a DECISION or CONFLICT stop, the turn after the answers sets it up. The setup of that run traces a failed suite job of the head, or stops as `setup.md` says.

On every STOP, add the new REFUTED, DECISION and CONFLICT rows to the PR's memory entry, if it has one. A STOP that pushed does this after its ci read. Report the DEFERRED, DECISION, REPEAT and CONFLICT rows of the run: `<this run> | grep -aE '\| (DEFERRED|DECISION|REPEAT|CONFLICT) \|'` (**Pass start**).

## PASS line

The goal's evaluator reads only the transcript, so end every turn with the line below. Append it to the ledger too: the next pass reads the pass count and the state of each pass there. The reason of a stop starts with `converged`, `DECISION row` or `CONFLICT row`, by its kind, and a convergence reason names no DECISION or CONFLICT row. The `fixed` field counts the FIXED rows of the pass by category (**Pass states and stop**). The goal reads the STOP field: `pushed` when the run made a commit and `origin/<head>` holds HEAD after the stop, and `not pushed` otherwise. A STOP for convergence quotes the PASS line of the previous pass from the ledger, because compaction can drop that turn from the transcript.

```text
PASS <n>/8 <repo> PR <pr> | HEAD <before> → <after> | git status: <clean, or the dirty paths> | rspec: <summary line> | checks: <ok, n/a, no jobs, pending, cancelled or what failed, per check> | fixed: <x> correctness/security, <y> other | step 5: <on or frozen> | deferred <b>, repeat <c>, decision <d>, conflict <e> | <CLEAN, SETTLED or UNSETTLED> | <continue, or STOP: reason, pushed or not pushed>
```

`<before>` is the `<after>` of the previous PASS line, or the `setup HEAD` in pass 1. `<after>` is the HEAD of the checkout at the end of the pass.
