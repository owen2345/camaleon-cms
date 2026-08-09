## 1. L3 — crop surfaces upload failures (commit 1)

- [x] 1.1 Red-first: crop request spec — a failing `upload_file` returns the sanitized error body
      (not an empty 200) and leaves the saved avatar meta untouched.
- [x] 1.2 `Admin::MediaController#crop`: guard `res[:error]` before the avatar write.

## 2. L16 — staged-file cleanup honors a string-keyed remove_source (commit 2)

- [x] 2.1 Red-first: `uploader_helper_spec` — a malicious upload with `{ 'remove_source' => true }`
      (string key, pre-symbolize failure path) purges the staged file.
- [x] 2.2 `cama_upload_failure`: `settings[:remove_source] || settings['remove_source']`.

## 3. L11 — operator task/generator output reaches the console (commit 3)

- [x] 3.1 The three repair rake tasks use a `report` lambda (Rails.logger + puts); the theme
      generator uses Thor `say`.
- [x] 3.2 Each rake-task spec asserts the summary/start line on stdout.

## 4. L18 — end-to-end media legacy-thumb spec (commit 4)

- [x] 4.1 Media `index` request spec: a cached `.jpg` thumb with only an on-disk `.png` renders the
      repaired `.png` URL (and not the `.jpg`) in the page body.

## 5. L7 — document the double-encoded legacy rows (commit 5, docs-only, [skip ci])

- [x] 5.1 CHANGELOG upgraders note: rows edited in the 2.9.1–2.9.2 sanitize-on-save era render
      double-encoded once and self-heal on resave; no repair task.

## 6. Verification and CI parity

- [x] 6.1 Touched specs green; rubocop clean on touched files; brakeman clean; zeitwerk clean.

## 7. OpenSpec + PR protocol

- [x] 7.1 `openspec validate fix-upload-and-task-residuals --strict` passes; archive on-branch
      (adds `media-crop-error-response`, syncs `upload-staging-lifecycle`); commit the archived
      change (no `[skip ci]` — heads the first push).
- [x] 7.2 Push, open the PR (What and Why + User-Visible Impact).
- [x] 7.3 Commit the short changelog entry referencing the PR with `[skip ci]` and push.
