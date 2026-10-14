# Review loop procedure

The procedure of a run of the review loop. The live `SKILL.md` of the skill gives the parameters and makes the copies of the rule files. A run follows the copy of this file.

## Setup (first pass of a run)

- **Target:** resolve the checkout path as its real path (`git -C ../<repo> rev-parse --show-toplevel`) and its GitHub project (`gh repo view --json nameWithOwner --jq .nameWithOwner`, run in the checkout). In a fork checkout, as below, give that command the URL of `<remote>`. `gh` answers with `origin`, the fork, unless that remote is named `upstream` or `github`.
- **PR:** `gh pr view <pr> --repo <project> --json state,headRefName,baseRefName,headRefOid,headRepositoryOwner,headRepository,body` gives its state, its head and base branches, its head commit, its head repository and its body, the record of its design. Stop in a `PASS 0/8` line unless `<head>` and `<base>` match `^[A-Za-z0-9_][A-Za-z0-9._/-]*$`: the commands below use both names without quotes. Then fetch both branches: `git -C <checkout> fetch origin <head> <base>`. In a fork checkout, only `<head>` comes from `origin`.

  The run goes on only when each condition below holds. Otherwise stop and say so in a `PASS 0/8` line. Do not switch, pull, stash or commit.
  - The PR is open.
  - The head of the PR is in the repository of `origin`. The `headRepositoryOwner` login and the `headRepository` name, as `<owner>/<name>`, equal that repository: `<project>`, or in a fork checkout `gh repo view <origin's URL> --json nameWithOwner --jq .nameWithOwner`. A PR from another fork fails this, because the STOP push goes to `origin`.
  - `origin/<head>` is at the head commit of the PR.
  - The checkout is on the head branch, at `origin/<head>`: a commit that is not pushed is then a commit of the run.
  - The checkout is clean: `git -C <checkout> status --porcelain` prints nothing.
  - The tests of the checkout are RSpec specs, the only suite that the checks run: `git -C <checkout> ls-files 'test/*_test.rb'` prints nothing. A plugin still on minitest stops here.
  - The checkout has `bin/rubocop` and `bin/rspec`, which the checks run.

  Every range below starts at `<base-ref>`: `origin/<base>`, never the local base branch, which can lag behind. In a fork checkout, `origin` is a fork and another remote, `<remote>`, is the project (`git -C <checkout> remote -v`, often `upstream`). The `<base>` of the fork can lag the same way. So `<base-ref>` is `<remote>/<base>`, fetched from it (`git -C <checkout> fetch <remote> <base>`). The head, the conditions above and the STOP push stay on `origin`.

  When the branch touches `openspec/` (`git -C <checkout> diff --name-only <base-ref>...HEAD -- openspec/` prints a path), run the `openspec validate` commands of `AGENTS.md` "Verify before pushing" in the checkout once. A failure stops the run in a `PASS 0/8` line, as the conditions above do.
- **Spec clone:** the spec runs of the loop run in a clone of the checkout, so that no other run shares their files. A host app is the exception (**Checks**). `<spec clone>` is `<scratchpad>/<repo>-clone`. The first sync of **Checks**, before a spec run or a trace, makes it when it does not exist.
- **Commands** run against the checkout: `git -C <checkout> …`, `(cd <checkout> && bin/…)`, `gh … --repo <project>`.
- **Ledger:** `tmp/review-loop/<repo>/<pr>.md` in camaleon-cms, whatever the target repo, never committed. A ledger with no `## Run` header does not exist yet, or holds only the `PASS 0/8` line of a setup that stopped before this step. Only then create it, if needed. Seed it as pass 0 from the memory entry of the PR, if any. The seed holds the REFUTED and DECISION rows that every STOP adds there. It also holds any other refuted entry as REFUTED, and any skipped entry as DECISION, or as FIXED when a later commit fixed it.

  Each run appends, in one command, `## Run <date>, effort <level>` and the line `setup HEAD <sha>`, the PR head that setup found. It counts its passes from 1. The rows of earlier runs still count for the verdict checks.
