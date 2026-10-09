# Workflows

## Phase 1: Branch Initialization

Before writing any code:

1. Start from the latest `master`.
2. `git checkout -b <type>/<brief-description>` with the prefixes from `AGENTS.md` (`feature/`, `fix/`, `security/`), and tell the user the branch name.
3. For a security fix, run the Vulnerability Triage Protocol (Phase 2A) before writing the fix.

---

## Phase 2: Execution

### A. Vulnerability Triage Protocol

Verify that a reported vulnerability is present and exploitable in this codebase before acting on it.

1. **Proof of presence.** Do not assume the report is correct. Dependency report: `bundle exec bundle-audit check` — does the gem and version match `Gemfile.lock`? Code or static report: `bin/brakeman -z --only-files <file_path>` — does Brakeman flag the line? Otherwise grep the codebase for the pattern.
2. **Verdict**, stated to the user as one of: ✅ **Legit** (present in our context, with the evidence), ❌ **False positive** (a library we do not use, a pattern only in test-only code, …), ⚠️ **Unverifiable** (the tools cannot confirm the risk; recommend a manual audit).
3. **Only on ✅ Legit**, write the failing reproduction first (rule in `AGENTS.md`; shape in `docs/ai/testing.md`, "Security Vulnerability Reproduction"), then the fix.

### B. Development

The spec-coverage, reproduce-first and reject-don't-transform rules are in `AGENTS.md`. The full security model — the gating rule, the remedy rule, and the pieces that implement them (`CamaleonCms::UnsafeMarkup`, model-level gates, `unfiltered_content!`-style opt-outs, the `camaleon_cms:security:scan_*` audit tasks) — is `docs/security/permissions.md`; read it before touching content saves, uploads, or a permission.

### C. Refactoring Protocol

- **Step-0 cleanup:** before a structural refactor of a file over 300 LOC, remove dead code (unused methods, unused requires, debug output) in its own commit first.
- **Phased execution:** no large multi-file refactor in one pass. Phases touch at most 5 files each; run verification and wait for explicit approval between phases.

### D. CI Parity

Before pushing, `AGENTS.md` "Verify before pushing" passes, as scoped there.

---

## Phase 3: Commit Guidelines

**One fix per commit by default, committed as soon as it is green.** When a review or an audit finds several defects, all their fixes go in the same PR. Each fix comes with the spec that reproduces the defect. A fix can be only a spec or only docs, when that is the whole fix. When a spec is infeasible, the commit message says why.

Related fixes can share a commit. Related fixes are the fixes of one finding or one failed check, or of findings on the same sentences, function or spec example. The changes of one autocorrect run are also related. A check fix or an autocorrect change of the uncommitted fix goes in the commit of that fix. Unrelated fixes never share a commit, also on a pushed PR branch.

Commit each fix or group of related fixes as soon as the `AGENTS.md` checks pass for what it touched. Commit the fix before you start an unrelated fix.

Run the checks in their order. Run `bin/rubocop -A` first, on the whole repo: CI lints the whole repo. Do not give it a list of files: RuboCop then also corrects a listed file that `.rubocop.yml` excludes. The changes of the lint go in the commit of the fix.

Then run the specs of the fix and the adjacent specs, brakeman and zeitwerk:check. When no spec file applies, skip the spec run: `bin/rspec` with no files runs the whole suite. Do not run the checks before you start a change.

When a check fails, wait until no other spec run is active (`docs/ai/testing.md`). Then run the check again in the checkout, the same way. This is the second run. An RSpec run uses the same files and the `--seed`, if any.

When the check does not fail in the same way, the result is not the same each time. When another run was active during the first run (`docs/ai/run-markers.md`), that run caused the failure, and there is nothing to fix. Otherwise the failure is a flake. Find the cause of the flake and fix it. The fix goes in the commit of the uncommitted fix, also when the flake was there before the branch. When no fix is uncommitted, the flake fix is a commit of its own. Then run the checks again, the lint first.

When the check fails again in the same way, find out what caused the failure. The uncommitted fix caused it when the failure is in a line or a spec example of this fix. A failure in a file that this fix adds also comes from this fix. Fix the failure in the commit of the fix. For any other failure, find the cause with one bisect in a scratch clone:

