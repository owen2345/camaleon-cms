# Workflows

## Phase 1: Branch Initialization (MANDATORY)
**You must perform these steps before writing any code:**
1.  **Sync:** Ensure you are on the latest `master`.
2.  **Branch:** Create a new branch: `git checkout -b <type>/<brief-description>`.
  *   *Protocol:* Announce the branch name to the user immediately.
3.  **Mechanical Check:** Read `docs/ai/mechanical_overrides.md` to identify if this task requires "Step-0 Clean-up."

## Phase 2: Execution & CI Parity
- **Testing:** Commands live in `docs/ai/testing.md`. You MUST run relevant tests before proposing a PR.
- **Security & Lint:** Your code must pass these local checks to match CI:
  - `bin/brakeman --no-pager`
  - `bin/rubocop -A` (Auto-correct only what you touched)

## Phase 3: PR Submission Protocol
**When you are ready to submit, you must generate a description following these STRICT negative constraints:**
- **NO** `Files Changed` section.
- **NO** Test failure/example counts.
- **NO** Verification logs/commands.
- **NO** Commit SHAs or history references.
- **REQUIRED:** One sentence on **User-Visible Impact** (or state "None").
- **REQUIRED:** A "What and Why" summary.

## Task Lifecycle Triggers
- **Before Domain Work:** Check `docs/ai/knowledge/` and `docs/ai/decisions/`.
- **During Work:** Verify or contradict existing hypotheses in the decision journal.
- **Before Completion:** Self-audit against `docs/ai/quality/criteria.md`.

## Vulnerability Triage Protocol (Hypothesis-Driven)

**Objective:** Verify that a reported vulnerability is "Legit" (exploitable or present in our specific context) before acting.

### Step 1: Proof of Presence
Do not assume the report is correct. Run these commands to find the "Smoking Gun":
- **For Dependency Reports:** Run `bundle exec bundle-audit check`. Does the reported gem/version match our `Gemfile.lock`?
- **For Code/Static Reports:** Run `bin/brakeman -z --only-files <file_path>`. Does Brakeman flag the specific line mentioned?
- **Manual Grep:** If no tool finds it, `grep -r` the codebase for the vulnerable pattern.

### Step 2: Legitimacy Verdict
State your finding to the user. You must pick one:
1.  ✅ **Legit:** "Confirmed. We are using version X; version Y is required." or "Confirmed. Brakeman flags this as a High risk SQLi."
2.  ❌ **False Positive:** "The report is for a library we don't use." or "The code pattern exists but is in a test-only file not reachable in production."
3.  ⚠️ **Unverifiable:** "I see the code, but my tools cannot confirm the risk. I recommend a deeper manual audit."

### Step 3: Authorization to Proceed
**ONLY if the verdict is ✅ Legit:**
1. Create a branch following the `security/` prefix (e.g., `security/fix-sqli-in-comments`).
2. Follow the standard "Goal-Driven Execution": **Write a failing test that reproduces the risk** (if possible) before applying the fix.

## Metadata Maintenance
If you change setup, test, or CI commands, you are **REQUIRED** to update:
1. `AGENTS.md`
2. `docs/ai/testing.md` (if applicable)
3. `README.md`
   *All updates must be part of the same PR.*
