# Failed checks

A check of `AGENTS.md` "Verify before pushing" failed. This document finds the cause. A second run tells a flake from a failure, a bisect names the commit, and the last section reproduces a failed CI job. The failure fix then goes in as `docs/ai/workflows.md` Phase 3 says.

## Second run

When a check fails, decide first whether a second run can give another result. A failed check whose result is the same each time needs no second run, for example the lint, brakeman or zeitwerk:check. A failure in a line, a spec example or a new file of the uncommitted fix needs no second run either: the fix caused it. Find the cause of such a failure at once.

Run any other failed spec run again in the checkout, the same way. It uses the same files and the `--seed`, if any, and starts only when no other spec run is active (`docs/ai/testing.md`). The run that failed is the first run, and this run is the second run. A failed spec run with another run active during it in the same checkout does not count (`docs/ai/run-markers.md`). Run it again alone: that run replaces it as the first or the second run. When the first run did not count and the run alone after it passes, the check passed: there is nothing to fix.

An item is a failed example, offense, warning, advisory or error, known by its description and file, and a crash is an error. A failure with no item has the exit code of its run as its item. The failure is every item that fails in both runs, or every item of the first run when the check has no second run. An item that fails in one run only is a flake: the result is not the same each time. Find the cause of the flake and fix it. A later run fails in the same way when every item of the failure fails in that run.

## Bisect

When the check fails again in the same way, or needs no second run, find out what caused the failure. Bisect a failure that the uncommitted fix did not cause (above), in a scratch clone. The bisect has three inputs, and the trace of the review loop gives them other values (`.claude/skills/review-loop/trace.md`):

- `<bad>`, the commit that fails: the branch.
- The Ruby and the gems of each command: those of the checkout, or the cell of a job (below).
- Whether the run that failed had the uncommitted fix: yes, when the checkout has one.

The steps:

1. Clone the checkout into a directory outside it: a clone inside it shows in `git status`. Do not clone GitHub: it does not have the commits that are not pushed. Make a new clone for each failed check. An older clone does not have the later commits, and a bisect leaves it at another commit.
2. Run the failed check in the clone first, without the uncommitted fix. When it passes, the fix caused the failure: find its cause in the fix, and skip the other steps. When it fails in another way, that run shows nothing about the fix, and `<bad>` in step 5 is the `<bad>` input. A run in a clean checkout with no new file had no fix. Skip this step and the copy below when the run that failed had no fix.

   Then copy the uncommitted fix into the clone, stage all of it (`git add -A`) and commit it there. `git -C <checkout> add -A && git -C <checkout> diff HEAD --binary | git -C <clone> apply --allow-empty` copies the changes, the new files included. The branch of the clone now ends with the commit of the fix.
3. Run the failed check in the clone. When it passes, a file that git ignores in the checkout caused the failure, for example a cache under `spec/dummy/tmp`. Find that file and remove it. Then run the check again in the checkout. When it still fails, the clone differs from the checkout in another way: find that difference.
4. Find the start commit of the branch in the checkout (`git merge-base origin/<base> HEAD`). In the clone, `origin/<base>` is the local base branch of the checkout, which can lag. Check out the start commit in the clone and run the failed check. When it fails in the same way, the failure was there before the branch. Tell the user, and do not fix it on this branch.

   For the lint and the whole suite, which CI runs the same way, a CI run at the start commit replaces the local run. `gh run list --repo <project> --commit <start commit> --workflow <workflow>` lists the runs of a workflow at that commit, and `gh run view <run id> --repo <project> --json jobs --jq '.jobs[] | "\(.databaseId) \(.conclusion) \(.name)"'` their jobs. `<project>` is the GitHub project, `<owner>/<name>`. `<workflow>` is the file name of the workflow that runs the check. In camaleon-cms, `audit.yml` runs the lint and `current_support.yml` runs the suite.

   Compare the job of the same matrix cell and the items of its `--log-failed` (below). The failure was there before the branch when that job fails in the same way. With no run at the start commit, run the check in the clone.

   A matrix job resolves the gems of its gemfile at each run, so an old green run can hide a gem that changed since. So when bisect names the first commit of the branch, run the check at the start commit in the clone. Make the fixup commit after the run at the start commit.
5. Run `git bisect start <bad> <start commit>` in the clone. `<bad>` is the commit before the commit of the fix when step 2 failed in the same way, else the `<bad>` input. Do not give HEAD: the clone is at the start commit. Bisect does not run the check at these two marks, so steps 3 and 4 run it there.

   Then run `git bisect run` with a script that runs the failed check. The script gives one of these exit codes:
   - 0 when the check passes.
   - 1 when the check fails in the same way.
   - 125 when the check fails in another way. Bisect then skips that commit, because another failure does not show the cause.
   - 128 or above when a signal killed the check, or `git` itself failed: its own exit status, tested before its output. Bisect then stops and keeps its marks, and `git bisect run` started again continues from them.

