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

Before pushing, the four commands in `AGENTS.md` pass. Auto-correct only what you touched.

---

## Phase 3: Commit Guidelines

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
   - **Yes**: include it. CI validates the tree at the head commit, and a changelog edit changes no tree an earlier run covered. The Phase 4 changelog commit lands after the PR exists, so it is normally this case — *lands last* is not the condition, *no run yet* is.
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