- **Rules:** `SKILL.md` made the copies of the rule files in `tmp/review-loop/<repo>/<pr>.rules/`, and every pass loads the rules from there.
- **CI:** read the ci check of the `setup HEAD`, as **Checks** says. A poll, when **Checks** starts one, runs as a background task, which gives the ledger its `task` line, and the review goes on meanwhile. When the poll ends, read its result as **Checks** says. Append the `ci` line of **Checks** when the read ends, with the `setup HEAD` as its `<sha>`. Before its PASS line, pass 1 waits for a poll that still runs (the wait of `docs/ai/testing.md` "Long commands").

  A marked `setup HEAD` has no suite run of its own. The `<sha>` of the ci commands is then the head of the newest suite run of the branch: `S='Audit|Test supported versions' gh run list --repo <project> --branch <head> --limit 100 --json headSha,workflowName --jq '[.[] | select(.workflowName | test("^(" + env.S + ")$"))] | .[0].headSha // empty'`. The `ci` line still names the `setup HEAD`. The command prints nothing when the branch has no suite run (ci n/a), and a failed `gh` is no result. After a rebase, that run can be on a commit that the branch no longer has. When `git -C <checkout> rev-parse -q --verify '<sha>^{commit}' > /dev/null && git -C <checkout> merge-base --is-ancestor <sha> HEAD` exits with 1, ci is n/a too: `merge-base` alone exits with 128 for a commit that the repository lacks (no result, `docs/ai/testing.md`).

  The first `ci` line under the run header is the ci read of setup. Trace a failed suite job there (`trace.md`) in pass 1, before the review when possible, otherwise before the PASS line. Trace it before the rerun of its run, which the trace can start. A rerun tests the old commit, so a job whose failure the trace fixed fails again there, and that failure does not count.

  The read ends before the trace of a failed job. With no failed job, it ends after the one rerun of a run, when that run gets one. The run stops on `no jobs`, `pending` or `cancelled` (**Checks**). The stop comes at the end of pass 1, which commits its fixes first.

## Pass start

Every pass starts with one step, after `SKILL.md` loaded `procedure.md`: it reads the lines of the ledger that the rules below use, with two commands. `LC_ALL=C awk '/^(rerun |setup )/ {print; next} /\| (REFUTED|DECISION|CONFLICT) \|/ {m=$0; sub(/ \| (REFUTED|DECISION|CONFLICT) \| .*$/, "", m); n=split(m, a, " \\| "); match($0, /\| (REFUTED|DECISION|CONFLICT) \|/); v=substr($0, RSTART+2, RLENGTH-4); h=""; if (match($0, /judged at [0-9a-f]+/)) h=substr($0, RSTART+10, RLENGTH-10); c=a[2]; for (k=3; k<=n-2; k++) c=c " | " a[k]; print a[1] " | " c " | " a[n-1] " | " v " | " h}' <ledger>` prints the `rerun` and `setup` lines of every run, and the verdict rows in a compact form. Of each REFUTED, DECISION or CONFLICT row, it prints the pass, the claim, the location, the verdict and the HEAD. `LC_ALL=C awk '/^## Run /{r=NR} /^PASS /{p=NR} {l[NR]=$0} END{for(i=r;i<=NR;i++) if (i>p || l[i] ~ /^(## Run|setup |ci |rerun |PASS )/) print l[i]; else if (l[i] ~ /\| FIXED \|/) {s=l[i]; sub(/ \| FIXED \| .*$/, "", s); n=split(s, a, " \\| "); print a[1] " | " a[n-1] " | " a[n]}}' <ledger>` prints the state lines of this run and every line after its last PASS line. Of each FIXED row of this run, it prints the pass, the location and the category.

Read a whole FIXED row of this run only when a finding names its location: `L='<location>' LC_ALL=C awk '/^## Run /{r=NR} {l[NR]=$0} END{for(i=r;i<=NR;i++) if (index(l[i], ENVIRON["L"]) && l[i] ~ /\| FIXED \|/) print l[i]}' <ledger>`. Read a whole verdict row the same way when a finding matches its claim or its location: `L='<text>' LC_ALL=C awk 'index($0, ENVIRON["L"]) && /\| (REFUTED|DECISION|CONFLICT) \|/' <ledger>`. Write `'\''` for an apostrophe of the text. `LC_ALL=C` lets `awk` read a ledger with invalid UTF-8, as `-a` does for `grep`. Do not read the other lines.

The PASS, `setup`, `ci` and `rerun` lines give the pass count and the state of each pass. The rows after its last PASS line, the `review`, `task`, `todo` and `fix` lines among them, are the open work of a cut-off pass. The verdicts check the REFUTED, DECISION and CONFLICT rows of the whole ledger, the seed of pass 0 included. Step 5 checks the location of the FIXED rows of this run.

From pass 2 on, and in a resumed pass 1, the pass also checks the checkout. The checkout must still be on the head branch, at the `<before>` of the pass (**PASS line**) or past it (below). Its tree must be clean, or the run's own (below). Other sessions and the IDE share the checkout. Without this check, the pass reviews and commits a switch, an edit or a commit made between passes as the work of the run. The push can also carry such a change, under checks that ran on another tree.