1. Clone the checkout into a directory outside it: a clone inside it shows in `git status`. Do not clone GitHub: it does not have the commits that are not pushed. Make a new clone for each failed check. An older clone does not have the later commits, and a bisect leaves it at another commit.
2. Copy the uncommitted fix into the clone, stage all of it (`git add -A`) and commit it there. `git -C <checkout> diff HEAD --binary | git -C <clone> apply --allow-empty` copies the changes to tracked files. Also copy the new files: `git -C <checkout> ls-files --others --exclude-standard` lists them. When the checkout is clean and has no new file, skip this step. The branch of the clone now ends with the commit of the fix.
3. Run the failed check in the clone. When it passes, a file that git ignores in the checkout caused the failure, for example a cache under `spec/dummy/tmp`. Find that file and remove it. Then run the check again in the checkout. When it still fails, the clone differs from the checkout in another way: find that difference.

   When the check fails in the clone and step 2 made a commit, run the check at the commit before it. When it passes there, the fix caused the failure. Fix the failure in the commit of the fix, and skip steps 4 and 5.
4. Find the start commit of the branch in the checkout (`git merge-base origin/<base> HEAD`). In the clone, `origin/<base>` is the local base branch of the checkout, which can lag. Check out the start commit in the clone and run the failed check. When it fails in the same way, the failure was there before the branch. Tell the user, and do not fix it on this branch.
5. Run `git bisect start <bad> <start commit>` in the clone. `<bad>` is the branch, or the commit before the commit of the fix when step 3 showed that it fails in the same way. Do not give HEAD: the clone is at the start commit. Bisect does not run the check at these two marks, so steps 3 and 4 run it there. Then run `git bisect run` with a script that runs the failed check. The script gives one of these exit codes:
   - 0 when the check passes.
   - 1 when the check fails in the same way.
   - 125 when the check fails in another way. Bisect then skips that commit, because another failure does not show the cause.

Each RSpec run in the clone, also each bisect step, uses the files and the `--seed`, if any, of the run that failed. When the run that failed was the whole suite, each run in the clone is the whole suite too. Do not give it more files. More files change the order of the examples, and an order-dependent failure can then pass. Leave out the files that do not exist at the commit of the run. RSpec fails to load a file that does not exist, and that failure shows nothing. When no file is left, skip the run, as above. The check passes at that commit, because the example that failed is not there.

Each lint run in the clone, also each bisect step, runs `bin/rubocop` without `-A`. An autocorrect changes the files of the clone, and the next `git checkout` in the clone stops. A run in step 3 that fails in another way shows nothing, for example when the clone has no `.bundle/config`, which git ignores. Repair the clone and run the check again. A run in step 4 that fails in another way shows that the start commit does not have this failure. Go on to step 5, as bisect does with exit code 125.

Bisect names the commit that caused the failure. When it lists several commits instead (`The first 'bad' commit could be any of`), the commits before the cause fail in another way. Find the cause in the diffs of the listed commits, or tell the user.

When the cause is the commit of the fix, fix the failure in the commit of the fix. When the cause is a commit of the branch, fix the failure and run the checks again, the lint first. Stage only the changes of the failure fix. When a file holds both fixes, stage the hunks of the failure fix with `git apply --cached <patch>`, not the interactive `git add -p`. Commit them with `git commit --fixup=<sha>` of the commit that bisect names, then commit the uncommitted fix. Fold the fixup commit last with `git rebase --autosquash <sha>~1`: a rebase does not start while the tree has changes.

**A fix and its notes go in one commit.** The commit of a fix holds the code, the spec and the documents that record the fix. Those documents are the OpenSpec artifacts, the upgrade guide and other docs. Do not add those notes in a later commit, which leaves a commit where the code and the documents disagree. The Phase 4 changelog entry and the OpenSpec archive step stay commits of their own.

To add notes to an earlier commit, run `git commit --fixup=<sha>`, then `git rebase --autosquash <sha>~1`. The rebase rewrites only that commit and the later ones.

To push a rewrite of a pushed commit, run `git push --force-with-lease=<branch>:<remote sha> origin <branch>`. `<remote sha>` is the last commit of the branch that you pushed or pulled. With this lease, the push fails when someone else pushed after `<remote sha>`. Always give that SHA. A background fetch, which an IDE can do, moves `origin/<branch>`, and a lease without a SHA trusts it.

Before the rewrite, make sure that your branch holds `<remote sha>` (`git merge-base --is-ancestor <remote sha> HEAD`). Also make sure that the remote branch is at `<remote sha>`: `git ls-remote origin refs/heads/<branch>` prints that SHA. When it prints another SHA, do not rewrite, and tell the user. Push any other change with a plain `git push`.

Whether a push skips CI is decided **per push, not per commit**: GitHub reads the marker off the head commit of the push, and a marked head suppresses every workflow for that push, including the `pull_request` event when the PR is opened at that tip. When invoked, the marker is the literal token on its own line at the end of the message:

```
<commit subject>

[skip ci]
```

