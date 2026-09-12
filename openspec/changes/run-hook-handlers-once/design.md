## Context

See proposal.md. `_do_hook` exists twice on purpose: `CamaleonCms::HookLifecycleConcern` for
controllers (it honours a legacy `@_hooks_skip` ivar) and `CamaleonCms::HooksHelper` for views
(kept ivar-free). Both wrap the `send` in `begin`/`rescue StandardError`, call
`plugin_load_helpers(plugin)` in the rescue and `send` again; the concern guards the retry with
`respond_to?(hook, true)`, the helper does not. `plugin_load_helpers` includes each declared helper
module into the host class (concern) or the host's singleton class (helper, through ActiveSupport's
`Kernel#class_eval`). Anonymous hooks are called outside that block and never retried.

## Goals / Non-Goals

**Goals:**

- The same dispatch semantics on both paths: load helpers when the handler is missing, run once,
  let a failure through, skip and warn when the handler cannot be found.

**Non-Goals:**

- Merging the two dispatchers into one module (a refactor with its own ivar-compatibility
  question; separate change).
- Wrapping the admin category and post type saves and their hooks in a transaction (a semantics
  change for every hook on those paths; separate change).

## Decisions

1. **Check before dispatch instead of rescue after.** `plugin_load_helpers(plugin)` runs only when
   `respond_to?(hook, true)` is false, then the handler is sent once. The rescue is gone, so the
   only thing that can run a handler twice, the dispatcher, no longer does. Alternative: keep the
   rescue and narrow it to `NoMethodError` naming the handler; it still re-runs a handler whose own
   code raised a `NoMethodError`, which is the double execution being removed.
2. **Skip with a warning when still undefined.** The concern already skipped silently; the helper
   raised. A warning at `Rails.logger.warn` naming hook, plugin and handler is the loud-enough
   signal for a misconfigured plugin without failing every page that renders. Alternative: raise
   on both paths, which turns one plugin's missing method into a site-wide outage.
3. **Shared examples, two thin specs.** The contract is one; the specs include the same shared
   examples for each module, with a host class built in the example so helper inclusion never
   leaks between examples.

## Risks / Trade-offs

- [A plugin relied on the retry to succeed on the second attempt] → only a helper-not-yet-included
  failure was ever fixed by the retry, and that case is now handled before the first run.
- [A view relied on the `NoMethodError` of an undefined handler] → none in core or the surveyed
  ecosystem; the controller path already skipped, so a plugin broken this way was already partly
  silent.
