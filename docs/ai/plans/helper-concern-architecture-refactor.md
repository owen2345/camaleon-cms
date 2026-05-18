# Helper/Concern Architecture Refactor (Post-Phase-5)

See also:
- `docs/ai/plans/helper-ivar-refactor-master-plan.md`
- `docs/ai/plans/helper-ivar-refactor-phases.md`

## Problem
The helper-ivar cleanup stream reduced RuboCop offenses, but the runtime architecture still mixes controller behavior into helpers and uses compatibility bridges (`instance_variable_set` / `instance_variable_get`) that keep helpers coupled to controller internals.

## Goal
Move to idiomatic Rails boundaries:
1. Helpers are view-facing only (presentation/formatting/read-only context usage).
2. Controller behavior lives in controllers and controller concerns.
3. Controllers include concerns, not broad helper modules for runtime flow.
4. Remove helper-side ivar writes/reads and implicit helper↔controller state coupling.

## Scope
- `CamaleonController`, `FrontendController`, `AdminController`
- Shared runtime modules currently implemented as helpers (`SessionHelper`, `SiteHelper`, `ThemeHelper`, `HooksHelper`, selected frontend/admin helpers)
- Plugin compatibility surfaces (`PluginRoutes.all_helpers`, hook/load paths)

## Phase A output: ownership inventory

### Current controller/runtime includes (to unwind)
- `CamaleonController` currently includes many `CamaleonCms::*Helper` modules directly for runtime behavior.
- `FrontendController` includes `CamaleonCms::Frontend::ApplicationHelper`.
- `AdminController` includes `CamaleonCms::Admin::ApplicationHelper`.
- Plugin helpers are dynamically included through `PluginRoutes.all_helpers`.

### Mixed-module ownership map

| Module | Current mixed responsibilities | Target owner |
|---|---|---|
| `CamaleonCms::SessionHelper` | auth/session cookies, redirects, login/logout, current user resolution, controller `@user` bridging | **Controller concern** for runtime/auth flows; helper surface only for view-safe predicates |
| `CamaleonCms::SiteHelper` | current site/theme resolution, request host resolution, site install/uninstall runtime tasks, helper-side `@current_site` bridging | **Controller concern** for request lifecycle + site/theme context; helper readers for view only |
| `CamaleonCms::ThemeHelper` | theme state init + breadcrumb state wiring + asset/view path helpers | split: **controller concern** for lifecycle state init; **helper** for asset/view path methods |
| `CamaleonCms::HooksHelper` | lifecycle hook orchestration + skip-list state with legacy ivar fallback | **Controller concern** for hook orchestration and skip-list state |
| `CamaleonCms::Frontend::SiteHelper` | visited-state checks with legacy ivar fallbacks | **Helper** with `CurrentRequest` readers only (remove ivar fallback) |
| `CamaleonCms::Frontend::SeoHelper` | SEO rendering plus visited/user fallback via ivars | **Helper** with explicit/current-request context only |
| `CamaleonCms::Frontend::ContentSelectHelper` | content selection DSL with `@object` fallback | **Helper** with explicit block context + `CurrentRequest` only |
| `CamaleonCms::Frontend::NavMenuHelper` | rendering/parser helper with visited-state legacy fallback | **Helper** with explicit/current-request context only |
| `CamaleonCms::CommentHelper` | recursive rendering with controller ivar fallback for post | **Helper** with explicit `post_id` only |
| `CamaleonCms::Admin::PostTypeHelper` | helper fallback to controller `@post_type` | **Helper** with explicit `post_type` argument only |
| `CamaleonCms::CamaleonHelper` | view helpers + helper-side ivar cache helper | split: keep view helpers; move cache strategy to request store/helper-local pattern without dynamic ivars |

### Compatibility constraints discovered
- Frontend themes still rely on controller-assigned ivars in templates (`@post`, `@category`, etc.); these ivars belong in controllers, not helper bridges.
- Decorators/plugins depend on admin preview locale compatibility (`cama_get_i18n_frontend` / `cama_is_admin_request?` path).
- Hook/plugin ecosystem depends on helper availability and dynamic plugin helper loading (`PluginRoutes.all_helpers`), so concern extraction must preserve callable surfaces used by hooks.

### Phase A boundary rules (to enforce in implementation)
1. No helper should call `instance_variable_set` / `instance_variable_get` for controller state bridging.
2. Helpers may read request-scoped state from `CurrentRequest` and explicit method arguments.
3. Runtime flow (redirects, cookies/session mutation, hook lifecycle dispatch) must be concern/controller-owned.
4. Controller ivars required for template compatibility are assigned in controllers only.

## Phased plan

### Phase A — Architecture inventory + ownership map
- Classify methods into:
  - controller concern responsibilities
  - view helper responsibilities
- Produce ownership map for mixed modules.
- Identify compatibility constraints (themes/plugins/decorators).

### Phase B — Extract controller concerns (foundation)
- Create concerns for:
  - request/site/theme context lifecycle
  - auth/session control flow
  - hook orchestration for controller lifecycle
  - frontend visited-state mutation
- Wire concerns into base/admin/frontend controllers.

#### Phase B implementation checklist (execution-ready)
1. `phase6b-baseline-and-guards`
   - Work from `fix/phase-6b-helper-concern-foundation`.
   - Reconfirm runtime include map in:
     - `app/controllers/camaleon_cms/camaleon_controller.rb`
     - `app/controllers/camaleon_cms/frontend_controller.rb`
     - `app/controllers/camaleon_cms/admin_controller.rb`
   - Enforce no feature expansion and no new helper ivar bridge logic.