The open work of a cut-off pass has three kinds. The state of the checkout and the lines after the previous PASS line tell them apart. A `task` line after that PASS line names a task of the cut-off pass. Judge it by its log, or wait for it (`docs/ai/testing.md` "Long commands"), instead of a new run. A `task` line of a ci poll is over when a `ci` line follows it.

- **Commits past the `<before>`, with ledger rows that record their SHAs:** the run's own. A pass cut off before its PASS line left them: finish that pass instead of a new one.
- **A clean tree, with a `review` line after that PASS line:** the pass fixes the open `todo` lines and runs no new review. A `todo` line is open until a FIXED row with its claim follows it. With no `review` line after that PASS line, the pass runs its review. It first reads the candidate files of this pass (**Pass**). An angle whose file ends with `done` does not run again, and the other angles do.
- **A dirty tree with the `<tree>` of the last `fix` line after that PASS line:** the run's own. A pass cut off during the checks of that fix left it. Compute the `<tree>` of the checkout with a temporary index: `(export GIT_INDEX_FILE=<tmp>; git -C <checkout> read-tree HEAD && git -C <checkout> add -A && git -C <checkout> write-tree)`. `<tmp>` is an absolute path outside the checkout, and the index of the checkout stays as it is. Finish the checks and the commit as below.

For the dirty-tree kind, look for the last `task` line of a spec run after the last `fix` line. Judge it by its log, or wait for it (`docs/ai/testing.md` "Long commands"). With none, start the spec run, unless the commit has no spec file (**Checks**). Another such line between them is a first run that failed or had no result: judge both (`docs/ai/failures.md`, **Checks**). A `task` line marked `# no fix`, or whose command runs in the clone of `docs/ai/failures.md` step 1, is neither the first nor the second run. A `fix` line of category `ci` resumes at the run after the fix (`trace.md`), which says whether the commit also runs its specs.

Then run the checks after the spec run that the commit needs: brakeman, zeitwerk:check and the openspec commands (`AGENTS.md`). The open lines are the `fix` lines of the last `<tree>` that have no FIXED row after that PASS line. First, alone, make the fixup commit for each open line that has a fifth field (**Checks**). Then commit the fix of the other open lines, after `git add -A`, with their rows. Write the SHA of the commit in the evidence field of each of those rows.

A pass 1 can be cut off that way: its run header is the last of the ledger, with no PASS line under it. Finish it the same way against the `setup HEAD` under that header, without a new setup. In pass 1, the `setup HEAD` line takes the place of the PASS line.

The `ci` lines of the `setup HEAD` under that header say where setup was cut off:

- No such line: read the ci check of setup first. When a poll ran, its last `task` line names its log.
- The last such line names a failed job, with no `fix` line of category `ci` after it: the trace is still open. Read the ci check again, then finish the trace.
- A `rerun` line with no `ci` line after it: read the ci check again. When `gh run view <run id> --repo <project> --json attempt --jq .attempt` prints 1, the rerun never started: run the rerun command of **Checks** first, which is no second rerun.
- The last such line says `no jobs`, `pending` or `cancelled`: the pass stops at its end. Finish it, then write its PASS line with the stop.

Any other state of the checkout stops the run: say so. Do not switch, reset, stash or commit. When the commits of the branch changed, also tell the user to start a new run. A rebase onto the base is one example. The user must push the branch before that run, because setup stops on a checkout that is not at `origin/<head>`. A rewrite of pushed commits needs the lease of `docs/ai/workflows.md` Phase 3.

## Pass

Run `/code-review <effort> --fix` on the local branch of the checkout against the base, unpushed commits included. Give it no target for camaleon-cms, and the checkout path for another repo. Its scope is `git -C <checkout> diff <base-ref>...HEAD`, whatever range `/code-review` picks on its own. On its own, it can pick `@{upstream}...HEAD`, which holds only the commits not yet pushed. Never target the PR number: that can review the pushed head, which lacks the commits of this run. When the review cannot cover that whole range, stop and say so.

The brief of the review tells each finder to append each candidate that it keeps to `tmp/review-loop/<repo>/<pr>.candidates/<pass>-<angle>.md` in camaleon-cms. The file ends with a line `done`. A resumed pass reads those files (**Pass start**), and a new run removes the directory (`SKILL.md`).

The conventions angle of the review reads the live `AGENTS.md` of camaleon-cms, not the copy of the run. For another repo, the conventions angle of the review holds the code to the `CLAUDE.md` of camaleon-cms (`AGENTS.md`). Plugin, theme and host app checkouts carry no agent docs of their own. A CLAUDE.md governs only the files at or below its directory, so the angle finds none otherwise.

