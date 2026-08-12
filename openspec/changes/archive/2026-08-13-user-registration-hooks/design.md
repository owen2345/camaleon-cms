# Design

## D1. Dispatch: broadcast, not target

`hook_run(target, name, params)` runs one app's handler; `hooks_run(name, params)` broadcasts to every
enabled app plus anonymous hooks. Registration must broadcast, so it uses `hooks_run` — matching
`user_before_login`/`user_after_register`. The old `hook_run('user_before_register', r)` passed the hook
name where the target app belongs, so `_do_hook` returned early (a String has no `['hooks']`) and nothing
ran.

## D2. Captcha gate precedes the hook

The register-captcha check is a leading guard, so `user_before_register` does not fire for captcha-failing
attempts. This diverges from `user_before_login`, which runs the hook even on a failed captcha and hands it
the result as `captcha_validate`. The divergence is intentional (a signup blocked at the captcha should not
run per-attempt hook work), and documented so a handler ported between the two hooks is not surprised.
Verifying the captcha at the gate also consumes the single-use challenge before the hook; a subsequent veto
therefore "burns" a solved captcha, which is harmless because the re-rendered form issues a fresh one.

## D3. Veto contract

`r[:stop_process]` mirrors `user_before_login`'s veto flag, but the two flows own the response differently:
login `return`s and expects the hook to have redirected; registration re-renders the form. So the register
veto contract is: the handler stops the save by setting the flag, and communicates by adding to
`r[:user].errors` or performing its own response. The controller renders the form only `unless performed?`
(so a handler that redirected is not double-rendered) and adds a generic error only when the handler left
none — so a veto is never a silent no-feedback re-render.
