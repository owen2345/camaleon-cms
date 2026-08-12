## Why

The admin registration flow's pre-save hook, `user_before_register`, was dispatched with `hook_run`
(which takes the target app as its first argument) instead of `hooks_run`, so it silently no-op'd and no
plugin handler ever ran — the sibling `user_before_login` broadcasts correctly. Fixing the dispatch made
the hook live, which raised a contract question this capability answers: when does it fire, and how may a
handler stop a registration? No existing capability covers the registration hook contract.

## What Changes

- `cama_register_user` broadcasts `user_before_register` via `hooks_run` before saving the user, with a
  `{ user:, params:, stop_process: false }` payload — so registered plugin/theme and anonymous handlers run.
- The hook fires only past the register captcha (the captcha check is a leading guard), unlike
  `user_before_login`, which runs regardless of the captcha and passes the result in its payload.
- A handler may veto by setting `r[:stop_process]`: the user is not saved. The handler may add its own
  error to `r[:user].errors` or perform its own response; otherwise the controller shows a generic error,
  and it never renders on top of a response the handler already performed (no `DoubleRenderError`).

## Notes

- Behavior with no registered handler is unchanged: registration proceeds exactly as before the hook was
  made live.
- Documented for plugin authors in `docs/hooks.md`.