`AGENTS.md` "Support range" says which ground rules do not bind a host app. Apply findings only as the verdicts allow.

## Ledger rows

pass | claim | file + function, spec example or doc section heading (no line numbers) | category | verdict | evidence (fix SHA, or reason + `judged at <sha>`)

Append the rows other than FIXED when their findings get a verdict. Append them in one command, with one line `todo <claim> | <location> | <category>` per finding with the verdict FIXED, and the line `review`. The `review` line records that the review ran, also when it found nothing. Append a FIXED row in the same command as the commit of its fix, which gives the row its SHA. A SHA in a row has 12 characters (`git rev-parse --short=12 <sha>`). The `setup`, `ci` and `fix` lines keep the full value, which `gh` and the tree test need.

The message of a commit follows `docs/ai/prose.md`: a subject line and at most three sentences, with no pass number and no ledger label. Before the commit, print each sentence of the message over 25 words, and its sentence count when over three: ``ruby -e 'bad = false; ss = File.read(ARGV[0]).gsub(/(?<!`)(`+)(?!`).+?(?<!`)\1(?!`)/, "X").split(/(?<=[.!?])[*_")\]]*\s+(?=[^a-z])|\n\n+/); ss.each { |s| n = s.split.size; next if n <= 25; bad = true; puts "#{n}: #{s}" }; c = ss.drop(1).count { |s| s.rstrip.sub(/[*_")\]]+\z/, "").end_with?(".", "!", "?") }; if c > 3 then bad = true; puts "#{c} sentences" end; exit(bad ? 1 : 0)' <file>``. Reword the message when the command prints. The command takes a code span as one word (`docs/ai/prose.md`). A sentence ends at its mark, also before a closing `**`, `"`, `)` or `]`. It exits with 1 when it prints, so `&&` can chain the commit after it.

Before the commit, also print each added Markdown sentence over 25 words and each paragraph over six sentences: ``git -C <checkout> diff --cached -U0 -- '*.md' | ruby -e 'bad = false; b = []; f = false; chk = lambda { next if b.empty?; t = b.join(" "); b = []; ss = t.split(/(?<=[.!?])[*_")\]]*\s+(?=[^a-z])/); ss.each { |s| n = s.split.size; next if n <= 25; bad = true; puts "#{n} words: #{s[0, 70]}" }; next if ss.size <= 6; bad = true; puts "#{ss.size} sentences: #{t[0, 70]}" }; ARGF.each_line { |l| if l !~ /\A\+(?!\+\+)/ then chk.call; f = false; next; end; s = l[1..].chomp.sub(/\A\s*>\s?/, ""); if s =~ /\A\s*(```|~~~)/ then chk.call; f = !f; next; end; next if f; if s.strip.empty? || s =~ /\A\s*(\||#+\s|---)/ then chk.call; next; end; chk.call if s =~ /\A\s*(?:[-*+]|\d+\.)\s/; b << s.sub(/\A\s*(?:[-*+]|\d+\.)\s+/, "").gsub(/(?<!`)(`+)(?!`).+?(?<!`)\1(?!`)/, "X") }; chk.call; exit(bad ? 1 : 0)'``. The `add` of the `fix` line staged the changes that it reads. The check joins the added lines of a paragraph, so it reads a hard-wrapped paragraph when the diff holds all its lines. It skips a table row, a heading and a fenced block, when the diff holds its opening fence. It counts a code span and a sentence end as the message check does. Judge its output: the fragments of a changelog entry and a template line are no sentences.

The commit of a failure fix (`docs/ai/workflows.md` Phase 3) also gets a FIXED row, with the check as its category. The category is `ci` for the fix of a failed suite job, and `flake` for a flake fix. A repair of a line, a spec example or a new file of the uncommitted fix (`docs/ai/failures.md`) is part of that fix. The repair gets no row of its own. Because each commit command appends its rows, a pass cut off before its PASS line leaves every commit that it made on record.

The loop never rewrites a commit. A rewrite gives commits new SHAs, which the rows and PASS lines no longer match. A failure that an earlier commit of the branch caused gets a `fixup!` commit (`docs/ai/workflows.md` Phase 3). The user folds the fixup commits with `git rebase --autosquash <sha>~1`, where `<sha>` is the oldest commit that they fix. The report names the fixup commits and `<sha>`.

## Verdicts

Check the steps in order. A finding that is also a correctness or security defect skips steps 5 and 6 and goes to step 7, whatever its category. The pass applies only FIXED and leaves no finding without a verdict. Commit the fixes as `docs/ai/workflows.md` Phase 3 says.

