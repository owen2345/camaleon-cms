## 1. Implement

- [x] 1.1 Broadcast `user_before_register` via `hooks_run` with a `{ user:, params:, stop_process: false }` payload
- [x] 1.2 Gate the hook behind the register captcha (leading guard clause)
- [x] 1.3 Honor `r[:stop_process]` — stop without saving, return `type: :stopped`
- [x] 1.4 Controller: render the form only `unless performed?`, and add a generic error when the handler left none

## 2. Tests

- [x] 2.1 A registered handler runs with the unsaved user
- [x] 2.2 Captcha-failing attempt does not reach the hook (asserts the rendered captcha error); captcha-passing does
- [x] 2.3 A veto stops the save; a no-feedback veto shows a generic error; a handler error is shown instead
- [x] 2.4 A veto that redirected does not double-render

## 3. Docs and archive

- [x] 3.1 Document the hook (fires, captcha divergence, veto contract) in `docs/hooks.md`
- [x] 3.2 CHANGELOG entry ([#1259])
- [x] 3.3 Archive this change on the branch
