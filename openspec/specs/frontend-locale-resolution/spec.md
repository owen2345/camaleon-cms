# frontend-locale-resolution Specification

## Purpose
Define how the frontend resolves the request locale — from the `?locale=` parameter, the
visitor's session language, and the site's configured languages — and what happens when a
request names a locale the site does not offer.

## Requirements

### Requirement: The frontend resolves its locale through a scalar-only fallback chain

The frontend SHALL resolve `I18n.locale` in order: a scalar `?locale=` parameter, the visitor's
session language (stored from a scalar `?cama_set_language=` parameter), then the site's first
configured language. Only scalar values SHALL participate: a non-scalar `locale` or
`cama_set_language` parameter (an array or hash, e.g. `?locale[]=`) SHALL be ignored in favor of
the rest of the chain and MUST NOT produce a server error. A session language the site does not
offer SHALL be dropped from the chain.

#### Scenario: Non-scalar locale parameter is ignored

- **WHEN** a visitor opens `/?locale[]=en`
- **THEN** the page renders with the locale resolved from the rest of the chain
- **AND** the response is not a server error

#### Scenario: Non-scalar language-switch parameter is ignored

- **WHEN** a visitor opens `/?cama_set_language[]=en`
- **THEN** the page renders with the locale resolved from the rest of the chain
- **AND** the response is not a server error

#### Scenario: Offered scalar locale is honored

- **WHEN** a site's configured languages include `en` and a visitor opens `/?locale=en`
- **THEN** the page renders in English

### Requirement: Unoffered locales produce the site's 404 page

When the resolved locale is not among the site's configured languages, the frontend SHALL
respond `404 Not Found` with the site's own error page — the standard 404 template or the
site's configured custom `error_404` post — rendered through the active theme. The rejected
locale SHALL NOT style the error page or leak into its links: the page SHALL render in the
site's first configured language. The response MUST NOT be a server error.

#### Scenario: Unoffered scalar locale renders the site 404

- **WHEN** a site's configured languages are `[en]` and a visitor opens `/?locale=de`
- **THEN** the response is `404 Not Found`
- **AND** the body is the site's 404 page rendered in English
