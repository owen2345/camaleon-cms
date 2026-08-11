# Design

## D1. Clamp the length at the point of generation

`GET /captcha?len=` is unauthenticated and exempt from the site/before-action stack, so the requested
length is the one piece of attacker input that reaches image generation. Clamping it into a small range
(4–8, default 5) at the top of `cama_captcha_build` neutralises both halves of the abuse in one place: a
huge value can no longer allocate a giant string or render an oversized image (H4), and a tiny value can
no longer collapse the answer space to a trivially brute-forceable size (H3). A non-numeric or absent
value (`?len[]=`, `?len=`, or no param) falls back to the default rather than raising.

The clamp lives in **both** `cama_captcha_build` copies — `RuntimeCaptchaImageConcern` (serves `/captcha`)
and `CaptchaHelper` (mixed into the controller/view stack for plugin forms). These two methods are already
maintained as byte-for-byte duplicates; the constants and `cama_captcha_length` helper are duplicated the
same way, each lexically bound to its own module's constants, so neither can drift into a weaker bound.

## D2. One active challenge, consumed on use

The bypass came from treating `session[:cama_captcha]` as an ever-growing list of acceptable answers.
Two changes make a captcha a single, single-use challenge:

- **Replace, not append.** `cama_captcha_build` assigns `session[:cama_captcha] = [text]`, so the only
  answer that verifies is the one on the image the user is currently looking at. This also bounds the
  session size (the old list grew without limit).
- **Consume on success.** `cama_captcha_verified?` deletes the challenge once it matches, so a solved
  captcha cannot be replayed; a re-rendered form issues a fresh one. It also rejects a blank submission up
  front, closing the empty-string match.

Because `cama_captcha_verified?` now has a side effect, `captcha_verify_if_under_attack` is refactored to
call it once and reuse the result — the previous code called it twice (once for the return value, once to
reset the counter), which after consumption would never reset the attack counter on a genuine solve.

## D3. Testing the happy path

The security properties are locked in by `spec/requests/security/captcha_hardening_spec.rb` (length clamp,
single active challenge, and a real `POST /admin/register` succeeding with the correct current answer) and
`spec/helpers/camaleon_cms/captcha_helper_spec.rb` (verify consumes, rejects a stale or blank value). The
browser-level "register with a correct captcha" feature example was removed: a captcha is now single-use
and bound to the one challenge the register page issues, while `get_rack_session` navigates away to read
it and each register render issues a fresh challenge — so a JS feature test can never both read the
current answer and submit against it. The request spec covers that path deterministically instead.
