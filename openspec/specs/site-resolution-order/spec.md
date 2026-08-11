# site-resolution-order Specification

## Purpose

Define the precedence `SiteHelper#current_site` follows — explicit argument, `$current_site` global,
caller-set `@current_site`, memoized `CurrentRequest.site`, and only then computation from the
installed sites or the request host — so a caller with no request can pin the site explicitly. The
caller-set slot sits above the memoized site on purpose: a mailer or background delivery on a
multisite install has no request to fall back on, and an in-request delivery for another site must
resolve against the site the sender assigned, not the request's. Assigning `@current_site` writes
through to `CurrentRequest.site`.

## Requirements
### Requirement: current_site honors a caller-set @current_site before the memoized site
`SiteHelper#current_site` SHALL resolve the current site in precedence order: an explicit `site`
argument, then the `$current_site` global, then a caller-set `@current_site` instance variable, then the
memoized `CurrentRequest.site`, and only otherwise compute it from the installed sites or the request
host. A caller-set `@current_site` SHALL be returned and written through to `CurrentRequest.site`, and
SHALL take precedence over an already-memoized `CurrentRequest.site`.

#### Scenario: A background sender sets @current_site with no request
- **WHEN** `current_site` is called on a multisite install with `CurrentRequest.site` blank, no request
  available, and `@current_site` assigned
- **THEN** it SHALL return the assigned site without raising, and set `CurrentRequest.site` to it

#### Scenario: @current_site overrides the memoized site
- **WHEN** `@current_site` is set for one site while `CurrentRequest.site` already holds another
- **THEN** `current_site` SHALL return the `@current_site` site

### Requirement: Multisite mail sends without a request
Sending mail through `HtmlMailer` SHALL resolve its site from the `current_site` passed to `sender`,
without requiring a request, so background and multisite deliveries do not raise.

#### Scenario: HtmlMailer builds on a multisite install
- **WHEN** `HtmlMailer.sender` is called with a `current_site` on a multisite install and no request
- **THEN** the message SHALL build without raising and resolve its theme and hooks against that site

