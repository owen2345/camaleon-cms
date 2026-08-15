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

**Security remedies are rejections, not transforms.** When a fix must stop dangerous content from an untrusted user, the remedy is a save-time refusal with an error naming the problem — never sanitizing, stripping, or escaping-away what the author wrote. Stored content must always equal authored content, so the frontend may render it verbatim. Do not add render-time sanitization either. Trusted skips (admins, the relevant dedicated permission), fail-closed defaults, and explicit server-side opt-outs (`unfiltered_content!`-style bang methods) follow `docs/security/permissions.md`; the shared detector for authored markup is `CamaleonCms::UnsafeMarkup`. Pre-existing stored data is reported (`rake camaleon_cms:security:scan_content` for authored content, `rake camaleon_cms:security:scan_uploads` for stored media), never rewritten. Positions the platform already escapes by default (plain `<%= %>` output of non-markup values) are not "escaping as a remedy" — they simply carry no gate.

Two boundaries on that rule, both of which have been crossed by proposals that read as reasonable:

- **The save-time decision is the only lever.** Content that passes is stored *and served* verbatim — no response header, CSP, content-disposition or separate origin constrains what a stored file does in the browser. A response header transforms nothing and acts after the save, so it slips past the letter of "reject, don't transform" while breaking it. Test any proposed control by asking whether it would constrain a *trusted* user's content; if it would, it is out.
- **Prefer the scan; a permission gate is the last resort.** Where content can be judged, the scan judges it — refusing a whole file type or format by permission is wrong there. A gate is the remedy only where no scan can reach a verdict at all (uploaded JavaScript). Never a substitute for scanning where scanning works.

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

**First: is the *entire PR* docs-only?** If every commit on the branch touches only documentation, specs (`openspec/`), `CHANGELOG.md`, or config with no code paths, mark **every** commit `[skip ci]` — including the first — so the PR runs no CI at all. Such a tree gives the code matrix nothing to validate, and `master` carries **no branch protection** (no required status checks), so a PR with zero runs still merges. This is the primary path for a documentation-, spec-, or changelog-only PR, and it overrides the one-run rule below. *(It depends on `master` staying unprotected: if a required-status-check rule is ever added, a PR with no run would be unmergeable and this carve-out must be revisited — re-check with `gh api repos/owen2345/camaleon-cms/branches/master --jq '.protected'`.)*

**Otherwise** — the PR includes a code change in some commit — decide the marker per push, not per commit, by answering one question:

> Has this PR already had a full check run on an earlier push?

- **No** — omit the marker on that push, *even if the push itself is docs-only*, and say why in the message. A mixed PR must get one full check run over its code, and a push whose head carries the marker produces none. This is the case when the branch has no PR yet, or when every push so far has been docs-only.
- **Yes** — include the marker. A second run on a docs-only change revalidates nothing. CI validates the tree at the head commit, and a `CHANGELOG.md` edit does not change any tree the earlier run already covered.

**The Phase 4 changelog commit is normally in the "Yes" branch.** It lands after the PR exists, which means an earlier push already opened the PR and triggered CI. Omitting the marker there duplicates the entire matrix to validate a Markdown edit. Do not read "the changelog commit lands last" as a reason to omit the marker — *lands last* is not the condition; *no run yet* is.

Other consequences to plan for:

- **Including the marker moves the PR head without triggering a run.** The passing checks stay attached to the previous SHA. Before merge, check whether branch protection requires checks on the head commit, and re-trigger only if it does — `master` currently has none, so no re-trigger is needed.
- **If you have already pushed a docs-only commit without the marker**, cancel the now-stale runs on the *previous* SHA, not the new ones. The PR head has moved, so the new runs are the ones that count for merge.
- **The marker matches anywhere in the message, including the body.** A commit that merely *explains* the directive will skip CI too. Write "skip-ci directive" in prose rather than the literal token — unless you are actually invoking it, in which case it belongs on its own line as shown above.
- **Never mark a release PR.** The Release workflow refuses to publish a commit that has no successful `current_support.yml` and `audit.yml` runs recorded against it, and a marker on the head of the push to `master` produces none. A version bump is a code change, so the rule above already lands a release PR in the "omit the marker" branch — keep it there. See `docs/releasing.md`.

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

    **🔴 Keep the entry short. The PR description is where the reasoning lives.** The changelog is read by someone deciding whether an upgrade affects them — not by someone auditing your analysis. A lead paragraph carrying the PR link is the whole entry for most changes; it MUST NOT exceed ~1000 characters. Do not restate the root cause, the code path, the attack mechanics, or the design rationale — every one of those is already in the PR body, one click away through the link you just added.

    Add a **Notes for upgraders** (or **Breaking changes**) list *only* for things the reader must act on or will observe: behavior that changed, output that moved, a dependency floor that was raised, data that is or is not rewritten. Two to four bullets, one or two sentences each. If a bullet explains *why* rather than *what changed for the reader*, delete it.

    The entry is a lookup target, not a narrative. Before committing it, re-read it as someone who has never seen the PR and ask what they would do differently — anything that does not change their answer belongs in the PR description instead.

4.  **Archive the OpenSpec change — before merge, not after.** If the work was planned with OpenSpec, run `/opsx:archive` **on the branch** and commit the result as part of the PR. This syncs the change's delta specs into `openspec/specs/<capability>/spec.md` and moves the change to `openspec/changes/archive/YYYY-MM-DD-<name>/`.

    Archiving is **not** a post-merge step. `master` must never carry a completed-but-unarchived change, and every box in `tasks.md` — including the archive task itself — must be checked before the branch merges. See PR [#1213](https://github.com/owen2345/camaleon-cms/pull/1213), where the archive commit precedes the merge commit on the branch.

5.  **Quality Gate:** Before completion, self-audit against `docs/ai/criteria.md`.
