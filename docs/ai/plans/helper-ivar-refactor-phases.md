# Helper ivar refactor phases (canonical plan)

See also: `docs/ai/plans/helper-ivar-refactor-master-plan.md` (long-lived umbrella plan).
Release tracking: `docs/ai/plans/releases/2.9.3.md`.

## Scope
Progressive removal of `Rails/HelperInstanceVariable` helper state patterns, with behavior-safe migration to `CurrentRequest` and explicit local/context state passing.

## Status
- Phase 1: merged
- Phase 2: merged
- Phase 3: merged
- Phase 4: planned/in progress
- Phase 5: queued

## Phase 4 plan

### Target files
- `app/helpers/camaleon_cms/session_helper.rb`
- `app/helpers/camaleon_cms/short_code_helper.rb`
- `app/helpers/camaleon_cms/comment_helper.rb`

### Approach
1. Session helper
   - remove helper ivar memoization/writes (`@cama_current_user`, `@user` patterns)
   - use request-scoped `CurrentRequest` where state must persist within a request
   - preserve login/logout/auth redirect behavior
2. Shortcode helper
   - replace shortcode registry ivars (`@_shortcodes`, `@_shortcodes_template`, `@_shortcodes_descr`)
   - preserve registration and rendering semantics
3. Comment helper
   - remove `@post` helper ivar dependency
   - pass required post context explicitly, keep rendered output behavior
4. Specs
   - add/update helper specs for session, shortcode, and comment helpers
5. Cleanup
   - remove Phase 4 helper exclusions from `.rubocop_todo.yml` once compliant

### Verification
- `(cd spec/dummy && bin/rails zeitwerk:check)`
- `bin/rubocop -A`
- `bin/rspec`

### Execution kickoff
- Branch created from latest `master`: `fix/phase-4-session-shortcode-comment-helpers`
- Baseline checks run:
  - `(cd spec/dummy && bin/rails zeitwerk:check)` ✅
  - `bin/rubocop ... --only Rails/HelperInstanceVariable` on Phase 4 helper files: one remaining offense in `comment_helper.rb` (`@post`) ❌
  - `bin/rspec spec/helpers/short_code_helper_spec.rb` ✅ (7 examples, 0 failures)
- Existing spec coverage snapshot:
  - `short_code_helper`: present
  - `session_helper`: missing dedicated helper spec
  - `comment_helper`: missing dedicated helper spec
- Refactor order selected:
  1. `session_helper`
  2. `short_code_helper`
  3. `comment_helper`

### Phase 4 progress update
- Completed refactors:
  - `session_helper`: removed helper ivars (`@user`, `@cama_current_user`) in favor of local flow + `CurrentRequest.user` cache, while preserving controller-context `@user` compatibility via `instance_variable_set`.
  - `short_code_helper`: migrated shortcode registry state to `CurrentRequest` (`shortcodes`, `shortcodes_template`, `shortcodes_descr`) and updated shortcode admin view to use helper accessors instead of ivars.
  - `comment_helper`: removed `@post` dependency from recursive renderer by threading explicit `post_id` with controller fallback.
- Completed specs:
  - Added `spec/helpers/session_helper_spec.rb`
  - Added `spec/helpers/comment_helper_spec.rb`
  - Kept and validated `spec/helpers/short_code_helper_spec.rb`
- Cleanup done:
  - Removed `session_helper.rb` and `short_code_helper.rb` from `.rubocop_todo.yml` `Rails/HelperInstanceVariable` exclusions.
- Verification status:
  - `(cd spec/dummy && bin/rails zeitwerk:check)` ✅
  - `bin/rubocop -A` ✅
  - `bin/rspec` ✅ (470 examples, 0 failures)
- Remaining for Phase 4:
  - commit/push + PR + changelog step.

## Phase 5 queue
- Remaining helper cleanup: `app/helpers/camaleon_cms/frontend/nav_menu_helper.rb`
- Final cleanup and CI parity

## Future follow-ups (non-blocking)
- Deterministic `Metas#get_meta` for duplicate-key rows (stable row ordering before selecting one).
- Legacy polymorphic owner compatibility hardening for demodulized `object_class` values under strict host-app defaults.
- Host app note (`camaleon_website`): harden e_shop header partial against missing nav menu slugs.

## Persistence policy
This file is the durable source of truth for this refactor stream. Session-local plan files may mirror active execution detail, but should not replace this record.
