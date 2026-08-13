# Design

## D1. Append, don't assign

The filter is added in an engine `initializer` with `app.config.filter_parameters += [...]`. Appending
(not assigning) preserves whatever the host app configured in its own
`config/initializers/filter_parameter_logging.rb`; the two sets union, and order is irrelevant because
filtering is a match-any. The initializer runs during `initialize!`, before the request-logging
middleware reads the configured filters, so it takes effect for all subsequent request logs.

## D2. Pattern choice

`filter_parameters` symbols are matched case-insensitively as substrings against each parameter key at
every nesting depth (so `options[email_pass]` matches on the inner `email_pass` key). The set is:

- `passw` — `password`, `password_confirmation` (Rails-conventional).
- `email_pass` — the SMTP password; **not** covered by `passw`, so named explicitly.
- `secret` — `filesystem_s3_secret_key` (and any `*secret*`; also Rails-conventional).
- `access_key` — `filesystem_s3_access_key` (and any `*access_key*`); a clearly credential-bearing stem.

Each entry is either Rails-conventional or an unambiguous credential stem, so the collateral on a host
app's benign parameters is minimal while the audit's named keys are all covered.

## D3. Testing

`spec/lib/engine_filter_parameters_spec.rb` builds an `ActiveSupport::ParameterFilter` from the app's
configured `filter_parameters` and asserts the SMTP password, both S3 keys, and a user password are
redacted to `[FILTERED]`, while a benign `site_name` is left readable. The redaction example fails
against the unfixed engine (which contributes no filters), verified by stashing the change.
