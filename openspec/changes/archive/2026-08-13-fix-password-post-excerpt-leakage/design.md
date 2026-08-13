# Design

## D1. Gate the decorator hook, not the templates

`the_excerpt` is a public decorator API: the leak surfaces (default-theme `_post_list_item`, the five
RSS builders, external themes) all consume it. Implementing the already-invoked `post_the_excerpt` hook
in visibility_post closes every consumer at once — including themes outside this repo — instead of
patching individual templates. Registration is one line in the plugin's `config.json`.

## D2. One lock predicate

The content gate previously embedded its unlock test inline. The excerpt gate must agree with it
exactly, so the test moves to `_visibility_password_locked?`, used by both hooks. This is also the
seam M2 uses to replace the unlock mechanism (session-based POST) without touching the gates again.

## D3. Neutral replacement text

The locked excerpt becomes `ct('password_protected_excerpt', default: 'This content is password
protected.')` — translatable per site like the plugin's other strings, and constant, so it reveals
nothing about the body. The title stays visible (parity with the content gate and the WordPress
model the plugin follows).

## D4. Testing

`spec/requests/security/password_post_excerpt_leakage_spec.rb` (request spec): `/rss` must not carry
the locked body but must carry the title and the notice (fails on unfixed code, stash-verified); a
decorator-level example pins `the_excerpt` itself for listing consumers; a public post's excerpt in
the same feed guards against over-blocking. The dummy app's test theme lists posts via `the_content`
(already gated), so the HTTP-reachable in-repo repro is the feed; the decorator example covers the
listing consumers.
