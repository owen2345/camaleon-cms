## Why

Shortcodes in authored content trigger theme/plugin code that emits arbitrary HTML/JS at render. The save-time content scan (`CamaleonCms::UnsafeMarkup`, which enforces `post_content_unfiltered_html`) cannot reach a verdict on a shortcode: the shortcode-name registry is populated per request by the active *frontend* theme, so it isn't available at an admin save; shortcode output is dynamic; and after expansion, trusted theme-emitted markup is indistinguishable from author input. So an author who lacks `post_content_unfiltered_html` can still emit a `<script>` through a shortcode — e.g. `[redirect url="';alert(document.cookie);//"]` expands to `<script>window.location.href='…'</script>` for every viewer (audit finding WEB-2). Shortcodes are an end-run around the `post_content_unfiltered_html` gate. Because no scan can judge them, the sanctioned remedy under `security-capability-gating` is a default-off permission — not a scan, and not render-time escaping.

Shortcodes are expanded on more than post bodies: `do_shortcode` also runs over custom-field values, taxonomy content, and widget descriptions. The gate must cover every authored surface that is later expanded, or the bypass simply moves to an ungated surface.

## What Changes

- Add a dedicated, default-off role permission `content_shortcodes`.
- Introduce a **boot-time shortcode registration DSL** so the set of registered shortcode names is known outside a frontend request (the per-request frontend registry is unavailable at save). This is what makes *precise* save-time detection possible.
- On save of any authored content that will be expanded by `do_shortcode` — post content, custom-field values, taxonomy content, and widget descriptions — if the content contains a registered shortcode and the acting user is a non-administrator lacking `content_shortcodes`, the save is **rejected** with an error naming the reason (mirroring `check_select_eval_authorization`).
- **BREAKING**: a non-administrator role without `content_shortcodes` can no longer publish shortcode-bearing content on any gated surface. Grant the permission to roles that need it. Administrators are unaffected (`can :manage, :all`).
- Rendering is **unchanged**: stored content stays verbatim and no escape or sanitize is applied on render for anyone. Trusted authors' shortcodes render raw exactly as today.
- Supersedes the theme-level `escape_javascript` fix (texpert/camaleon_website#758, closed): under reject-don't-sanitize we gate the capability rather than escape trusted content.

## Capabilities

### New Capabilities

- `content-shortcode-gating`: authoring shortcodes in any surface that `do_shortcode` expands (post content, custom-field values, taxonomy content, widget descriptions) is permitted for a non-administrator role only through the default-off `content_shortcodes` permission, enforced by a save-time rejection, with administrators bypassing. Includes a boot-time shortcode-name registry (a registration DSL) that makes precise save-time detection possible. Conforms to and cites `security-capability-gating`.

### Modified Capabilities

- None. `security-capability-gating` is cited and conformed to, not changed — this adds a new conformant instance.

## Impact

- New default-off role permission `content_shortcodes` in the `Ability`/role model and the admin roles UI toggle, mirroring the existing gated permissions.
- New boot-time shortcode registration DSL + a process-wide canonical shortcode-name registry (replaces reliance on the per-request frontend registry for detection).
- A save-time authorization check applied at every authored-content save path that feeds `do_shortcode`: post content, custom-field values, taxonomy content, and widget descriptions — factored into a shared detector + check rather than duplicated per model.
- No change to stored content, to the content scan, or to rendering.
