# password-post-protection Specification

## Purpose
A password-protected post (visibility `password`) must not disclose its body — or any representation
derived from the body — to a visitor who has not supplied the post's password. The post's existence
and title remain visible (listings, feeds), matching the plugin's model of replacing the body with a
password prompt.
## Requirements
### Requirement: Excerpts of a locked password post are replaced

While a password-protected post is locked for the current request, `the_excerpt` SHALL return a
neutral, translatable notice instead of the summary meta or the body-derived excerpt, so listing
pages, search results, and RSS feeds cannot leak the body. The post's title SHALL remain visible.

#### Scenario: RSS feed does not leak the body

- **WHEN** an anonymous visitor fetches `/rss` while the feed contains a locked password post
- **THEN** the item's description carries the neutral notice and no body text, while the title is
  still present

#### Scenario: Listing consumers get the notice

- **WHEN** any consumer calls `the_excerpt` on a locked password post
- **THEN** it receives the neutral notice, not the summary meta or body-derived excerpt

#### Scenario: Public posts are unaffected

- **WHEN** a public post's excerpt is rendered alongside a locked post's
- **THEN** the public excerpt still shows its body-derived text and only the locked post carries the
  notice

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

### Requirement: Password-protected posts are excluded from page caching

Because a password post is unlocked per session while the page cache is keyed on the URL alone, a
password-protected post SHALL NOT be page-cached; otherwise an unlocked render would be stored under
the shared URL key and replayed to visitors who never entered the password. The page cache SHALL
exclude `password` visibility as it already excludes `private`.

#### Scenario: An unlocked render is not cached for other visitors

- **WHEN** the page-cache plugin evaluates whether to cache a `password`-visibility post
- **THEN** it SHALL NOT cache it, so a later visitor without the session unlock never receives a
  cached body

