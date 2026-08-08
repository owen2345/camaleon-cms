# Proposal: security-capability-gating

## Why

Camaleon already answers "may a non-admin do this dangerous thing?" with a role permission in four
places — `post_content_unfiltered_html`, `contact_form_unfiltered_html`, `media_unfiltered_upload`,
and `select_eval` — each held only by administrators by default and each failing closed when there is
no request context. But the pattern is convention by repetition, not a stated rule. Nothing catches a
new security-sensitive action shipped ungated, gated by a bypassable proxy (a filesystem path, an
output filename, a client flag), or failing open.

Both failure modes have already happened. [#1228](https://github.com/owen2345/camaleon-cms/pull/1228)
was a correction after the fact: an upload exemption keyed on a source path that a caller-supplied
output filename could walk through, replaced by a permission. And `cama_external_menu` in the surveyed
ecosystem ships the opposite failure — an access check that fails *open*, so restricted menus become
public if the hook stops running. State the rule once, as a checkable convention.

## What Changes

- A new `security-capability-gating` capability states the rule as requirements: the default-off
  permission, admin-by-`can :manage, :all`, the fail-closed predicate, authorization rather than a
  proxy signal, and a governance requirement that a new security-sensitive action conforms and cites
  it.
- `docs/security/permissions.md` gains a "The gating rule" section stating the principle and the
  recipe for adding a new gated capability, ahead of the per-permission detail it already carries.
- `docs/ai/criteria.md` gains a Security-section line pointing at the rule, so the pre-PR self-audit
  checks it.
- No engine code changes. The four existing permissions already conform and are cited as the
  templates; they are not modified.

## Capabilities

### New Capabilities

- `security-capability-gating`: a security-sensitive action is admin-only by default and gated for
  non-admins by a dedicated, default-off, fail-closed role permission — authorization, never a proxy
  signal, and never fail-open.

## Impact

- `openspec/specs/security-capability-gating/spec.md` (new)
- `docs/security/permissions.md` (new section)
- `docs/ai/criteria.md` (Security pointer)

**Not in scope.** This codifies the rule; it does not retrofit existing ad-hoc checks beyond citing
them, and it implements no specific fix. The first application under the codified rule is the N2 upload
finding (re-scan the bytes a `before_upload` handler swaps in, for a caller without
`media_unfiltered_upload`), which lands with its own change.
