## 1. N2 — re-scan substituted before_upload bytes (commit 1, security)

- [x] 1.1 New `spec/requests/security/upload_before_upload_rescan_spec.rb`: an untrusted upload
      with a `before_upload` handler that swaps `settings[:uploaded_io]` for `<script>` bytes is
      refused with no file written (red on master); a permission-holder's swap persists;
      an unchanged IO is not re-scanned.
- [x] 1.2 `upload_file`: capture the IO before `before_upload`, re-scan the substituted IO after
      it when untrusted and the object changed, failing through `cama_upload_failure`.
- [x] 1.3 Spec green; rubocop clean on touched files; commit N2 (cite `security-capability-gating`).

## 2. M26 — non-positive size limit means unlimited (commit 2)

- [x] 2.1 New `spec/lib/camaleon_cms/upload_size_limit_spec.rb`: `cama_size_limit_error` returns
      nil for `maximum` 0 and negative with a non-empty size (red on master), still errors for a
      positive maximum below size.
- [x] 2.2 `cama_size_limit_error`: treat `maximum <= 0` as unlimited.
- [x] 2.3 Spec green; rubocop clean; commit M26.

## 3. M25 — consolidate the event patterns (commit 3, perf refactor)

- [x] 3.1 `content_security.rb`: collapse the 58 event regexes into one alternation;
      `SUSPICIOUS_PATTERNS` becomes the event pattern + element + scheme (3 total). Keep
      `UNSAFE_EVENT_PATTERNS` referenceable if externally used, or note removal.
- [x] 3.2 Extend `spec/lib/camaleon_cms/uploader_content_security_spec.rb` with representative
      event-word matches (onclick/onerror/onmouseover/onsubmit/onunload) and a non-handler
      near-miss that must pass; full content-security spec stays green (matching unchanged).
- [x] 3.3 Rubocop clean; commit M25.

## 4. M24 — on_translation on the controller upload path (commit 4)

- [x] 4.1 New `spec/lib/camaleon_cms/runtime_uploader_translation_spec.rb`: a concern host that
      responds to `ct` routes `cama_uploader_ct` through it (hook override observed); a host
      without `ct` falls back to `I18n` (red on master: concern never uses `ct`).
- [x] 4.2 `runtime_uploader_concern.rb`: override `cama_uploader_ct` to dispatch to `ct` when
      `respond_to?(:ct)`, else `super`.
- [x] 4.3 Spec green; rubocop clean; commit M24 (amends `uploader-implementation-parity`).

## 5. M28 — restart-requirement doc (commit 5, docs-only, [skip ci])

- [x] 5.1 CHANGELOG note: dropping a plugin/theme folder then activating it needs a restart
      (#1163 behavior).

## 6. Verification and CI parity

- [x] 6.1 Full `bin/rspec` suite green.
- [x] 6.2 `bin/rubocop` clean, `bin/brakeman --no-pager` clean,
      `(cd spec/dummy && bin/rails zeitwerk:check)` clean.

## 7. OpenSpec + PR protocol

- [x] 7.1 `openspec validate harden-upload-rescan-and-limits --strict` passes; archive on-branch
      (syncs the three modified capabilities); commit the archived change (no `[skip ci]` — heads
      the first push).
- [x] 7.2 Push, open the PR (What and Why + User-Visible Impact; protocol constraints), first
      push runs CI.
- [x] 7.3 Commit the short changelog entry referencing the PR with `[skip ci]` and push.
