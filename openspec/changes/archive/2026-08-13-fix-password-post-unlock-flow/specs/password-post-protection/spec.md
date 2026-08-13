# password-post-protection

## ADDED Requirements

### Requirement: Unlocking a password post uses POST, constant-time comparison, and session state

The password prompt SHALL submit the password in a POST body to a dedicated unlock endpoint, using a
`type='password'` input and a CSRF token; the URL SHALL never carry the password. The endpoint SHALL
scope the post to the current site's frontend-visible posts, respond 404 for a post that is not
password-protected, compare the submitted password in constant time, and record a successful unlock
as a session-side marker (post id) — never the password. The previous query-string unlock parameter
SHALL NOT unlock a post.

#### Scenario: GET parameter no longer unlocks

- **WHEN** a visitor requests a locked post's URL with the old `post_password` query parameter set to
  the correct password
- **THEN** the body stays locked and the password prompt is shown

#### Scenario: Correct password unlocks for the session

- **WHEN** the visitor posts the correct password to the unlock endpoint
- **THEN** they are redirected to the post with its body visible, and later plain GETs of the post in
  the same session stay unlocked without any password in the URL

#### Scenario: Wrong password stays locked with feedback

- **WHEN** the visitor posts a wrong password
- **THEN** they are redirected back to the locked post, the prompt shows a translatable error, and the
  body is not disclosed

#### Scenario: Non-password posts cannot be "unlocked"

- **WHEN** the unlock endpoint is called for a post that is not password-protected (or not visible on
  this site's frontend)
- **THEN** it responds 404 and no session marker is written
