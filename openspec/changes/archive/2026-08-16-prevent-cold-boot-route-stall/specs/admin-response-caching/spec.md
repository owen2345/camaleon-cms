# admin-response-caching

## Purpose

Admin pages are per-user and dynamic. They must never be served from a browser or shared cache, so a
stale render cannot reappear — for example after a server restart — until a manual reload.

## ADDED Requirements

### Requirement: Admin responses are not cacheable

Every response from an admin controller SHALL carry `Cache-Control: no-store`, so no admin page is
retained by the browser or an intermediary cache. The header SHALL be set ahead of authentication so
it applies to the pre-authentication redirect as well.

#### Scenario: An admin page is uncacheable

- **WHEN** an authenticated administrator requests an admin page
- **THEN** the response carries `Cache-Control: no-store`

#### Scenario: The pre-authentication redirect is uncacheable

- **WHEN** an unauthenticated request hits an admin page and is redirected to sign in
- **THEN** that redirect response also carries `Cache-Control: no-store`
