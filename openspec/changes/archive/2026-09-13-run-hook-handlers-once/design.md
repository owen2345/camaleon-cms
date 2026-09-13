## Context

See proposal.md. `_do_hook` existed twice, in `CamaleonCms::HookLifecycleConcern` for controllers
and `CamaleonCms::HooksHelper` for views, as copies that had drifted. Both wrapped the `send` in
`begin`/`rescue StandardError`, called `plugin_load_helpers(plugin)` in the rescue and sent again,
but the concern guarded that retry with `respond_to?(hook, true)` and the helper did not; the guard
arrived with the concern in 2.9.3, and before it controllers used the helper's dispatcher. A
controller includes both modules, and the concern's copy shadowed the helper's.
`plugin_load_helpers` includes each declared helper module into the host class (concern) or the
host's singleton class (helper, through ActiveSupport's `Kernel#class_eval`). Anonymous hooks are
called outside that block and never retried.

## Goals / Non-Goals

**Goals:**

- One dispatch on both paths: include the plugin's helpers, call each handler once, let any failure
  through.

**Non-Goals:**

- Wrapping the admin category and post type saves and their hooks in a transaction (a semantics
  change for every hook on those paths; separate change).
- Registering plugin helpers for views once at class load instead of per dispatch: `HtmlMailer` and
  Draper contexts built outside a request dispatch hooks with no such registration.

## Decisions

1. **Include the helpers first, then call once.** `plugin_load_helpers(plugin)` runs before a
   plugin's handlers, whatever `respond_to?` says, and each handler is sent once with no rescue.
   `respond_to?` cannot tell whether the helper is still missing: the host can answer the name with
   a method of its own (`Kernel#format`), and Draper's `HelperProxy`, once it has forwarded a name,
   answers it on every later proxy while the view context lacks the method. Alternative: keep the
   rescue and narrow it to `NoMethodError` naming the handler; it still re-runs a handler whose own
   code raised such an error, which is the double execution being removed.
2. **A handler nothing defines raises, on both paths.** Nothing is looked up before the call, so a
   handler served by `method_missing` runs and one that nothing defines raises `NoMethodError` like
   any failing handler. Views always did; controllers did through 2.9.2. A gate hook, such as the
   password gate on `post_the_content` and `post_the_excerpt`, `post_can_visit` or `filter_post`,
   then fails closed. Alternative: skip it with a warning on both paths; a missing gate handler then
   serves what it would have held back, and the warning repeats on every dispatch.
3. **One dispatcher.** `HookLifecycleConcern` includes `HooksHelper`, as `SessionRuntimeConcern`
   includes the session and email helpers, and overrides only what a controller does differently:
   `hook_skip_list` honours the legacy `@_hooks_skip` ivar and `plugin_load_helpers` includes into
   the controller class. `_do_hook` reaches both through method calls and reads no ivar itself.
4. **The loader checks the object it includes into.** `PluginsHelper#plugin_load_helpers` skips a
   helper the object already `is_a?`; checking only `self.class` never saw its own singleton
   include, so each call included the module and ran its `included` hook again.
5. **Shared examples, two thin specs.** The contract is one; the concern spec and the helper spec
   include the same shared examples, through the public `hook_run`, with a host class built per
   example so helper inclusion never leaks between examples.

## Risks / Trade-offs

- [A plugin relied on the retry to succeed on the second attempt] → only a helper-not-yet-included
  failure was ever fixed by the retry, and the helpers are now included before the first run.
- [A manifest names a handler nothing defines on a hook fired from a controller] → it raises
  `NoMethodError` again, as through 2.9.2. `camaleon-ecommerce`'s `on_upgrade` →
  `ecommerce_on_upgrade` is the surveyed case: its admin Upgrade action raises while the plugin keeps
  working (`docs/ai/ecosystem.md`, `docs/upgrading-to-2.9.5.md`).
- [A plugin's helpers are included on the first dispatch of any of its hooks, not only for a missing
  handler] → a view, decorator helper or mailer gains them once per object, as it did on its first
  failing dispatch before; each later dispatch costs a constant lookup and an `is_a?`.
