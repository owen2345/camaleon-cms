# Tasks: restore-runtime-compat-surfaces

## 1. Admin helper/menu surfaces

- [x] 1.1 M23 — restore the `@post_type` fallback in `post_type_list_taxonomy`; spec the 2-arg call.
- [x] 1.2 M22a — quote-aware `parse_datas`; spec single/double-quoted values.
- [x] 1.3 M22b — `sanitize` plain-String menu titles to a safe inline subset, SafeBuffer pass-through;
      spec that inline HTML renders and scripts/handlers are stripped.
- [x] 1.4 M18 — share one `CurrentRequest` store between `cf_add_model` and the placement dropdown;
      spec `cf_extra_models_for_fields`.
- [x] 1.5 M19 — alias `@_admin_menus` onto the store, `.replace` in the insert methods (both copies);
      spec store identity through an insert.

## 2. Session + frontend

- [x] 2.1 M16 — memoize a nil `cama_current_user` via `CurrentRequest.user_resolved`; keep external set;
      spec the single-resolution.
- [x] 2.2 M20 — restore the legacy-ivar read fallback in the frontend readers; invert the two specs that
      pinned its removal.

## 3. Ship

- [x] 3.1 Full `bin/rspec` (1196/0), `bin/rubocop` (429 files clean), `bin/brakeman` (0), zeitwerk.
- [x] 3.2 Archive on the branch (syncs `runtime-compat-surfaces` into `openspec/specs/`).
- [x] 3.3 Commit, push, open the PR, then add the changelog entry referencing it.
