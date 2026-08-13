# password-post-protection

## Purpose

A password-protected post (visibility `password`) must not disclose its body — or any representation
derived from the body — to a visitor who has not supplied the post's password. The post's existence
and title remain visible (listings, feeds), matching the plugin's model of replacing the body with a
password prompt.

## ADDED Requirements

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
