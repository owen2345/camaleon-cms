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

1. **Proof of presence.** Do not assume the report is correct. Dependency report: `bin/bundler-audit update && bin/bundler-audit check` — does the gem and version match `Gemfile.lock`? Code or static report: `bin/brakeman -z --only-files <file_path>` — does Brakeman flag the line? Otherwise grep the codebase for the pattern.
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

Related fixes can share a commit. Unrelated fixes never share a commit, also on a pushed PR branch. Related fixes are:

- The fixes of one finding, or of one failed check.
- The fixes of findings on the same sentences, function or spec example.
- The changes of one autocorrect run.
- A failure fix and the uncommitted fix that it joins (below).

Commit each fix or group of related fixes as soon as the `AGENTS.md` checks pass for what it touched. Commit the fix before you start an unrelated fix.

Run the checks in their order. Run `bin/rubocop -A` first, on the whole repo, as `AGENTS.md` "Verify before pushing" says. The changes of the lint go in the commit of the fix.

Then run the specs of the fix and the adjacent specs, brakeman and zeitwerk:check. When no spec file applies, skip the spec run: `bin/rspec` with no files runs the whole suite. Do not run the checks before you start a change.

A failure fix is the fix of a failed check. It goes in the first case of this list that holds:

- **Bisect names an earlier commit of the branch:** a fixup commit of that commit (below).
- **A fix is uncommitted:** the commit of that fix. A flake fix for a flake that was there before the branch goes there too.
- **Otherwise:** a commit of its own.

After a failure fix, run the checks again, the lint first.

When a check fails, find its cause as `docs/ai/failures.md` says. That document holds the second run, the bisect in a scratch clone and the reproduction of a failed CI job.

When bisect (`docs/ai/failures.md`) names a commit of the branch as the cause, record the tree of the checkout first. `git add -A && git write-tree` prints it: `<before>`. Make the failure fix, run the lint, and record the tree the same way as `<after>` before the other checks. The difference between the two trees must be the failure fix alone. Do not change the uncommitted fix between the two records. After a repair of the failure fix, record `<after>` again.

Commit the failure fix from a temporary index, so that no file of the checkout changes: `(export GIT_INDEX_FILE=<tmp>; git read-tree HEAD && git diff --binary <before> <after> | git apply --cached --3way && git commit --fixup=<sha>)`. `<sha>` is the commit that bisect names, and `<tmp>` an absolute path outside the checkout. When the apply exits with 1, the two fixes touch the same or adjacent lines, or a file that the uncommitted fix adds. They are related fixes, so the failure fix joins the commit of the uncommitted fix.

Then commit the uncommitted fix, after `git add -A`. Fold the fixup commit last with `GIT_SEQUENCE_EDITOR=true git rebase -i --autosquash <sha>~1`: a rebase does not start while the tree has changes. A plain `--autosquash` folds nothing before git 2.44, and the rebase still reports success.

**A fix and its notes go in one commit.** The commit of a fix holds the code, the spec and the documents that record the fix. Those documents are the OpenSpec artifacts, the upgrade guide and other docs. Do not add those notes in a later commit, which leaves a commit where the code and the documents disagree. The Phase 4 changelog entry and the OpenSpec archive step stay commits of their own.

To add notes to an earlier commit, run `git commit --fixup=<sha>`, then `GIT_SEQUENCE_EDITOR=true git rebase -i --autosquash <sha>~1`. The rebase rewrites only that commit and the later ones.

To push a rewrite of a pushed commit, run `git push --force-with-lease=<branch>:<remote sha> origin <branch>`. `<remote sha>` is the last commit of the branch that you pushed or pulled. With this lease, the push fails when someone else pushed after `<remote sha>`. Always give that SHA. A background fetch, which an IDE can do, moves `origin/<branch>`, and a lease without a SHA trusts it.

Before the rewrite, make sure that your branch holds `<remote sha>` (`git merge-base --is-ancestor <remote sha> HEAD`). Also make sure that the remote branch is at `<remote sha>`: `git ls-remote origin refs/heads/<branch>` prints that SHA. When it prints another SHA, do not rewrite, and tell the user. Push any other change with a plain `git push`.

GitHub decides **per push, not per commit** whether a push skips CI: it reads the skip marker off the head commit of the push. A marked head suppresses every workflow for that push, including the `pull_request` event when the PR is opened at that tip. To skip CI, write a marker as a literal token on its own line at the end of the message:

```
<commit subject>

[skip ci]
```

GitHub reads these bracket markers anywhere in the message:

- `[skip ci]`
- `[ci skip]`
- `[no ci]`
- `[skip actions]`
- `[actions skip]`

