## Purpose

Ensure the forgot-password endpoint neither reveals whether an email is registered nor lets a caller
flood a known inbox with reset emails. A password-reset request is an unauthenticated action taking an
arbitrary email, so its response and its outbound email must not depend on, or expose, account
existence beyond what is unavoidable.

## ADDED Requirements

### Requirement: The forgot-password response does not reveal account existence

A password-reset request SHALL produce the same user-visible outcome — the same message, status, and
redirect — whether or not the submitted email matches an account. The response SHALL NOT distinguish a
registered address from an unregistered one.

#### Scenario: A known and an unknown email answer identically

- **WHEN** a reset is requested for an email that matches an account, and separately for one that does
  not
- **THEN** both requests redirect to the login page with the same neutral notice and no error

### Requirement: Reset emails are throttled per account

A reset email SHALL be sent at most once per account within a cooldown window. A further request within
the window SHALL still be accepted and answered identically, but SHALL NOT send another email; the
previously issued token remains valid for its lifetime.

#### Scenario: A second request within the window sends no second email

- **WHEN** two reset requests are made for the same account within the cooldown window
- **THEN** only one reset email is sent
