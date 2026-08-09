# Design — filter-theme-field-value-saves

## Context

See `proposal.md` — Why. Load-bearing facts verified in code:

- `save_theme` runs four writes in order: raw `set_field_values(params[:theme_fields])`,
  `set_options`, `set_metas`, then the filtered
  `set_field_values(cama_permitted_field_options('Theme'))` — and finally fires the
  `on_theme_settings` hook. `set_field_values` deletes all existing value rows before writing
  whenever its payload is non-blank, so the last non-blank writer wins.
- Hooks execute on the controller instance (`_do_hook` → `send(hook)`), and
  `SettingsController` includes `CustomFieldsConcern` — so a theme hook handler can call
  `cama_permitted_field_options` directly. The `themes/new` handler's save branch only runs
  when a form posts `action_name=save_settings`; the stock theme-settings form posts no
  `action_name`, so the branch is reachable only through a theme's custom form markup (the
  generator template documents exactly that contract).
- The `themes/new` handler currently ends with its own `flash` + `redirect_to action: :settings`.
  That redirect is doubly broken: there is no `settings` action route, so it raises
  `ActionController::UrlGenerationError` (confirmed by the red spec); even had the route
  existed, `save_theme`'s own redirect would then raise `AbstractController::DoubleRenderError`.
  Either way the raw write has already committed. The render branch (`action_name=settings`) has
  no such collision and is left alone.
- The `themes/new` theme is duplicated, not symlinked, into the dummy app at
  `spec/dummy/app/apps/themes/new/custom_helper.rb` (identical to the gem copy). The suite loads
  the dummy copy, so the fix is applied to both files to keep them in sync and close the gap in
  the shipped gem.
- No in-repo view posts `theme_fields`; it is a legacy/ecosystem param. The ecosystem doc
  records no external binding to it, but per AGENTS.md the visible surface is a floor — so
  the param is filtered, not removed.
- `camaleon_first`'s settings handler is an empty method, the default theme registers no save
  handler, and the generator template's example handler is an empty method with a comment —
  `themes/new` is the only shipped raw save.
- The allowed-slugs lookup keys on the `'Theme'` placement scope, matching the association
  scope (`name.to_s.demodulize`) per the meta-scope-resolution capability.

## Goals / Non-Goals

**Goals:**

- Both theme-settings save paths accept only registered slugs, at parity with every other
  admin custom-field save hardened in 2.9.2.
- `theme_fields` keeps working for registered slugs (compat for any external theme posting it).
- The bundled custom-save path completes with one response.

**Non-Goals:**

- No tightening of the allowed-slugs lookup itself (it is global by `object_class`, not
  scoped by `objectid`/site — a pre-existing looseness shared by all eba56d6f call sites;
  tightening it is a separate, wider change).
- No change to the `set_options`/`set_metas` writes in `save_theme` (different storage, not
  custom-field value rows).
- No change to the last-writer-wins interplay when both `theme_fields` and `field_options`
  are posted (pre-existing; forms post one shape).
- No change to external themes' own handlers — the engine cannot rewrite them; fixing the
  bundled example fixes the pattern authors copy.

## Decisions

1. **Extend the concern with `param_key:` instead of duplicating the permit.**
   `cama_permitted_field_options(object_class, param_key: :field_options)` — both the blank
   check and the `require` read the key. The eight existing call sites are untouched by the
   default. Rejected: a separate `cama_permitted_theme_fields` method (duplicates the permit
   shape the two params share); inlining a permit in `save_theme` (drifts from the concern
   the 2.9.2 hardening centralized).
2. **Filter `theme_fields` rather than delete the param.** Zero in-repo posters, but the
   param predates the hardening and external themes may post it; filtered, registered slugs
   keep saving, so the contract narrows exactly to the 2.9.2 contract every other surface
   already has. The `present?` guard on the line drops — the filter returns `{}` for a blank
   param and `set_field_values` no-ops on blank payloads, mirroring the sibling
   `field_options` line.
3. **The bundled handler saves filtered and stops responding.** Its save branch becomes the
   same filtered call the controller uses (reachable because hooks run on the controller
   instance), and its `flash` + `redirect_to` go away — `save_theme`'s standard flash and
   redirect complete the request, which is what removes the `DoubleRenderError`. The user
   observes the standard "Theme updated successfully" notice instead of a 500.
4. **Repro-first with a `theme_settings`-only role.** The threat model gates non-admin
   capability by grantable permissions, so the specs authenticate a role granted only
   `theme_settings` (house style: the cross-site injection spec). Both raw paths are proven
   red: an unregistered slug via `theme_fields`, and one via the bundled theme's custom-save
   action (site's `_theme` option pointed at `new`, group + fields registered directly on the
   theme record). The double-render pin asserts the standard redirect — red today because the
   request raises `DoubleRenderError` (the dummy app runs `show_exceptions :none`).

## Risks / Trade-offs

- [An external theme posts `theme_fields` with slugs it never registered as fields] → those
  writes stop persisting, by design; the theme's registered fields keep working. This is the
  same narrowing every other admin surface underwent at 2.9.2.
- [An external theme's own `on_theme_settings` handler still raw-saves] → out of engine
  control; the concern's filter is one call away on the controller instance, the generator
  template's example stays clean, and the bundled example now demonstrates the filtered call.
- [Dropping the handler's redirect changes the bundled theme's post-save flash text] → the
  old text rendered only after a 500 masked it; the standard notice is the visible behavior
  the stock form already produces.

## Migration Plan

Code change deploys normally; no data changes. Rollback = revert the commit. External themes
are unaffected unless they posted unregistered slugs through `theme_fields`, which reverts to
being persisted on rollback.
