# Phase 6G: Concern decomposition cleanup

## Problem
`RuntimeStateConcern` became a large mixed concern (shortcodes, html/assets, content, theme, captcha internals, admin menu runtime, comment defaults, uploader pipeline), and `SessionRuntimeConcern` mixes session/auth flow with captcha attack helpers and email methods. This reduces readability and concern discoverability.

## Goal
Split runtime concerns back into focused modules with clear ownership while preserving behavior and existing call signatures.

## Scope
- `app/controllers/concerns/camaleon_cms/runtime_state_concern.rb`
- `app/controllers/concerns/camaleon_cms/session_runtime_concern.rb`
- `app/controllers/camaleon_cms/camaleon_controller.rb`
- Relevant concern specs and architecture plan docs

## Findings (branch vs `master`)
1. `RuntimeStateConcern` absorbed method groups historically separated in helpers:
   - `ShortCodeHelper`
   - `HtmlHelper`
   - `ContentHelper`
   - `ThemeHelper`
   - `CaptchaHelper` (captcha image internals)
   - `Admin::MenusHelper`
   - `CommentHelper`
   - `UploaderHelper`
2. `SessionRuntimeConcern` now includes captcha attack helpers (`cama_captcha_*`, `captcha_verify_if_under_attack`) that are better isolated from auth/session flow.
3. Existing helper modules still exist, so extraction must avoid behavior drift and call-site breakage.

## Implementation checklist
1. **Boundary contract**
   - Finalize ownership map for all methods in `RuntimeStateConcern` and `SessionRuntimeConcern`.
   - Keep public method names/signatures stable.

2. **Session captcha split**
   - Extract captcha attack/session methods from `SessionRuntimeConcern` into a dedicated concern.
   - Wire concern includes so existing controllers keep resolving methods without change.

3. **Runtime shortcode/theme split**
   - Move shortcode and theme-asset-related methods into focused concern(s).
   - Preserve aliases and shortcode behavior.

4. **Runtime html/content split**
   - Move html asset-library state and content before/after state into dedicated concern(s).
   - Keep `CurrentRequest` keys and hook order unchanged.

5. **Runtime admin menu split**
   - Move admin menu runtime methods (and tightly coupled comment helper payload logic if needed) into dedicated concern(s).
   - Preserve admin sidebar/menu behavior.

6. **Runtime uploader split**
   - Move uploader/image/download pipeline methods into dedicated concern.
   - Preserve URL validation, suspicious-content checks, and size/format validation behavior.

7. **Controller wiring + docs**
   - Replace monolithic runtime include with focused concern includes in `CamaleonController`.
   - Update `docs/ai/plans/helper-concern-architecture-refactor.md` Phase G contract notes.

8. **Specs + verification**
   - Add/update concern coverage where ownership changes.
   - Run:
     - `(cd spec/dummy && bin/rails zeitwerk:check)`
     - `bin/rubocop -A`
     - `bin/rspec`

## Constraints
- Architecture-only refactor (no feature expansion).
- Apply Step-0 cleanup before structural edits in files >300 LOC.
- Keep execution phased and reviewable.
