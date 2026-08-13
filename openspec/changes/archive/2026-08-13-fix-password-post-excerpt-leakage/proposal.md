# Fix password-protected post leakage through excerpts and feeds

## Why

The visibility_post plugin's password gate covers only `post_the_content`: a password-protected post
replaces its body with the password form. But `PostDecorator#the_excerpt` — rendered by listing pages,
search results, and every RSS builder (`rss`, `single`, `post_type`, `category`, `post_tag`) — is
computed from the post body (or its summary meta) and runs the `post_the_excerpt` hook, which no plugin
implemented. Any anonymous visitor could read the beginning of a password-protected post from `/rss` or
any listing that shows excerpts, without ever entering the password. Audit finding M1.

### Triage verdict: legit

Reproduced in `spec/requests/security/password_post_excerpt_leakage_spec.rb`: on unfixed code, `/rss`
carries the locked post's body text in its `<description>`, and `the_excerpt` returns the body-derived
excerpt (stash-verified failures).

## What Changes

- visibility_post registers the `post_the_excerpt` hook. While a password post is locked for the
  request, the excerpt is replaced with a neutral, translatable notice
  (`ct('password_protected_excerpt')`, default "This content is password protected.").
- The lock decision is extracted into one private predicate (`_visibility_password_locked?`) shared by
  the content and excerpt gates, so every derived representation of the body agrees on the unlock
  state. (M2 later swaps the predicate's unlock source; this change keeps the existing
  `post_password` parameter semantics.)
- Post titles remain visible in feeds and listings — matching the content gate, which shows the title
  with the password form.

## Out of scope

- The unlock mechanism itself (GET parameter, plaintext input, non-constant-time compare) — audit
  finding M2, fixed separately.
- Hiding password posts from listings/feeds entirely: title-visible-body-locked is the plugin's
  (WordPress-parity) model; the leak was the body-derived excerpt, not the post's existence.