1. Check every finding against the code yourself, whether or not the review verified it. Refuted → REFUTED. PLAUSIBLE, only when that check can neither confirm nor refute it → DEFERRED. Low severity or a loud failure is no reason to defer a confirmed defect.
2. Same claim as a DECISION or REFUTED row, on code that the row's HEAD also has → REPEAT if DECISION, CONFLICT if REFUTED. A REPEAT row names the new evidence of the finding, if any, for the user. The row's HEAD is the `<sha>` after `judged at` in its evidence, the HEAD at which the pass judged it. A row that names no HEAD, such as a pass 0 seed, has the `setup HEAD` of the run header after it. If that code changed, treat the claim as new. A sentence that a commit of the run added, reworded, split or moved, and that keeps the decided meaning, counts as the same code.

   Also treat it as new when the repository no longer has that HEAD: `git -C <checkout> rev-parse -q --verify '<sha>^{commit}'` exits with 1. A rewrite leaves the old HEAD off the branch, but the repository keeps it.
3. A fix that undoes a commit already on this branch (`<base-ref>..HEAD`) gives CONFLICT. A fix that goes against a DECISION row on the same code, as step 2 defines it, gives CONFLICT too.
4. Needs a design trade-off or the user's call → DECISION. A fix that re-adds what the PR removed on purpose, as its body records, is the user's call too. The `decision` parameter says whether the row stops the run after this pass (see **Pass states and stop**).
5. Reuse, simplification or efficiency (the cleanups), conventions (code that breaks a `CLAUDE.md` or `AGENTS.md` rule) or coverage-only → FIXED. A fix needs a spec as `AGENTS.md` "Specs" says, and a conventions fix can change behavior. A coverage-only fix is the new spec.

   Once step 5 is frozen (see below), the findings of step 5 are DEFERRED instead. A cleanup is also DEFERRED when a cleanup of an earlier pass of this run reshaped that function, spec example or doc section.
6. Altitude or wording → FIXED in pass 1, DEFERRED after. Wording is text that still gives the right outcome when a reader follows it literally. Text that gives a wrong outcome is a defect.
7. A correctness or security defect → FIXED, with the spec that reproduces it. The row has the category correctness or security, whatever category the review gave the finding. `AGENTS.md` "Specs" and `docs/ai/workflows.md` Phase 3 give the exceptions.

## Checks

The checks are the four in camaleon-cms `AGENTS.md` "Verify before pushing", in the form of the table for each kind of checkout. When `AGENTS.md` "Verify before pushing" exempts the branch or the commit from a check, that check is n/a too.

| | camaleon-cms | plugin or theme | host app (PostgreSQL) |
|---|---|---|---|
| suite workflows | `Audit`, `Test supported versions` | `CI` | `test-on-push` |
| brakeman | as `AGENTS.md` | n/a | `bin/brakeman --no-pager` |
| zeitwerk:check | as `AGENTS.md` | the same | `bin/rails zeitwerk:check` |
| spec database | the SQLite file of the spec clone | the same | its own test database, shared with every checkout of the app |
| spec runs | the spec clone | the same | the checkout, under the other-run wait |

The loop runs the checks before each commit, the lint first, as `docs/ai/workflows.md` Phase 3 says. The PASS line reports the last run of each check in the pass, or n/a when the pass did not run it.

Every spec run, every ci poll and any other command that can outlast the timeout is a background task (`docs/ai/testing.md` "Long commands"). When the tool answers, append `task <id> <log> <command>` to the ledger.

Between the lint and the other checks of a fix, append one line `fix <tree> | <claim> | <location> | <category>` per FIXED row of its commit. A fix that runs no lint gets the lines at once. The three fields after `<tree>` are the claim, the location and the category of the row, for the resume of a cut-off pass (**Pass start**). `<tree>` comes from `git -C <checkout> add -A && git -C <checkout> write-tree`: the tree of the checkout with the uncommitted fix. The `add` stages the fix, which its commit needs. After a repair or a failure fix, append the `fix` lines of every uncommitted fix again before the checks.

Before the commit, the same two commands must print the `<tree>` of its `fix` line. Otherwise the tree changed during the checks: append the `fix` lines again, and run the checks again.

Judge the command by its result, as `docs/ai/testing.md` "Long commands" says. With no result, start the command again once. A second spec run that ends with the same summary line and exit code is a failure: `docs/ai/failures.md` traces it. A hang, or any other second start with no result, stops the run: report the command with its log. A sync or a `gh` command that fails has no result too, and the report gives its output in place of a log. A `gh run rerun` that GitHub refuses, with an HTTP 4xx error in its output, has a result: the refusal (below).

