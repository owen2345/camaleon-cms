# Run a plugin hook handler once per dispatch

## Why

Both hook dispatchers, the controller concern and the view helper, rescue any failure inside a
plugin's handler, reload the plugin's helpers and run the handler again, letting the second
failure escape. The retry exists for one case, a helper module not yet included into the host, but
it re-executes every other failure: a handler that raises after a partial write (an option stored,
a mail sent, a row created) performs the write twice before the caller sees the error. The view
dispatcher also raises `NoMethodError` for a handler no helper defines, where the controller one
silently skips it, so a misconfigured plugin behaves differently by dispatch path.

## What Changes

- A handler runs exactly once per dispatch. A failure inside it propagates to the caller as it is,
  with no retry.
- A handler whose helper module is not yet included is included before that single run.
- A handler that stays undefined after its helpers are loaded is skipped with a logged warning
  naming the plugin, the hook and the handler, on both dispatch paths. **BREAKING** only for a
  view rendering that relied on the `NoMethodError` a plugin's undefined handler raised; core has
  no such dependency.
- Anonymous hooks and the skip list are unchanged.

## Capabilities

### New Capabilities

- `hook-handler-dispatch`: what a registered hook handler can expect from the dispatcher, once per
  dispatch, helpers loaded on demand, an undefined handler skipped and logged, a failure reported
  to the caller unchanged.

### Modified Capabilities

None. `user-registration-hooks` specifies which hooks fire and with what payload, not how a handler
is executed.

## Impact

- Code: `app/controllers/concerns/camaleon_cms/hook_lifecycle_concern.rb` and
  `app/helpers/camaleon_cms/hooks_helper.rb` (`_do_hook` in each).
- Specs: shared examples for both dispatchers, in a concern spec and a helper spec.
- Docs: `docs/hooks.md` (Mechanism), `CHANGELOG.md`.
- Plugins and themes: a handler that failed and was retried now fails once; a handler that no
  helper defines is skipped with a warning in views as it already was in controllers.
