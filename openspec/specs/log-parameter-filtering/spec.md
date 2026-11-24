# log-parameter-filtering Specification

## Purpose
Ensure credential-bearing request parameters are redacted from the application logs. Camaleon accepts
secrets through ordinary form parameters — user passwords and, in the site settings form, the SMTP
password and object-storage keys — so without explicit log parameter filtering these are written to the
Rails logs in cleartext.
## Requirements
### Requirement: Credential parameters are filtered from logs

Camaleon SHALL configure Rails log parameter filtering so that user passwords, the site-settings
SMTP password (`email_pass`) and object-storage keys (`filesystem_s3_access_key`,
`filesystem_s3_secret_key`), token parameters (including the installer gate `setup_token`), and the
stored password of a password-protected post (`visibility_value`) are redacted from request logs,
including when nested under a parent key such as `options` or `post`.

#### Scenario: Credential parameters are redacted

- **WHEN** a request logs parameters containing a user password, the settings `email_pass`,
  `filesystem_s3_access_key`, and `filesystem_s3_secret_key`, a `setup_token`, or a post
  `visibility_value`
- **THEN** each of those values is replaced with the filtered mask in the log output

#### Scenario: Non-sensitive settings are not redacted

- **WHEN** the same parameters include a non-sensitive setting such as `site_name`
- **THEN** that value is left readable in the log output

### Requirement: The log parameter filters keep the filters of the host application

The configuration of the log parameter filtering SHALL be additive. It SHALL preserve any parameter
filters that the host application already defines.

#### Scenario: A filter of the host application stays

- **WHEN** the host application defines a parameter filter of its own
- **THEN** that filter still redacts its parameter in the log output, and the filters of Camaleon apply too