The fifth check is **ci**: the GitHub workflow runs of a commit, the rows of `gh run list --commit <sha>`. In camaleon-cms, they test the PR merged into the base, on every Ruby and Rails of the matrix. Setup reads them for the `setup HEAD`. A stop that pushes reads them again for the pushed commit (see **Pass states and stop**).

Each read ends with the line `ci <sha> <ok, n/a, no jobs, pending, cancelled or the failed job>` in the ledger. Its `<sha>` is the HEAD that the read stands for: the `setup HEAD` at setup, and the pushed commit after a push. The ci field of a PASS line is the value of the last `ci` line of the run for the `<after>` of the line. With no such line, it is n/a.

- The suite runs are the runs of the suite workflows of the table, which run the lint, the scans and the suite of the repo. In camaleon-cms, they are the workflows that `.github/workflows/release.yml` requires. Their jobs are the suite jobs, and every other run is advisory. Examples are `Test upcoming versions` (Rails edge and Ruby head) and `Test ecosystem members`. A failed or cancelled advisory run gets a DECISION row, and a pending one gets no row. No advisory run fails ci, but a failed suite job does.
- In the commands below, `S` holds the suite workflows of the table, joined with `|`. The commands show the camaleon-cms value.
- ci is n/a when the repo has no workflow file. After a push, ci is n/a when the pushed head carries a skip marker. Then do not read ci.
- A head carries a skip marker when its message has one: `docs/ai/workflows.md` Phase 3 lists the markers, and `git -C <checkout> log -1 --format=%B <sha>` shows the message. Match a bracket marker anywhere as a fixed string (`grep -F '<marker>'`). A `skip-checks` trailer counts only when `git -C <checkout> cat-file commit <sha> | tail -n 3` prints two empty lines and then the trailer. Setup tests the `setup HEAD` the same way (**Setup**, CI).
- `<sha>` is the full SHA of the head: `gh` matches no short SHA and prints an empty list for one. For a marked `setup HEAD`, it is the head of the newest suite run of the branch (**Setup**, CI).
- List the runs once: `gh run list --repo <project> --commit <sha> --json workflowName,status,conclusion,databaseId`. When every suite workflow has a run, and every suite run is completed, read the conclusions of the runs (below). Else read ci with one poll, as a background task: `for i in $(seq 120); do r=$(S='Audit|Test supported versions' gh run list --repo <project> --commit <sha> --json workflowName,status --jq '[.[] | select(.workflowName | test("^(" + env.S + ")$"))] | if (unique_by(.workflowName) | length) < (env.S | split("|") | length) then "absent" elif all(.status == "completed") then "completed" else "pending" end'); echo "$i $r"; case "$r" in completed) exit 0;; absent) [ "$i" -ge 11 ] && exit 3; e=0;; pending) e=0;; *) e=$((e+1)); [ "$e" -ge 3 ] && exit 5;; esac; sleep 30; done; exit 4`.
- The exit code of the poll is its result:
  - 0: every suite run is completed.
  - 3: a suite workflow still has no run after five minutes. GitHub makes the runs seconds after a push, so it made no run of that workflow for the head. A merge conflict of the PR with the base is one cause, and a workflow file that does not parse is another. Report ci as `no jobs`.
  - 4: a suite run is still pending after an hour. Report ci as `pending`.
  - 5: three calls of `gh` one after the other failed, and the log holds the error. The poll has no result.
- After exit code 0, list the runs again and read the conclusions (below).
- Of the runs of one suite workflow, read the newest, with the largest `databaseId`. A reopened PR gives a workflow a second run on the same head. A conclusion `success` or `skipped` passes. For any other conclusion of a suite run, `gh run view <run id> --repo <project> --json jobs --jq '.jobs[] | select(.conclusion != "success" and .conclusion != "skipped") | "\(.databaseId) \(.conclusion) \([.steps[] | select(.conclusion == "failure")] | length) \(.name)"'` names the jobs that did not pass, with the count of their failed steps.
- A job with a failed step is a failed job. Setup traces it as the copy of `trace.md` says (**Setup**, CI). Any other job that did not pass did not run to its end. Examples are a cancelled job, a job with no step, a job that timed out, and a suite run with no job. A job or a run that did not run to its end gets the one rerun of its run (below).
- Rerun a run once: append `rerun <run id>` to the ledger, then run `gh run rerun <run id> --repo <project> --failed`, which reruns the failed and the cancelled jobs. When GitHub refuses that command, run `gh run rerun <run id> --repo <project>`, the whole run. Then read ci again. A workflow run with a `rerun` line anywhere in the ledger gets no second rerun, also from a later run of the loop. The jobs of a workflow run with a `rerun` line count as the jobs of its rerun. A restart of a failed `gh run rerun` command (above) is not a second rerun.
- A rerun whose jobs pass gives ci ok. A job whose failure the trace fixed does not count (**Setup**, CI). A job of the rerun that does not run to its end, or a refused whole-run rerun, gives ci `cancelled`. Report the run.

