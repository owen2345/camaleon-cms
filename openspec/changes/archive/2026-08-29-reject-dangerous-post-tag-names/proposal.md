# Proposal: reject-dangerous-post-tag-names

## Why

Tag names were stored verbatim with no gate, and the admin autocomplete renders suggestion items
as HTML — so a tag name like `<img src=x onerror=…>` planted by a low-trust author executed in
the admin post form of every other author who typed a matching character. The branch closes this
with a save-time rejection (shipped, spec-covered); this change records the requirement so the
capability spec matches the shipped contract.

## What Changes

- Post saves that submit tag names run each name through the shared `UnsafeMarkup` detector
  (same allowlist as post content) for untrusted authors, and a dangerous name refuses the save
  with a validation error — reject, never sanitize or transform.
- The same trust gate as post content applies: admins and roles with the unfiltered-content
  opt-out are unaffected; previously stored tag names are left untouched.
- No new code in this change: spec-only documentation of behavior shipped on
  `feature/jquery-3-upgrade`.

## Capabilities

### New Capabilities

_None._

### Modified Capabilities

- `post-content-sanitization`: adds a requirement — untrusted authors' dangerous post tag names
  are rejected at save time under the same trust gate and allowlist as post content.

## Impact

- Affected code (already on the branch): the Post save validation and its request specs; the
  admin tag autocomplete surfaces that render stored names.
- Downstream: none beyond the save-time refusal untrusted authors already experience for
  dangerous content; the rejection message reuses the content-rejection messaging.
