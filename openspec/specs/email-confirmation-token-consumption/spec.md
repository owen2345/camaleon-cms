# email-confirmation-token-consumption Specification

## Purpose
An email-confirmation link carries a one-time token; once it has been used to mark an address
confirmed, the same link must not stay live. Consuming the token on use keeps confirmation tokens
single-use, matching the password-reset token.
## Requirements
### Requirement: A confirmation token is consumed on use

`SessionsController#confirm_email` SHALL clear `confirm_email_token` (and its `confirm_email_sent_at`
timestamp) once it has successfully marked the account's email valid, so the same confirmation link
cannot be replayed and the spent token no longer resolves to any account.

#### Scenario: A used confirmation link is spent

- **WHEN** a valid, unexpired confirmation link is followed and the email is marked valid
- **THEN** the token is cleared and a second request carrying the same token resolves to no account

