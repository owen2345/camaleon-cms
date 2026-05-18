# Helper ivar refactor phases (canonical plan)

See also: `docs/ai/plans/helper-ivar-refactor-master-plan.md` (long-lived umbrella plan).
Release tracking:
- `docs/ai/plans/releases/2.9.3.md`
- `docs/ai/plans/releases/2.10.0.md`
- `docs/ai/plans/releases/rails-7.2-plus.md`

## Scope
Progressive removal of `Rails/HelperInstanceVariable` helper state patterns, with behavior-safe migration to `CurrentRequest` and explicit local/context state passing.

## Status
- Phase 1: merged
- Phase 2: merged
- Phase 3: merged
- Phase 4: merged
- Phase 5: merged
- Phase 6 (architecture boundary refactor): in progress

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
  - completed (PR merged).

## Phase 5 queue
- Remaining helper cleanup: `app/helpers/camaleon_cms/frontend/nav_menu_helper.rb`
- Final cleanup and CI parity

### Phase 5 execution plan
1. Branch + baseline
   - Branch from latest `master` (`fix/phase-5-nav-menu-helper-cleanup`).
   - Run baseline checks for `nav_menu_helper` + existing helper specs.
2. Step-0 cleanup (mandatory for >300 LOC file)
   - `app/helpers/camaleon_cms/frontend/nav_menu_helper.rb` is 300+ LOC.
   - First pass: remove dead/unused code only (if any), no behavior change.
   - Commit Step-0 cleanup separately before structural refactor.
3. Refactor `frontend/nav_menu_helper.rb`
   - Replace `@_front_breadcrumb` with request-scoped state (CurrentRequest-backed breadcrumb store).
   - Replace direct frontend visited ivar reads (`@cama_visited_post`, `@cama_visited_category`, `@cama_visited_tag`, `@cama_visited_post_type`) with request-scoped frontend context attributes.
   - Add helper accessors (or equivalent local readers) so parsing/rendering reads from one request-state source.
   - Preserve public helper API and rendering behavior.
4. Specs
   - Extend `spec/helpers/camaleon_cms/frontend/nav_menu_helper_spec.rb` for breadcrumb and current-item detection behavior after state migration.
   - Add missing coverage for `breadcrumb_add` + `breadcrumb_draw` order and active-last-item behavior.
   - Add explicit current-state tests for `post`, `category`, `post_tag`, `post_type` parsing paths via request-scoped visited context.
5. Cleanup
   - Remove final `Rails/HelperInstanceVariable` exclusion for `frontend/nav_menu_helper.rb` from `.rubocop_todo.yml`.
6. Final verification
   - `(cd spec/dummy && bin/rails zeitwerk:check)`
   - `bin/rubocop -A`
   - `bin/rspec`
7. Ship
   - Commit/push/PR, then changelog entry referencing PR.

### Phase 5 tracked todo IDs (SQL)
- `phase5-branch-and-baseline`
- `phase5-step0-nav-menu-cleanup`
- `phase5-nav-menu-helper-refactor`
- `phase5-spec-coverage`
- `phase5-rubocop-todo-cleanup`
- `phase5-verification-and-pr`

## Phase 6 queue (canonical)
- Canonical plan: `docs/ai/plans/helper-concern-architecture-refactor.md`
- Objective: move controller/runtime responsibilities out of helpers into controller concerns and keep helpers view-facing only.
- Scope highlights:
  - remove helper-side ivar bridging (`instance_variable_set` / `instance_variable_get`)
  - replace runtime controller includes of helpers with concern includes
  - keep plugin/theme compatibility through explicit adapters where necessary

### Phase 6 progress update
- Branch: `fix/phase-6-helper-concern-architecture`
- Phase A (inventory/boundaries): completed
  - added ownership map of mixed modules (runtime concern vs view helper targets)
  - documented compatibility constraints for themes/plugins/decorators
  - defined enforceable boundary rules for implementation phases

## Future follow-ups
- Resolved during Phase 5 and no longer pending.

## Persistence policy
This file is the durable source of truth for this refactor stream.
Session-local plan files are optional mirrors and must not be treated as canonical.
