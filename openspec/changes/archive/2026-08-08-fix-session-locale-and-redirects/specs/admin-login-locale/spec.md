## Purpose

Localize the pre-authentication admin session pages (login, register, forgot-password) from the
site's configured languages, honoring an explicit `?locale=` request only when the site offers it.

## ADDED Requirements

### Requirement: Session pages localize from the site's languages

The admin session pages rendered before authentication (login, register, forgot-password) SHALL
resolve `I18n.locale` from the current site's configured languages: the site's first configured
language by default. Sites whose first language is not the host application's default locale MUST
NOT render these pages in the host default.

#### Scenario: Non-English site renders its own language

- **WHEN** a site's configured languages are `[es, en]` and a visitor opens `/admin/login`
- **THEN** the page renders with Spanish translations

#### Scenario: Site without configured languages uses the host default

- **WHEN** a site has no stored language configuration
- **THEN** the session pages render in the host application's default locale

### Requirement: Explicit locale requests are availability-guarded

A `?locale=` query parameter SHALL select the page locale only when the site's configured
languages include that locale. Unknown, unoffered, or malformed values SHALL fall back to the
default resolution silently — the request MUST NOT raise (`I18n::InvalidLocale`) or produce a
server error.

#### Scenario: Offered locale is honored

- **WHEN** a site's configured languages are `[es, en]` and a visitor opens `/admin/login?locale=en`
- **THEN** the page renders with English translations

#### Scenario: Unoffered locale falls back

- **WHEN** a site's configured languages are `[es]` and a visitor opens `/admin/login?locale=de`
- **THEN** the page renders with Spanish translations
- **AND** the response is not a server error

#### Scenario: Non-scalar locale parameter falls back

- **WHEN** a visitor opens `/admin/login?locale[]=en` (or any other non-scalar `locale` value)
- **THEN** the page renders in the site's first configured language
- **AND** the response is not a server error

### Requirement: Frontend language choice stays out of admin session pages

The frontend visitor language stored in `session[:cama_current_language]` SHALL NOT influence the
admin session pages' locale.

#### Scenario: Frontend session language does not leak

- **WHEN** a visitor's frontend session carries a language different from the site's first
  configured language and the visitor opens `/admin/login` without a `?locale=` parameter
- **THEN** the page renders in the site's first configured language
