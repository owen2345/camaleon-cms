## Why

Camaleon's engine set no `config.filter_parameters`, so credential-bearing request parameters were
written to the Rails logs in cleartext. The site settings form submits the SMTP password and S3 keys as
`options[email_pass]`, `options[filesystem_s3_access_key]`, `options[filesystem_s3_secret_key]`, and user
passwords flow through auth. The Rails default (`:passw`, `:secret`) does not cover `email_pass` or
`filesystem_s3_access_key`, and a host app that had not added its own filters logged them in the clear.
Audit finding M9.

### Triage verdict: legit

`grep` confirms the engine sets no filter; the dummy host filters only `[:password]`. Reproduced in
`spec/lib/engine_filter_parameters_spec.rb`: `email_pass` and both S3 keys pass through unredacted
without the fix (stash-verified).

## What Changes

- The engine appends `%i[passw email_pass secret access_key]` to `config.filter_parameters` with `+=`,
  so user passwords, the SMTP `email_pass`, and the S3 secret/access keys are redacted to `[FILTERED]`
  in the logs. Using `+=` preserves any filters the host app already configured.

## Notes for upgraders

- These parameters are now redacted from new log output. Values already written to existing log files
  are not retroactively scrubbed. A host that already filtered them is unaffected (the sets union).

## Out of scope

- Log lines already written before the upgrade.
- Secrets stored in the database or site options (this is about request-parameter logging only).
