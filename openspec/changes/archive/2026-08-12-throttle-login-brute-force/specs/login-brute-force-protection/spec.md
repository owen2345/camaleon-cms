## Purpose

Pin that admin authentication is protected against brute force by a server-side, per-client-IP signal that
an attacker cannot reset by dropping the session cookie. The prior gate counted failures only in the
session, so a cookieless request never triggered the captcha and could guess passwords without limit; and
the bundled request throttle keyed on the session id too. A per-IP counter drives the captcha (soft) and a
hard lockout, and the request throttle keys on the IP.

## ADDED Requirements

### Requirement: The login captcha gate is keyed on the client IP, not only the session

Failed admin-login attempts SHALL be counted per client IP (server-side) in addition to per session, and
the captcha requirement SHALL trigger when either counter exceeds the configured threshold. Dropping or
rotating the session cookie SHALL NOT reset the requirement.

#### Scenario: A fresh session does not clear the captcha requirement

- **WHEN** enough failed logins from one IP have raised the counter over the threshold, and a client then
  presents a fresh session (no prior cookie) and submits the correct password without a captcha
- **THEN** the login is still rejected, because the per-IP counter still requires a captcha

### Requirement: An IP is hard-locked after too many failures

Once failed attempts from one IP reach the lockout threshold (configurable, defaulting to a multiple of the
captcha threshold), every admin-login and impersonation-re-auth attempt from that IP SHALL be refused with
HTTP 429 for a self-expiring cooldown window, regardless of the credentials or captcha supplied. A
successful login SHALL clear the counter.

#### Scenario: The correct password is refused while the IP is locked out

- **WHEN** an IP has exceeded the lockout threshold and then submits the correct password
- **THEN** the response is HTTP 429 and no session is established

### Requirement: The request-throttle plugin keys on the client IP

The `attack` plugin SHALL key its per-request throttle and its ban on `request.remote_ip` rather than the
session id, so a cookieless or cookie-rotating request is still counted, and it SHALL stop inserting
tracking rows once an IP is over the limit.

#### Scenario: A throttled request is recorded against the IP and inserts stop when banned

- **WHEN** requests from one IP exceed the plugin's configured limit
- **THEN** the tracking rows are keyed by that IP, the IP is banned, and no further rows are inserted while
  the ban holds