- A spec run before a commit runs the specs of the fix and the adjacent specs (`docs/ai/workflows.md` Phase 3), never the whole suite. The exceptions are the trace of a CI failure (`trace.md`) and an adjacent set of more than half of the suite (`AGENTS.md` "Verify before pushing"). `docs/ai/testing.md` says which files `bin/rspec` gets. When a commit has no such spec file, skip the run and report rspec as n/a.
- A commit that touches `openspec/` also runs the `openspec validate` commands of `AGENTS.md` "Verify before pushing".
- When a check fails, find out what caused the failure as `docs/ai/failures.md` says. Then fix it as `docs/ai/workflows.md` Phase 3 says. In the `git merge-base` command of `docs/ai/failures.md` step 4, `<base-ref>` takes the place of `origin/<base>`. For a spec run, the spec clone takes the place of the checkout, except for a host app (below). The failed run, the second run and the run after a fix happen there. The ignored file that its step 3 names is then a file of the spec clone.
- A failure whose cause the trace does not find stops the run: report the check with its log.
- The clone of `docs/ai/failures.md` step 1 stays a clone of its own, outside the spec clone. The run of step 2 without the fix comes first, in the spec clone synced with `no copy`. The `task` line of the run without the fix ends with `# no fix`. Make the clone of step 1 only when step 3 runs.
- `docs/ai/failures.md` step 4 runs the check at the start commit of the branch. When it fails there in the same way, stop the run. Leave the uncommitted fix in the tree, and name it in the report as the run's own.
- When a commit of the branch caused the failure, make the fixup commit of `docs/ai/workflows.md` Phase 3, without the rebase. The FIXED row of the fixup commit also names the commit that it fixes. Its `fix` line ends with a fifth field, the SHA of that commit. The pass stops the run after its last commit (see **Pass states and stop**).
- A spec run of the loop, before a commit or in a trace, runs in the spec clone (see **Setup**), never in the checkout. A host app is the exception (below). Before the spec run, sync the spec clone, with the ten-minute timeout (an install can take minutes). The sync has these parts, joined with `&&` in this order, and a run names `<commit>` and the parts that it skips. Every other part runs, unless its bullet names a case where it does not. A failed sync has no result (above).
  - The clone, when the spec clone does not exist: `[ -d <spec clone> ] || git clone -q <checkout> <spec clone>`.
  - The reset: `git -C <spec clone> fetch -q <checkout> HEAD && git -C <spec clone> reset -q --hard <commit> && git -C <spec clone> clean -fdq -e 'gemfiles/*.lock'`. `<commit>` is `FETCH_HEAD`, the HEAD of the checkout, unless the run names another commit of the branch. The reset discards the changes that the previous spec run copied in. The `clean` keeps the lock of a job gemfile for a trace (`trace.md`).
  - The merge, in a trace only (`trace.md`).
  - The copy of the uncommitted changes, with their new files: `git -C <checkout> add -A && git -C <checkout> diff HEAD --binary | git -C <spec clone> apply --3way --allow-empty`. A run that names `no copy` skips it.
  - The install: `(cd <spec clone> && bundle install --quiet)`.
- The spec clone keeps its caches: `git clean` without `-x` leaves the ignored files. No other spec run shares the files of the spec clone or its SQLite file, so a failed spec run there counts. A subagent that runs specs makes a clone of its own the same way, at another path. In a host app, a subagent runs its specs in the checkout too, under the wait below.
- A host app on PostgreSQL (camaleon_website, florsan) runs its specs in the checkout, with no spec clone. A clone lacks the ignored files that its boot reads, such as `.env` and `config/master.key`, and its test database is shared with every checkout anyway. There, a spec run starts only when no other spec run is active. The wait for other runs of `docs/ai/testing.md` "Which specs to run" checks that, an hour at most. A spec run still active after the hour stops the run, and the report names its pids.
- A failed spec run of a host app does not count when `pgrep -f '[r]spec'` names another run at its end. Run a failed spec run that does not count again alone, as `docs/ai/failures.md` says. The clone of `docs/ai/failures.md` step 1 does not run the specs of a host app, which run in the checkout only (above). When a host-app spec run fails again in the same way, stop the run and report the failed examples.

## Pass states and stop

