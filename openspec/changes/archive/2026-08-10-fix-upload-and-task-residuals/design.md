# Design — fix-upload-and-task-residuals

## Context

Five independent regression-audit lows, batched as the uploads/tasks residual PR. Load-bearing
facts:

- `upload_file` returns the parsed file hash (with `url`) on success and `{ error: ... }` (no
  `url`) on failure. `crop` was the only caller reading `res['url']` without an error guard.
- `cama_upload_failure` is the shared cleanup seam (RuntimeUploaderConcern + UploaderHelper). It is
  first called at the malicious-content check, which runs BEFORE `settings.to_h.deep_symbolize_keys`
  — so at that call site the settings keys are whatever the caller passed.
- The three repair rake tasks and the theme generator predate the `orphaned_comments` precedent
  (#1224), which logs a summary AND `puts` it so a terminal operator sees the result.
- The M27 page seam (#1242) mutates the loaded relation page in place; the view iterates the same
  page. This was verified at review but had no committed end-to-end guard (unit specs pass `.to_a`).

## Goals / Non-Goals

**Goals**

- Make `crop` fail like its sibling error paths (visible message, no nil avatar write).
- Make staged-file cleanup independent of the caller's key form.
- Make operator-run tasks/generators print to the console.
- Guard the M27 rendered-thumb behavior end to end.

**Non-Goals**

- No repair task for L7's double-encoded rows: a blanket re-encode cannot tell a user's literal
  `&amp;` from a sanitize-era artifact, is not idempotent, and each row self-heals on resave.
  Document only (maintainer decision).
- No change to the crop success response shape or status codes — `crop` keeps its plain-text 200
  convention (its other error paths already render a plain-text message).

## Decisions

1. **L3: guard `res[:error]` before the avatar write.** Matches the two existing error returns in the
   same action (`render plain: helpers.sanitize(...)`), so the avatar flow gets a message instead of
   an empty body, and the saved avatar meta is left untouched on failure.
2. **L16: read both key forms in the seam** (`settings[:remove_source] || settings['remove_source']`)
   rather than symbolizing earlier in `upload_file`. The seam is the shared invariant; hardening it
   fixes every caller, present and future, in one place. Rejected: moving the symbolize call above
   the first scan (fixes only that one call site, leaves the seam fragile).
3. **L11: `report` lambda (log + puts) in tasks; `say` in the generator.** Keeps the log record
   (matching `orphaned_comments`) while giving the operator console output; the generator is a Thor
   generator, whose idiomatic operator output is `say`.
4. **L18: request-level guard.** A record with a cached `.jpg` thumb and only an on-disk `.png` is
   rendered; the spec asserts the page contains the `.png` and NOT the `.jpg`, so a regression that
   stops the in-place mutation reaching the view fails the suite.

## Risks / Trade-offs

- [L3 returns a 200 with the error message] → consistent with the action's other error paths; the
  avatar flow already handles a plain-text response there.
- [L11 prints per-row lines to stdout] → these are manual repair/generator runs, where console
  output is the point; automated callers do not run them.

## Migration Plan

Code + specs + a changelog note; no schema or data changes. Deploy normally; rollback = revert the
commits.
