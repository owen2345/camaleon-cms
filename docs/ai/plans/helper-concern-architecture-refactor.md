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