- **SETTLED:** the pass ran to the end and applied no correctness or security fix. Every check passed or was n/a, and the checkout's tree is clean. A correctness fix is a FIXED row whose category is correctness, security, flake or a check name. Step 5 and step 6 fixes can go in.
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

These stops push nothing, also when a reason to push applies. A stop that neither list names pushes nothing too. Each of these stops is defined where it happens:

- A setup stop, also on a ci read of setup with `no jobs`, `pending` or `cancelled` (**Setup**).
- A checkout that changed between passes (**Pass start**), or a pass that ends with uncommitted changes, which can be another writer's.
- A second CONFLICT on a fix that undoes an earlier commit of the branch (**Verdicts** step 3).
- A `fixup!` commit (**Checks**).
- A failure whose cause the trace does not find, or that was there before the branch (**Checks**).
- A CI failure that the spec clone does not show and that a rerun shows again (`trace.md`).
- A hang, or a command with no result twice (**Checks**).
- The wait of a host app that ends after its hour (**Checks**).

`AGENTS.md` wants the checks before a push, and the user judges an undo, another writer's change or a fold. A stop without a push leaves the commits of the run for the user to push before the next run (see **Setup**).

Commit but do not push during the run. The STOP push carries every commit of the run. Decide the skip marker for the whole push: GitHub reads it off the last commit alone (`docs/ai/workflows.md` Phase 3). A marked docs-only last commit also skips CI for the code commits of the run. At a stop that pushes, push the head branch once and fold the PR body (`gh pr edit <pr> --repo <project>`, per `docs/ai/workflows.md`).

The checks ran before each commit of the run, so the push needs no other check run (`AGENTS.md` "Verify before pushing").

Before the push, fetch `origin/<head>`. When it is at HEAD, skip the push, and compare HEAD with the `setup HEAD`:

- HEAD is the `setup HEAD`: the run made no commit.
- HEAD is past the `setup HEAD`: a pass cut off after its push made the commits. Read ci for HEAD, as below.

Push with `git -C <checkout> push origin <head>`.

A push rejected because `origin/<head>` moved during the run stays unpushed too. A PR merged or closed during the run also stays unpushed: check its `state` again before the push. Leave the PR body unfolded and say so. Do not pull, rebase or force past the rejection. After a pull or a rebase, the push carries a tree that the checks never ran on. A forced push drops the other commits.

After a push that moved `origin/<head>`, read the ci check of the pushed commit (see **Checks**). The run is over, so the loop does not trace a failure there. It reruns once each run in which a suite job did not pass, and reads ci again (**Checks**). A job that fails again is the failed job that ci reports. After a DECISION stop, it reads ci and reruns nothing.

A STOP that pushed does not meet the goal when its ci is neither ok nor n/a (see the goal text). A DECISION stop is the exception, and counts as it stands: the user answers the rows first.

The next turn sets up a new run. After a DECISION stop, the turn after the answers sets it up. The setup of that run traces a failed suite job of the head, or stops as **Setup** says.

On every STOP, add the new REFUTED and DECISION rows to the PR's memory entry, if it has one. A STOP that pushed does this after its ci read. Report the DEFERRED, DECISION, REPEAT and CONFLICT rows of the run: `LC_ALL=C awk '/^## Run /{r=NR} {l[NR]=$0} END{for(i=r;i<=NR;i++) print l[i]}' <ledger> | grep -E '\| (DEFERRED|DECISION|REPEAT|CONFLICT) \|'`.

## PASS line

The goal's evaluator reads only the transcript, so end every turn with the line below. Append it to the ledger too: the next pass reads the pass count and the state of each pass there. The reason of a convergence stop starts with `converged`, and the reason of a DECISION stop names the row: the goal reads both. The `fixed` field counts the FIXED rows of the pass by category (**Pass states and stop**). The goal reads the STOP field: `pushed` when the run made a commit and `origin/<head>` is at HEAD after the stop, and `not pushed` otherwise. A STOP for convergence quotes the PASS line of the previous pass from the ledger, because compaction can drop that turn from the transcript.

```text
PASS <n>/8 <repo> PR <pr> | HEAD <before> → <after> | git status: <clean, or the dirty paths> | rspec: <summary line> | checks: <ok, n/a, no jobs, pending, cancelled or what failed, per check> | fixed: <x> correctness/security, <y> other | step 5: <on or frozen> | deferred <b>, repeat <c>, decision <d>, conflict <e> | <CLEAN, SETTLED or UNSETTLED> | <continue, or STOP: reason, pushed or not pushed>
```

`<before>` is the `<after>` of the previous PASS line, or the `setup HEAD` in pass 1. `<after>` is the HEAD of the checkout at the end of the pass.
