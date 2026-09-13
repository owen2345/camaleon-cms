# Run a plugin hook handler once per dispatch

## Why

Both hook dispatchers, the controller concern and the view helper, rescue any failure inside a
plugin's handler, reload the plugin's helpers and run the handler again, letting the second
failure escape. The retry exists for one case, a helper module not yet included into the host, but
it re-executes every other failure: a handler that raises after a partial write (an option stored,
a mail sent, a row created) performs the write twice before the caller sees the error. The two
dispatchers are copies that have drifted: the view dispatcher raises `NoMethodError` for a handler
no helper defines, where the controller one has silently skipped it since 2.9.3, so a hook that
gates content fails open on the controller path.

## What Changes

- A handler runs exactly once per dispatch. A failure inside it propagates to the caller as it is,
  with no retry.
- A plugin's declared helper modules are included before its handlers run, whether or not the host
  already answers a handler's name, and a module the host already includes is not included again.
- A handler is called without being looked up first, on both dispatch paths: a handler served by
  `method_missing` runs, and one that nothing defines raises `NoMethodError` to the caller.
  **BREAKING** on the controller path for a manifest that names an undefined handler, which 2.9.3
  and 2.9.4 skipped silently; views, and controllers through 2.9.2, raised.
- One dispatcher: `HookLifecycleConcern` includes `HooksHelper` and keeps only what a controller
  does differently.
- Anonymous hooks and the skip list are unchanged.

## Capabilities

### New Capabilities

- `hook-handler-dispatch`: what a registered hook handler can expect from the dispatcher, once per
  dispatch, its plugin's helpers included first, called without a lookup, a failure reported to the
  caller unchanged.

### Modified Capabilities

None. `user-registration-hooks` specifies which hooks fire and with what payload, not how a handler
is executed, and `ecosystem-plugin-bindings` specifies the receiver and the payload shape, which do
not change.

## Impact

- Code: `app/helpers/camaleon_cms/hooks_helper.rb` (`_do_hook`),
  `app/controllers/concerns/camaleon_cms/hook_lifecycle_concern.rb` (includes the helper, keeps its
  skip list and helper loading), `app/helpers/camaleon_cms/plugins_helper.rb`
  (`plugin_load_helpers` checks the object it includes into).
- Specs: shared examples for both dispatchers, in a concern spec and a helper spec, and a spec for
  `plugin_load_helpers`.
- Docs: `docs/hooks.md` (Mechanism), `docs/upgrading-to-2.9.5.md`, `CHANGELOG.md`,
  `docs/ai/ecosystem.md`.
- Plugins and themes: a handler that failed and was retried now fails once. A manifest entry naming
  a handler that nothing defines raises on controllers too: `camaleon-ecommerce` maps `on_upgrade`
  to `ecommerce_on_upgrade`, which it does not define, so its admin Upgrade action raises as it did
  through 2.9.2.