It matches anywhere in the message, so a commit that merely explains the directive skips CI too — write "skip-ci directive" in prose unless you are invoking it.

A commit is **docs-only** when it touches only documentation (`.md` files, `README.md`, `docs/`), `CHANGELOG.md`, `openspec/`, comments, or config with no code path.

1. **The entire PR is docs-only** (every commit on the branch): mark **every** commit, including the first, so the PR runs no CI at all — this overrides rule 2. `master` carries no branch protection, so a PR with zero runs still merges; if a required-status-check rule is ever added this carve-out must go (check with `gh api repos/owen2345/camaleon-cms/branches/master --jq '.protected'`).
2. **The PR contains a code change somewhere.** For each push ask: *has this PR already had a full check run on an earlier push?*
   - **No** (no PR yet, or every push so far was docs-only): omit the marker, even on a docs-only push, and say why in the message. A mixed PR gets one full run over its code, and a marked head produces none.
   - **Yes**, and every commit of this push is docs-only: include it. CI validates the tree at the head commit, and a changelog edit changes no tree an earlier run covered. A push with a code commit omits the marker. The Phase 4 changelog commit lands after the PR exists, so it is normally this case — *lands last* is not the condition, *no run yet* is.
3. **Consequences to plan for.** A marked push moves the PR head without a run and leaves the passing checks on the previous SHA; fine while `master` has no required checks, re-trigger only if that changes. If you pushed a docs-only commit *without* the marker by mistake, cancel the now-stale runs on the *previous* SHA, not the new ones. Push a marked docs-only commit only once GitHub has created the run for the code push before it (`gh run list --branch <branch>`): a marked push landing seconds after a code push supersedes that push's `pull_request` event before its run exists, and the code gets no run at all.
4. **Never mark a release PR.** The Release workflow refuses a commit with no successful `current_support.yml` and `audit.yml` runs, and a version bump is a code change anyway. See `docs/releasing.md`.

---

## Phase 4: PR Submission & Maintenance

1. **PR description.** Required: a **What and Why** summary and one sentence of **User-Visible Impact** (or "None"). Not allowed: a Files Changed section, test or example counts, verification logs or commands, commit SHAs or history references, and any evolution narrative — describe the PR's net what/why/how as it now stands, and when commits are added later fold their substance into the description instead of appending follow-up or review-history sections.

2. **Metadata maintenance.** A change to setup, test, or CI commands updates `AGENTS.md`, `docs/ai/testing.md` (if applicable) and `README.md` in the same PR.

3. **Changelog.** After creating the PR, commit an entry under `## Unreleased` that links it:

    ```
    - **Security fix:** Fix mass assignment and open redirect vulnerabilities in SitesController, [#1152](https://github.com/owen2345/camaleon-cms/pull/1152)
    ```

    The entry is a lookup target for someone deciding whether an upgrade affects them, not a narrative; the reasoning lives in the PR description. The **entire entry must not exceed 500 characters**, PR link and reporter credit included, and it does not restate the root cause, the code path, the attack mechanics or the design rationale. Keep a **Breaking changes** list inline only for what the reader must act on or will observe: two to four bullets, one or two sentences each, *what changed for the reader*, never *why*.

    Everything else an upgrader must do or know lives in the release's upgrade guide, `docs/upgrading-to-<version>.md`: operator actions with copy-paste commands, observable behavior changes, notes for theme and plugin developers. Each released version's CHANGELOG section carries a single banner linking the guide (see the `## [2.9.3] …` section), and every entry whose notes moved ends with a link to its guide section anchor, e.g. `[Upgrade notes](docs/upgrading-to-<version>.md#sessions--login)`. Mid-cycle, before the guide exists, draft an upgrader note inline under a **Notes for upgraders** bullet; the release step consolidates those (`docs/releasing.md` Step 1). Once `docs/upgrading-to-<version>.md` exists mid-cycle, new and existing unreleased entries put their detail there and keep only the one-line action plus the anchor link. Before committing, re-read the entry as someone who has never seen the PR: anything that would not change what they do belongs in the PR description or the upgrade guide instead.

4. **Archive the OpenSpec change before merge.** If the work was planned with OpenSpec, run `/opsx:archive` on the branch and commit the result as part of the PR: it syncs the delta specs into `openspec/specs/<capability>/spec.md` and moves the change to `openspec/changes/archive/YYYY-MM-DD-<name>/`. `master` never carries a completed-but-unarchived change, and every box in `tasks.md`, the archive task included, is checked before the branch merges.

5. **Quality gate.** Self-audit against `docs/ai/criteria.md` before completion.
