# Workflows

## Phase 1: Branch Initialization (MANDATORY)

Before writing any code:

1. Ensure you are on the latest `master`.
2. Create a new branch: `git checkout -b <type>/<brief-description>` using the prefixes from `AGENTS.md` (`feature/`, `fix/`, `security/`).
3. *Protocol:* Announce the branch name to the user immediately.
4. If this is a security fix, follow the **Vulnerability Triage Protocol** (Phase 2A) before writing the fix.

---

## Phase 2: Execution

### A. Vulnerability Triage Protocol (Hypothesis-Driven)
**Objective:** Verify that a reported vulnerability is "Legit" (exploitable or present in our specific context) before acting.

1.  **Step 1: Proof of Presence:** Do not assume the report is correct.
    - **For Dependency Reports:** Run `bundle exec bundle-audit check`. Does the reported gem/version match our `Gemfile.lock`?
    - **For Code/Static Reports:** Run `bin/brakeman -z --only-files <file_path>`. Does Brakeman flag the specific line mentioned?
    - **Manual Grep:** If no tool finds it, `grep -r` the codebase for the vulnerable pattern.
2.  **Step 2: Legitimacy Verdict:** State your finding to the user. You must pick one:
    - ✅ **Legit:** "Confirmed. We are using version X; version Y is required." or "Confirmed. Brakeman flags this as a High risk SQLi."
    - ❌ **False Positive:** "The report is for a library we don't use." or "The code pattern exists but is in a test-only file not reachable in production."
    - ⚠️ **Unverifiable:** "I see the code, but my tools cannot confirm the risk. I recommend a deeper manual audit."
3.  **Step 3: Authorization to Proceed:** ONLY if the verdict is ✅ Legit:
    - Write a failing test that reproduces the risk before applying the fix (rule in `AGENTS.md`; spec templates in `docs/ai/testing.md`, "Security Vulnerability Reproduction").

### B. Development
The spec-coverage and security-fix testing rules are stated in `AGENTS.md`. Test commands, helpers, and conventions live in `docs/ai/testing.md`.

### C. Refactoring Protocol
- **Step-0 cleanup:** Before any structural refactor of a file larger than 300 LOC, first remove dead code (unused methods, unused requires, debug output) and commit that cleanup separately, before the real refactor.
- **Phased execution:** Do not attempt large multi-file refactors in one pass. Break the work into explicit phases touching no more than 5 files each; run verification and wait for explicit approval before starting the next phase.

### D. CI Parity
Before pushing, your code must pass the key commands listed in `AGENTS.md` (security scan, lint, specs, zeitwerk check). Auto-correct only what you touched.

---

## Phase 3: Commit Guidelines

**🔴 MANDATORY: `[skip ci]` for Non-Code Commits**

Before EVERY commit, check: **Does this commit contain ONLY documentation, changelog, or config changes with NO code changes?**

If YES, you MUST format the commit message as:
```
<commit subject>

[skip ci]
```

**Examples of commits requiring `[skip ci]`:**
- Documentation updates (`.md` files, README, docs/)
- Changelog entries (`CHANGELOG.md`)
- Configuration files with no code path changes
- Comment-only changes

**⚠️ The marker is per-push, not per-commit.** GitHub evaluates it against the **head commit of the push**, so a `[skip ci]` commit at the tip suppresses every workflow for that push — including the `pull_request` event when the PR is opened at that tip. Push three commits ending on a docs-only one and *nothing* runs, for any of them.

**Decide the marker per push, not per commit, by answering one question:**

> Has this PR already had a full check run on an earlier push?

- **No** — omit the marker, *even on a docs-only push*, and say why in the message. Every PR must get one full check run, and a push whose head carries the marker produces none. This is the case when the branch has no PR yet, or when every push so far has been docs-only.
- **Yes** — include the marker. A second run on a docs-only change revalidates nothing. CI validates the tree at the head commit, and a `CHANGELOG.md` edit does not change any tree the earlier run already covered.

**The Phase 4 changelog commit is normally in the "Yes" branch.** It lands after the PR exists, which means an earlier push already opened the PR and triggered CI. Omitting the marker there duplicates the entire matrix to validate a Markdown edit. Do not read "the changelog commit lands last" as a reason to omit the marker — *lands last* is not the condition; *no run yet* is.

Other consequences to plan for:

- **Including the marker moves the PR head without triggering a run.** The passing checks stay attached to the previous SHA. Before merge, check whether branch protection requires checks on the head commit, and re-trigger only if it does.
- **If you have already pushed a docs-only commit without the marker**, cancel the now-stale runs on the *previous* SHA, not the new ones. The PR head has moved, so the new runs are the ones that count for merge.
- **The marker matches anywhere in the message, including the body.** A commit that merely *explains* the directive will skip CI too. Write "skip-ci directive" in prose rather than the literal token — unless you are actually invoking it, in which case it belongs on its own line as shown above.

---

## Phase 4: PR Submission & Maintenance

1.  **PR Protocol:** Generate a description following these STRICT negative constraints:
    - **NO** `Files Changed` section.
    - **NO** Test failure/example counts.
    - **NO** Verification logs/commands.
    - **NO** Commit SHAs or history references.
    - **REQUIRED:** One sentence on **User-Visible Impact** (or state "None").
    - **REQUIRED:** A "What and Why" summary.

2.  **Metadata Maintenance:** If you change setup, test, or CI commands, you are **REQUIRED** to update:
    - `AGENTS.md`
    - `docs/ai/testing.md` (if applicable)
    - `README.md`
    *All updates must be part of the same PR.*

3.  **Changelog:** After creating the PR, you MUST generate and commit a changelog entry referencing the PR:
    ```
    - **Security fix:** Fix mass assignment and open redirect vulnerabilities in SitesController, [#1152](https://github.com/owen2345/camaleon-cms/pull/1152)
    ```

4.  **Archive the OpenSpec change — before merge, not after.** If the work was planned with OpenSpec, run `/opsx:archive` **on the branch** and commit the result as part of the PR. This syncs the change's delta specs into `openspec/specs/<capability>/spec.md` and moves the change to `openspec/changes/archive/YYYY-MM-DD-<name>/`.

    Archiving is **not** a post-merge step. `master` must never carry a completed-but-unarchived change, and every box in `tasks.md` — including the archive task itself — must be checked before the branch merges. See PR [#1213](https://github.com/owen2345/camaleon-cms/pull/1213), where the archive commit precedes the merge commit on the branch.

5.  **Quality Gate:** Before completion, self-audit against `docs/ai/criteria.md`.
