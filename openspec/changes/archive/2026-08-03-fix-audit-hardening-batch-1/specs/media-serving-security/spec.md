## ADDED Requirements

### Requirement: Header middleware installation does not depend on the host's static file server

The system SHALL install `CamaleonCms::MediaSecurityHeaders` in the middleware stack under both
static-file configurations: before `ActionDispatch::Static` when the host application has
`public_file_server.enabled` set to true, and appended ahead of the engine's own static file
handler when it does not. Application boot SHALL NOT raise when `ActionDispatch::Static` is absent
from the host stack.

#### Scenario: Boot with the public file server disabled

- **WHEN** the host application boots with `config.public_file_server.enabled = false`
  (the standard production configuration behind nginx/Apache)
- **THEN** `Rails.application.initialize!` completes without error
- **AND** `CamaleonCms::MediaSecurityHeaders` is present in the middleware stack

#### Scenario: Headers still precede static serving when the file server is enabled

- **WHEN** the host application boots with `config.public_file_server.enabled = true`
- **THEN** `CamaleonCms::MediaSecurityHeaders` sits before `ActionDispatch::Static`, so SVG
  responses served statically still carry the security headers
