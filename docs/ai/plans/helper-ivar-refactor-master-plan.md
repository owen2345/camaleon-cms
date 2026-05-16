# Refactor Plan: Replace Helper Instance Variables with Explicit State APIs

Release context: `docs/ai/plans/releases/2.9.3.md`

## Problem
`Rails/HelperInstanceVariable` currently flags 160 offenses across 16 helper modules. Most of these helpers are stateful DSL/builders (menus, SEO, shortcode, content buffers, current object/site/session memoization), so removing ivars safely requires incremental API-preserving refactors with focused specs.

## Proposed approach
Refactor in small, behavior-safe phases (max 5 files/phase), introducing explicit state containers/memoized helper methods instead of ad-hoc instance variables. Keep public helper method signatures stable, add/expand helper specs per phase, and remove files from `Rails/HelperInstanceVariable` exclusions as each phase becomes clean.

## Todos
1. **prep-baseline-and-guardrails**
   - Confirm current branch and helper offense scope.
   - Document affected helper families and target phase order.
   - Define the per-phase verification command set and rollback rule.

2. **phase-1-content-and-asset-helpers**
   - Refactor: `content_helper.rb`, `html_helper.rb`, `theme_helper.rb`, `hooks_helper.rb`.
   - Replace ivar mutations/reads with explicit per-request state accessors.
   - Add/update helper specs for content buffers and asset registries.
   - Remove these files from `.rubocop_todo.yml` exclusion.

3. **phase-2-frontend-context-helpers**
   - Refactor: `frontend/content_select_helper.rb`, `frontend/seo_helper.rb`, `frontend/site_helper.rb`, `site_helper.rb`.
   - Preserve nested block semantics (`process_in_block`) and current-site behavior.
   - Add/update specs for object-context switching and SEO settings isolation.
   - Remove these files from `.rubocop_todo.yml` exclusion.

4. **phase-3-admin-menu-taxonomy-helpers**
   - Refactor: `admin/menus_helper.rb`, `admin/post_type_helper.rb`, `admin/custom_fields_helper.rb`, `camaleon_helper.rb`.
   - Replace temporary ivar traversal stacks with explicit local/context structures.
   - Add/update specs for menu active-state resolution and taxonomy rendering.
   - Remove these files from `.rubocop_todo.yml` exclusion.

5. **phase-4-session-shortcode-and-remaining-helpers**
   - Refactor: `session_helper.rb`, `short_code_helper.rb`, `comment_helper.rb`.
   - Preserve login/session flows and shortcode registration/render behavior.
   - Add/update specs for auth lookups and shortcode registry lifecycle.
   - Remove these files from `.rubocop_todo.yml` exclusion.

6. **phase-5-final-cleanup-and-ci-parity**
   - Refactor remaining helper: `frontend/nav_menu_helper.rb`.
   - Remove final `Rails/HelperInstanceVariable` helper exclusion(s) once compliant.
   - Run full RuboCop and RSpec suite.
   - Run `(cd spec/dummy && bin/rails zeitwerk:check)`.
   - Delete `Rails/HelperInstanceVariable` exclusion block when empty.

## Notes and considerations
- Keep backwards compatibility for helper APIs used by themes/plugins.
- Avoid large all-at-once rewrites; each phase should be independently mergeable.
- Treat memoization separately from mutable builder state to avoid request leakage.
- If a helper cannot be safely refactored without wider architectural change, stop and document a focused follow-up design decision.