Each RSpec run in the clone, also each bisect step, uses the files and the `--seed`, if any, of the second run. When the second run was the whole suite, each run in the clone is the whole suite too. Do not give it more files. More files change the order of the examples, and an order-dependent failure can then pass.

Leave out the files that do not exist at the commit of the run. RSpec fails to load a file that does not exist, and that failure shows nothing. When no file is left, skip the run, as `docs/ai/workflows.md` Phase 3 says. The check passes at that commit, because the example that failed is not there.

Each lint run in the clone, also each bisect step, runs `bin/rubocop` without `-A`. An autocorrect changes the files of the clone, and the next `git checkout` in the clone stops. The run of step 3 can fail in another way, for example with no `.bundle/config`, which git ignores. That run shows nothing: repair the clone and run the check again. A run in step 4 that fails in another way shows that the start commit does not have this failure. Continue with step 5, as bisect does with exit code 125.

Bisect names the commit that caused the failure. When it lists several commits instead (`The first 'bad' commit could be any of`), the commits before the cause fail in another way. Find the cause in the diffs of the listed commits, or tell the user.

When bisect names a commit of the branch, the failure fix goes there as a fixup commit (`docs/ai/workflows.md` Phase 3).

## Reproduce a failed CI job

Reproduce a failed CI job before you trace it. Its job log names the failed step, the failed examples and the `--seed`, if any: `gh run view <run id> --repo <project> --job <job id> --log-failed`, with both ids from the link of the check. The last `##[group]Run <command>` line before the first `##[error]` line names the failed step. A step that only prepares the runner does not run on this machine, for example an action (`uses:`) or an install with `sudo`. Run the job again on GitHub: `gh run rerun <run id> --repo <project> --failed`.

After a rerun, a log read with a job id alone can print the latest attempt's log. Take the job id from the jobs command of Bisect step 4 with `--attempt <n>`. Give the log command the same flag. `<n>` is the number of the failed attempt.

Take the command of that step from `.github/workflows/`, not from the log. Run it in the checkout as the workflow does, with the Ruby and the gems of the checkout. Before `bin/bundler-audit`, run `bin/bundler-audit update` once: CI reads a fresh advisory database, and the local copy can lack a new advisory. For a spec failure, first run only the failed examples. When they pass, run the files of the job with its `--seed`, if any. For a job that runs `bin/rspec` with no file, those files are the whole suite.

The checkout run comes before a scratch clone run, because most failures do not depend on the cell of the job. The trace of the review loop goes cell-first instead, because its one run must match CI (`.claude/skills/review-loop/trace.md`).

The CI run is the first run of "Second run" above. The second run is the checkout run when it shows the failure, or when the job has the Ruby and the gems of the checkout. Otherwise the second run is the run in the scratch clone (below). An item that fails in the CI run only is not a flake to trace. Run the job again on GitHub once (above), and tell the user when it fails again. A `<member> / RSpec` check runs the suite of an ecosystem member: reproduce it as `docs/ai/testing.md` "Ecosystem member checks" says.

A job of the matrix runs another Rails (a `BUNDLE_GEMFILE` under `gemfiles/`) or another Ruby. That Rails and Ruby are the cell of the job. When the checkout does not show its failure, reproduce it in a scratch clone (step 1).

CI tests the PR merged into the base commit of its run. The job log names that commit: `HEAD is now at <merge> Merge <head commit> into <base of the job>`. When neither the checkout nor the clone shows the failure, merge that commit in the clone (`git merge <base of the job>`). Then run the step again.

For a job with a gemfile, run `BUNDLE_GEMFILE=<clone>/gemfiles/<rails>.gemfile bundle install` in the clone, then the step with the same variable. The path is absolute, as in the workflow file. A Bundler before 4.0 keeps a relative path as given, and a child process that runs in another directory does not find the gemfile.

When `mise ls --installed ruby` lists a Ruby of the minor version of the job, set `MISE_RUBY_VERSION=<version>` in the environment of each command. `<version>` is that minor version, for example `3.2`, and the shims then run the newest installed Ruby of it. Trace a failure that the clone shows in the clone, with the same variables in each run.

Without an installed Ruby of that version, the shim starts a build of it, which takes minutes. So leave `MISE_RUBY_VERSION` out when mise lacks the version: the step then runs with the Ruby of the clone. Say so in the report. Do not set `MISE_AUTO_INSTALL=0`. With it, the shim runs the next `ruby` on `PATH` with no warning, also for the Ruby of `.tool-versions`.