2. `phase6b-step0-large-file-cleanup`
   - Apply Step-0 cleanup to `app/controllers/camaleon_cms/frontend_controller.rb` (>300 LOC) before structural extraction.
3. `phase6b-create-runtime-concerns`
   - Add:
     - `app/controllers/concerns/camaleon_cms/request_context_concern.rb`
     - `app/controllers/concerns/camaleon_cms/session_runtime_concern.rb`
     - `app/controllers/concerns/camaleon_cms/hook_lifecycle_concern.rb`
     - `app/controllers/concerns/camaleon_cms/frontend_visited_state_concern.rb`
4. `phase6b-wire-camaleon-controller`
   - Include new concerns in `CamaleonController`.
   - Move/route lifecycle and site-check runtime ownership into concerns with behavior parity.
   - Preserve `PluginRoutes.all_helpers` include behavior and existing hook call surfaces.
5. `phase6b-wire-frontend-admin-controllers`
   - Wire `FrontendController` and `AdminController` to concern-owned runtime paths.
   - Keep helper includes stable unless strictly required for handoff.
6. `phase6b-spec-coverage`
   - Cover concern-owned runtime behavior for auth/session redirects, hook lifecycle/skip-list behavior, and frontend visited-state propagation.
7. `phase6b-verification`
   - `(cd spec/dummy && bin/rails zeitwerk:check)`
   - `bin/rubocop -A`
   - `bin/rspec`
8. `phase6b-phase-handshake`
   - Record Phase 6B outcomes and explicit Phase 6C carryovers.

#### Phase B progress update
- Completed foundation extraction with new controller concerns:
  - `CamaleonCms::RequestContextConcern`
  - `CamaleonCms::SessionRuntimeConcern`
  - `CamaleonCms::HookLifecycleConcern`
  - `CamaleonCms::FrontendVisitedStateConcern`
- `CamaleonController` now includes concern-owned runtime flow for app lifecycle hooks and request context setup.
- `FrontendController` visited-state mutations now flow through concern writers that update `CurrentRequest` and compatibility ivars.
- `AdminController` hook lifecycle dispatch now routes through concern lifecycle helper (`run_hook_lifecycle`).
- Added concern-focused coverage:
  - `spec/controllers/concerns/camaleon_cms/session_runtime_concern_spec.rb`
  - updates in `spec/helpers/camaleon_cms/hooks_helper_spec.rb`
  - updates in `spec/controllers/camaleon_cms/frontend_controller_lookup_prefixes_spec.rb`
- Verification completed for Phase B scope:
  - `(cd spec/dummy && bin/rails zeitwerk:check)`
  - `bin/rubocop -A`
  - `bin/rspec`

##### Phase C carryovers
- Remove helper-side legacy ivar fallback reads for frontend visited/user/object context.
- Continue migration of runtime methods out of helper modules while preserving view-helper API contracts.
- Plan controller include cleanup to reduce runtime dependence on helper mixins after helper slimming lands.

#### Phase B follow-up hotfix queue
- **Issue:** Admin site settings (`/admin/settings/site`, Custom Configurations tab) can raise `Missing partial .../custom_fields/fields/` for multiple inputs (confirmed: Footer Description and Seo Site) when custom field render fallback resolves an empty field key.
- **Targeted fix scope:**
  1. Reproduce with spec coverage on admin custom field render path for both failing inputs.
  2. Normalize field key resolution in `app/views/camaleon_cms/admin/settings/custom_fields/_render.html.erb` to prevent empty partial path fallback.
  3. Preserve plugin/custom overrides (`field.get_option('render')`, `cama_custom_field_elements`).
  4. Re-run standard verification:
     - `(cd spec/dummy && bin/rails zeitwerk:check)`
     - `bin/rubocop -A`
     - `bin/rspec`

##### Phase B hotfix progress update
- Completed normalization fix in `app/views/camaleon_cms/admin/settings/custom_fields/_render.html.erb`:
  - normalized `field_key` resolution now handles string-key-backed options and safe fallback.
  - render fallback no longer builds an empty partial path (`.../fields/`).
- Added regression coverage:
  - `spec/views/camaleon_cms/admin/settings/custom_fields/_render.html.erb_spec.rb`
  - covers both failing inputs (`footer_description`, `seo_site`).
- Verification completed:
  - `(cd spec/dummy && bin/rails zeitwerk:check)`
  - `bin/rubocop -A`
  - `bin/rspec`

### Phase C — Slim helpers to presentation APIs
- Remove helper ivar mutation/access bridges.
- Convert helper state access to explicit args and read-only `CurrentRequest`.
- Keep public helper API stable where feasible.

### Phase D — Controller include cleanup
- Remove runtime `include CamaleonCms::*Helper` usage from controllers.
- Keep helper exposure view-focused via helper contracts.
- Ensure redirects/session side effects are concern-driven.

### Phase E — Frontend/admin hotspots
- Frontend: remove remaining nav/seo/content-select legacy ivar fallbacks.
- Admin: replace helper fallback reads from controller ivars with explicit params/context APIs.

### Phase F — Compatibility + deprecation
- Add narrow adapters only where ecosystem compatibility requires it.
- Document retained compatibility contracts and deprecation path.

### Phase G — Verification + documentation
- `(cd spec/dummy && bin/rails zeitwerk:check)`
- `bin/rubocop -A`
- `bin/rspec`
- Update plan/changelog/docs with final architecture contract.

## Constraints
- No feature expansion; architecture-only refactor.
- Follow Step-0 cleanup rule for files >300 LOC before structural edits.
- Execute in small phases; each phase should remain independently reviewable.
- Prefer explicit state flow over implicit ivar/module coupling.
