## ADDED Requirements

### Requirement: The registration pre-hook fires before the user is saved

`cama_register_user` SHALL broadcast the `user_before_register` hook via `hooks_run` — reaching every
installed plugin/theme handler and any anonymous hook — before the registering user is saved, with a
payload carrying the unsaved `user`, the request `params`, and `stop_process: false`. (The hook was
previously dispatched with `hook_run` in a form that silently no-op'd, so it never fired.)

#### Scenario: A registered handler runs with the unsaved user

- **WHEN** account registration is permitted and a `user_before_register` handler is registered
- **THEN** the handler runs before the save, receiving the unsaved user in the payload

### Requirement: The registration pre-hook fires only past the register captcha

When the register captcha is enabled, `user_before_register` SHALL NOT fire for an attempt that fails the
captcha; such an attempt SHALL return a captcha error before the hook runs. When the captcha passes (or is
disabled), the hook SHALL fire. This differs from `user_before_login`, which runs its hook regardless of
the captcha result and passes that result in the payload; `user_before_register` does neither.

#### Scenario: A captcha-failing attempt does not reach the hook

- **WHEN** the register captcha is enabled and the submitted captcha is missing or wrong
- **THEN** registration returns a captcha error and the `user_before_register` hook does not run

#### Scenario: A captcha-passing attempt reaches the hook

- **WHEN** the register captcha is enabled and correctly solved
- **THEN** the `user_before_register` hook runs

### Requirement: A handler may veto the registration

A `user_before_register` handler SHALL be able to veto the registration by setting `r[:stop_process]`; the
registration SHALL stop without saving the user. The handler MAY surface its own reason by adding to
`r[:user].errors` or by performing its own response (render/redirect); when it does neither, the flow SHALL
show a generic error, and SHALL NOT render on top of a response the handler already performed.

#### Scenario: A veto stops the save

- **WHEN** a `user_before_register` handler sets `r[:stop_process]`
- **THEN** the user is not created and the registration form is re-shown

#### Scenario: A veto without its own feedback shows a generic error

- **WHEN** a vetoing handler adds no error of its own and performs no response
- **THEN** the re-rendered form shows a generic "registration could not be completed" error

#### Scenario: A veto that took over the response is not double-rendered

- **WHEN** a vetoing handler issues its own redirect (or render) and then vetoes
- **THEN** the flow does not render again on top of it (no DoubleRenderError)