GitHub also reads a `skip-checks: true` trailer, with or without the space, as the last line after two empty lines, which only `git commit --cleanup=verbatim` keeps. A commit message that only names a bracket marker skips CI too. Write "skip-ci directive" instead, unless you want to skip CI.

A commit is **docs-only** when it touches only documentation (`.md` files, `README.md`, `docs/`), `CHANGELOG.md`, `openspec/`, comments, or config with no code path.

1. **The entire PR is docs-only** (every commit on the branch): mark **every** commit, including the first, so the PR runs no CI at all — this overrides rule 2. Earlier unmarked commits do not change this: mark the next commit, and leave the pushed messages as they are. `master` carries no branch protection, so a PR with zero runs still merges; if a required-status-check rule is ever added this carve-out must go (check with `gh api repos/owen2345/camaleon-cms/branches/master --jq '.protected'`).
2. **The PR contains a code change somewhere.** For each push ask: *has this PR already had a full check run on an earlier push?*
   - **No** (no PR yet, or every push so far was docs-only): omit the marker, even on a docs-only push, and say why in the message. A mixed PR gets one full run over its code, and a marked head produces none.
   - **Yes**, and every commit of this push is docs-only: include it. CI validates the tree at the head commit, and a changelog edit changes no tree an earlier run covered. A push with a code commit omits the marker. The Phase 4 changelog commit comes after the PR exists, so it is normally this case. The condition is *no run yet*, not *last commit*.
3. **Consequences to plan for.** A marked push moves the PR head without a run and leaves the passing checks on the previous SHA; fine while `master` has no required checks, re-trigger only if that changes. If you pushed a docs-only commit *without* the marker by mistake, cancel the now-stale runs on the *previous* SHA, not the new ones. Push a marked docs-only commit only once GitHub has created the run for the code push before it (`gh run list --branch <branch>`): a marked push landing seconds after a code push supersedes that push's `pull_request` event before its run exists, and the code gets no run at all.
4. **Never mark a release PR.** The Release workflow refuses a commit with no successful `current_support.yml` and `audit.yml` runs, and a version bump is a code change anyway. See `docs/releasing.md`.

---

## Phase 4: PR Submission & Maintenance

1. **PR description.** Required: a **What and Why** summary and one sentence of **User-Visible Impact** (or "None"). Not allowed: a Files Changed section, test or example counts, verification logs or commands, commit SHAs or history references, and any evolution narrative — describe the PR's net what/why/how as it now stands, and when commits are added later fold their substance into the description instead of appending follow-up or review-history sections.

2. **Metadata maintenance.** A change to setup, test or CI commands updates every document that states the command, in the same PR.

3. **Changelog.** After creating the PR, commit an entry under `## Unreleased` that links it:

    ```
    - **Security fix:** Fix mass assignment and open redirect vulnerabilities in SitesController, [#1152](https://github.com/owen2345/camaleon-cms/pull/1152)
    ```

    The entry is a lookup target for someone deciding whether an upgrade affects them, not a narrative; the reasoning lives in the PR description. The **entire entry must not exceed 500 characters**, PR link and reporter credit included, and it does not restate the root cause, the code path, the attack mechanics or the design rationale. Keep a **Breaking changes** list inline only for what the reader must act on or will observe: two to four bullets, one or two sentences each, *what changed for the reader*, never *why*.

    Everything else an upgrader must do or know lives in the release's upgrade guide, `docs/upgrading-to-<version>.md`: operator actions with copy-paste commands, observable behavior changes, notes for theme and plugin developers. Each released version's CHANGELOG section carries a single banner linking the guide (see the `## [2.9.3] …` section), and every entry whose notes moved ends with a link to its guide section anchor, e.g. `[Upgrade notes](docs/upgrading-to-<version>.md#sessions--login)`. Mid-cycle, before the guide exists, draft an upgrader note inline under a **Notes for upgraders** bullet; the release step consolidates those (`docs/releasing.md` Step 1). Once `docs/upgrading-to-<version>.md` exists mid-cycle, new and existing unreleased entries put their detail there and keep only the one-line action plus the anchor link. Before committing, re-read the entry as someone who has never seen the PR: anything that would not change what they do belongs in the PR description or the upgrade guide instead.

4. **Archive the OpenSpec change before merge.** If the work was planned with OpenSpec, run `/opsx:archive` on the branch and commit the result as part of the PR: it syncs the delta specs into `openspec/specs/<capability>/spec.md` and moves the change to `openspec/changes/archive/YYYY-MM-DD-<name>/`. `master` never carries a completed-but-unarchived change, and every box in `tasks.md`, the archive task included, is checked before the branch merges.

5. **Quality gate.** Self-audit against `docs/ai/criteria.md` before completion.
