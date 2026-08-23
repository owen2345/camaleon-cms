## Context

See proposal.md — Why. The blocker for a save-time gate is detection: the shortcode-name registry (`CurrentRequest.shortcodes`, read by `cama_reg_shortcode`) is populated per request by the active frontend theme's `front_before_load` hook, so it is empty in the admin save path, and shortcode names are added imperatively via `shortcode_add` — nowhere enumerable at boot. Model-level `can?` is already available: `check_select_eval_authorization` (`custom_field.rb`) calls `can?(:manage, :select_eval)` in a model callback. `do_shortcode` is called from several authored surfaces — `post_decorator` (post content), `custom_fields_concern` (field values), `term_taxonomy_decorator` (taxonomy content), and the widget template (widget descriptions).

## Goals / Non-Goals

**Goals:**
- Precise save-time detection (only real, registered shortcodes — no false positives on bracketed text).
- Reject a non-administrator's save of shortcode-bearing content on **every** surface `do_shortcode` expands, unless the actor holds `content_shortcodes`.
- Leave stored content and all rendering untouched.

**Non-Goals:**
- No change to how shortcodes expand at render; no content sanitization anywhere.
- Not unifying the render-time `shortcode_add` template registration with the new boot DSL (the DSL declares names; converging the two is a possible later refactor).

## Decisions

### D1 — A boot-time shortcode registration DSL feeding a canonical registry
Core exposes a registration DSL that runs at boot (not per request, not `config.json`): shortcode providers declare their shortcode names through it, and the CMS aggregates them into a process-wide canonical set (e.g. `CamaleonCms::ShortcodeRegistry`). Core declares its own bundled shortcodes through the same DSL. Save-time detection builds its match regex from this registry (the `cama_reg_shortcode` shape, sourced from the registry rather than `CurrentRequest`).

*Alternatives considered:* (a) `config.json` `"shortcodes"` array — pure data, but the maintainer chose a code DSL for flexibility; (b) generic `[name …]` detector — rejected: false positives; (c) accumulate names from runtime `shortcode_add` — rejected: cold-start fail-open. **Constraint the DSL imposes:** declarations run at boot with no request/site context, so a provider's declaration must not depend on `current_site`/`request`. Where a provider today computes shortcode names dynamically in a front hook, only the *names* need to move to the boot DSL; the render-time handler can stay in `shortcode_add`.

### D2 — Gate at every authored-content save that feeds do_shortcode
Apply the same check at each surface's save path — post content (`Post`), custom-field values (the field-value save path), taxonomy content (`TermTaxonomy`/post-type/category/tag), and widget descriptions (the appearances/widgets save path). Factor the logic into a shared detector + authorization check (a concern/mixin or a shared service) rather than duplicating it, so the surfaces stay consistent and adding a surface is one call. Each check mirrors `check_select_eval_authorization`: if the registry-backed detector finds a shortcode in the content of any stored locale and the actor is a non-administrator lacking `content_shortcodes`, add a base error and abort. **A missed surface is a fail-open bypass**, so the task list enumerates the `do_shortcode` call sites and gates each; a test asserts the current known set is covered.

### D3 — `content_shortcodes` permission per security-capability-gating
Define the permission alongside the existing gated permissions in the `Ability` model and the admin roles UI toggle: default-off, seeded on no role, admin-bypass via `can :manage, :all`, absent key reads not-granted (no migration), fail-closed.

### D4 — Fail-closed on unavailable registry / unevaluable permission
If the registry cannot be built (boot error) it MUST NOT silently become empty (fail-open). An error-unavailable registry, an absent authorization context, or an evaluation failure resolves to gated/not-granted for non-administrators (block). A legitimately empty registry (no provider declared shortcodes) is a distinct, non-error state.

### D5 — Remove any pre-existing shortcode escaping/sanitizing (audit — core + ecosystem)
Because the remedy is the gate, no escape/sanitize should be applied to shortcodes on save or render. **Audit at proposal time (2026-08-23): none found in core or the cloned ecosystem.** Core: the shortcode engine (`short_code_helper.rb`), `_shortcode_parse_attr`, the `shortcode_templates/` views (`widget.html.erb` uses `raw`), and every `do_shortcode` call site are verbatim; the post-content save path is reject-based (`reject_untrusted_dangerous_content`), not shortcode sanitizing; bundled plugins/themes register no shortcodes. Ecosystem: the four active shortcode providers — `cama_contact_form` (`forms`, view-rendered), `cama_image_lightbox` (`lightbox`), `cama-stripe-donation` (`stripe_donation`, view-rendered), `camaleon-download` (`download`) — apply no escaping/sanitizing; the two with shortcode-XSS (`camaleon-download` DL-1, `cama_image_lightbox` LB-1) interpolate attrs **raw**, so there is nothing to remove and the gate is what closes them. The only escaping ever added anywhere was the theme-level `escape_javascript` in texpert/camaleon_website#758, already reverted. Apply must **re-audit** core and ecosystem (the trees may change before implementation) and remove any shortcode-specific escaping/sanitizing found — but only where this gate covers the threat it guarded; anything the gate does not cover is recorded, not silently dropped (removing a security escape without equivalent coverage would re-open the vuln).

## Risks / Trade-offs

- **A `do_shortcode` surface is missed → fail-open on that surface.** → Enumerate all call sites (post content, field values, taxonomy content, widget descriptions today) and gate each behind the shared check; add a coverage test; document that new expanded surfaces must adopt the check.
- **Third-party shortcodes not declared through the DSL aren't detected → fail-open for them.** → Core declares its bundled shortcodes; document the DSL for providers. Concrete ecosystem providers that must adopt the DSL to be gated: `cama_contact_form` (`forms`), `cama_image_lightbox` (`lightbox`), `cama-stripe-donation` (`stripe_donation`), `camaleon-download` (`download`); plus camaleon_website's `camaleon_cms` theme (`redirect`, `bootstrap_slider`). Declaring `download` and `lightbox` is what actually closes DL-1/LB-1 through the gate. These are per-repo follow-ups (separate repos — never pushed without direction; see `docs/ai/ecosystem.md`), enabled by the core mechanism, not part of this change's implementation.
- **DSL declarations that reach for request/site context at boot will fail.** → Document the request-independence constraint; only names move to the DSL.
- **Regex over content on every gated save / multi-locale.** → Negligible; one anchored scan from a bounded name set, over each stored locale, on create/update only.

## Migration Plan

- `content_shortcodes` is default-off and seeded on no role → existing installs read it as not-granted with no data migration; grant it to roles that author shortcodes.
- Declare core's bundled shortcode names through the boot DSL.
- Rollback: removing the permission + the shared check disables the gate; no stored data changed.
