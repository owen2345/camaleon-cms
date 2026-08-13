## Purpose

Ensure credential-bearing request parameters are redacted from the application logs. Camaleon accepts
secrets through ordinary form parameters — user passwords and, in the site settings form, the SMTP
password and object-storage keys — so without explicit log parameter filtering these are written to the
Rails logs in cleartext.

## ADDED Requirements

### Requirement: Credential parameters are filtered from logs

The engine SHALL configure Rails log parameter filtering so that user passwords and the site-settings
SMTP password (`email_pass`) and object-storage keys (`filesystem_s3_access_key`,
`filesystem_s3_secret_key`) are redacted from request logs, including when nested under a parent key
such as `options`. The configuration SHALL be additive, preserving any parameter filters the host
application already defines.

#### Scenario: Credential parameters are redacted

- **WHEN** a request logs parameters containing a user password and the settings `email_pass`,
  `filesystem_s3_access_key`, and `filesystem_s3_secret_key`
- **THEN** each of those values is replaced with the filtered mask in the log output

#### Scenario: Non-sensitive settings are not redacted

- **WHEN** the same parameters include a non-sensitive setting such as `site_name`
- **THEN** that value is left readable in the log output
