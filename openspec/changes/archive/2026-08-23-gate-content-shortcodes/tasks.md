## 1. Permission (security-capability-gating conformance)

- [x] 1.1 Add `content_shortcodes` to the `CamaleonCms::Ability` permission set alongside `post_content_unfiltered_html` / `select_eval` / `media_unfiltered_upload` / `contact_form_unfiltered_html` — default-off, seeded on no role, administrators satisfied via `can :manage, :all`.
- [x] 1.2 Expose the permission as a toggle in the admin roles UI, mirroring the existing gated permissions.
- [x] 1.3 Confirm an absent key reads as not-granted (no migration) and the check fails closed (no ability/context or evaluation error => not-granted).

## 2. Boot-time shortcode registration DSL + canonical registry

- [x] 2.1 Add a boot-time registration DSL (e.g. `CamaleonCms::ShortcodeRegistry`) that shortcode providers call to declare their shortcode names, running with no request/site context; aggregate declarations into a process-wide canonical set.
- [x] 2.2 Declare core's bundled shortcode names through the DSL; document the DSL and the request-independence constraint for theme/plugin authors.
- [x] 2.3 Provide a registry-backed detector (regex built from the canonical set, matching the `cama_reg_shortcode` shape but sourced from the registry) that reports whether a content string contains a registered shortcode.
- [x] 2.4 Fail closed: distinguish a legitimately empty registry from an error-unavailable one; on the error case, treat content as gated for non-administrators.

## 3. Save-time gate across every expanded surface

- [x] 3.1 Factor the check into a shared detector + authorization helper (concern/mixin or service) that runs the registry-backed detector over every stored locale/translation of the content and refuses when the actor is a non-administrator lacking `content_shortcodes`.
- [x] 3.2 Apply it at each authored-content save path that feeds `do_shortcode`: post content (`Post`), custom-field values, taxonomy content (`TermTaxonomy` / post-type / category / tag), and widget descriptions (appearances/widgets).
- [x] 3.3 Enumerate the current `do_shortcode` call sites and add a coverage test asserting each authored surface is gated, so a newly added surface is caught.
- [x] 3.4 Re-audit the save/update and render paths for escaping/sanitizing applied specifically to shortcodes (none in core at proposal time; the theme-level `escape_javascript` in #758 is reverted). Remove any found where this gate covers the threat it guarded; record — do not silently remove — any instance the gate does not cover.

## 4. Tests (reproducing specs, red-first)

- [x] 4.1 A non-administrator without `content_shortcodes` saving shortcode-bearing post content is rejected and nothing is persisted.
- [x] 4.2 The same rejection holds for a custom-field value, taxonomy content, and a widget description.
- [x] 4.3 A non-administrator granted `content_shortcodes` succeeds on those surfaces; an administrator succeeds without the key in role meta.
- [x] 4.4 Content with no registered shortcode (including bracketed prose / `[text]`) is not gated (precise detection, no false positives).
- [x] 4.5 Upgraded install (role meta predating the key) reads not-granted with no migration; fail-closed paths (unevaluable permission, error-unavailable registry) resolve to gated.
- [x] 4.6 A permitted author's stored shortcode content still renders/expands verbatim (no added escaping or sanitization).
- [x] 4.7 A permitted author's shortcode output renders byte-for-byte verbatim — no CMS escaping/sanitizing of the shortcode syntax, attributes, or output on save or render.

## 5. Docs, changelog, OpenSpec

- [x] 5.1 Changelog entry (short, PR-linked) with a Breaking-changes note: non-admin roles without `content_shortcodes` can no longer publish shortcode content on any expanded surface; grant the permission; shortcode providers must declare names through the boot DSL to be gated. Draft upgrader notes under **Notes for upgraders**.
- [x] 5.2 Optionally add `content_shortcodes` to the conformant-examples list in `openspec/specs/security-capability-gating/spec.md`.
- [x] 5.3 Archive this OpenSpec change on the branch before merge (`/opsx:archive`), committed as part of the PR.

## 6. CI parity (before push)

- [x] 6.1 `bin/rspec` green (new specs + full suite).
- [x] 6.2 `bin/rubocop` clean on touched files; `bin/brakeman` no new warnings.
- [x] 6.3 `(cd spec/dummy && bin/rails zeitwerk:check)` passes.
