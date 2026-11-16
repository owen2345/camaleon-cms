## Context

See `proposal.md`, "Why". `CustomFieldsRelationship#reject_untrusted_dangerous_value` returns early for a kind that is not in `GATED_FIELD_KEYS`. The class method `gate_rejection_reason` picks the rule by kind, and the `scan_content` rake task calls the same method. `author_trusted_for_unfiltered_value?` trusts an admin, and a holder of `post_content_unfiltered_html` for the fields of a post. For every other owner it trusts only an admin.

The path of the defect is `cama_shortcode_data`. It returns `the_field` or `the_fields`, which give a plain `String`. `do_shortcode` puts that `String` into the content, and the theme prints the content with `raw`. The `render_field` branch of the shortcode is safe: it renders a template that escapes the value. Themes outside Camaleon also print a field value with `raw`, for example `raw(post.the_field("map"))` in the `cv` theme of camaleon_website.

The requirement "Untrusted input is rejected, never transformed" of `security-capability-gating` stays as it is. A value that only reaches escaped positions still needs no gate. A custom field value is not such a value, because the `data` shortcode can put it into a raw position.

## Goals / Non-Goals

**Goals:**

- One dispatch, in `gate_rejection_reason`, for the validation and for the audit task, as today.
- The trust of a non-admin follows the trust rule of `docs/security/permissions.md` (D5). The permission of another save, such as `nav_menu` or `widgets`, gives no trust.

**Non-Goals:**

- A per-kind rule set for kinds that are not markup.
- A change of the shortcode, the custom field templates or a theme.

## Decisions

**D1. The markup rule for every kind except `field_attrs`.** The rule is the one that `editor` uses today: `UnsafeMarkup.unsafe_html?` with the post-content allowlist. The same untrusted author is held to the same rule for the post content, so the rule is not new to that author.

A probe in the dummy app gave these verdicts. Pass: `a < b & c`, `x > y`, `5 <3 you`, `<b>bold</b>`, `https://x.test/p?a=1&b=2`, `#ff0000`, `2026-11-15`. Refuse: `Fish & Chips <today>`, `<iframe src=x></iframe>`.

- Alternative: a narrow rule for kinds that are not markup (script elements, event handlers, script URLs). The contact-form gate uses such a rule for a visitor. It refuses less plain text, but it lets an `<iframe>` or a `<form>` into the page through the shortcode. A second rule is also a second thing to keep in parity. Rejected.

**D2. A URL kind gets the markup rule and the URL rule.** `[data field='link']` puts a URL value into the content as markup, so `https://x.test/"><script>…` must be refused. The URL rule stays for the `href` and `src` positions of the templates. An ordinary URL passes the markup rule (D1 probe).

**D3. `field_attrs` keeps its member scan.** The stored JSON escapes `<` as a Unicode escape, which a browser shows as text. Each decoded member is already held to the markup rule.

**D4. `GATED_FIELD_KEYS` and `gated_field_key?` go away.** Every kind is gated, so the early return in the validation goes too. `MARKUP_FIELD_KEYS` goes as well, since the markup rule is the default. `URI_FIELD_KEYS` and `JSON_MARKUP_FIELD_KEYS` stay.

A search of the sibling plugin and theme checkouts finds no caller of the removed constants or of `gated_field_key?`. The constants are not a documented API (`docs/ai/ecosystem.md`).

**D5. Trust by owner.** The maintainer chose to align the check with the trust rule of `docs/security/permissions.md` (2026-11-15).

- A `CamaleonCms::Site` owner: `can?(:manage, :settings)`. `Admin::SettingsController#site_saved` writes these values, and `validate_role` authorizes it on `settings`.
- A `CamaleonCms::Theme` owner: `can?(:manage, :theme_settings)` too. `save_theme` writes these values, and `validate_role_theme` authorizes it on `theme_settings`.
- Every owner that is not a post: `can?(:manage, :settings)` or `can?(:manage, :custom_fields)`. `docs/security/permissions.md` says that these two permissions give a role the trust of an administrator. The maintainer chose this on 2026-11-15, after a review found that the doc and the check disagreed. An example is the post type fields: `Settings::PostTypesController` writes them, and it authorizes the save on `settings`. The fields of a post stay with `post_content_unfiltered_html`, the permission of the post body, which these two permissions do not give.
- A value with no owner: admin only.
- The check asks `CamaleonCms::Ability` for the site in `CurrentRequest`, and it fails closed as the post branch does. The permission holds for that site only, so a site or a theme owner must belong to it. For the other owners, the check reads no site: the permission of the current site decides.

**D6. The error message stays `value_rejected_html`.** It names the field and the remedy, and it already fits a value of any kind.

**D7. The scan comes before the trust check of a non-admin.** The trust check builds a `CamaleonCms::Ability`, which loads the role and two role metas. The maintainer chose this order on 2026-11-15.

- The validation checks an admin first, at no cost. Then it scans, and it checks the trust only for a value that the scan refuses.
- A trust check first would load the role for each value row, because every kind is scanned now.
- A trusted non-admin gets a scan of each value, which reads no database row.

- Alternative: one `Ability` for each request on `CurrentRequest`. It saves more queries, but `Ability#initialize` loads the role again on purpose, so a cache can read a changed role. Rejected for this change.

**D8. The trust check finds the owner by its Camaleon class.** A row stores the short name of its owner class, such as `Post`. Before PR #1346, `CamaleonRecord.polymorphic_class_for` tried the top-level constant first. In a host app with its own `Post` model, the trust check then got a host record and used the rule of other owners.

The trust check reads `owner`. PR #1346 merged first, and it makes `polymorphic_class_for` try the Camaleon class first for each model.

- Alternative: a lookup of the Camaleon class in the trust check only (`trust_owner`). This change had it until PR #1346 merged. Removed: it repeated the lookup of `owner`, and it gave `CamaleonCms::User` for `User` also when the configured user class is a host class.

**D9. A URI kind refuses each character that ends an attribute.** `do_shortcode` replaces a shortcode also inside a tag, and `the_field` gives the raw value. So `<img src="[data field='photo']">` puts an image value into an attribute. The value `x" onerror="alert(1)` has no `<`, so the markup rule passes it, and the page runs the handler.

A URI kind now also refuses `"`, `'`, `<`, `>`, a backtick and whitespace before another character. A URL can encode each of them, and the media library gives no URL with one of them. The maintainer chose this on 2026-11-16, after a review found the gap.

- A value of another kind inside a tag gets no rule (intended). Only an admin or a holder of `content_shortcodes` can place a shortcode, and that role chooses the position. A rule for a `text_box` value refuses a quote in ordinary prose.
- Whitespace at the end of a URL passes. No character of the value follows it, so it adds no attribute, and a URL that an author copies often has it.
- Leading whitespace is refused. In an attribute with no quotes, whitespace ends the value. The parser skips whitespace before a value, so a shortcode at the start of the value is safe. But a shortcode after other characters, as in `<img src=https://cdn.test/[data field='photo']>`, gives `src="https://cdn.test/"`, and the value ` onerror=alert(1)` adds an event handler. The first rule of D9 let whitespace at both ends pass. The maintainer chose to refuse leading whitespace on 2026-11-16, after a review found this gap.
  - Alternative: refuse whitespace at the end too. The rule is simpler, but it refuses a URL with a trailing space or line break, which is safe. Rejected.
- `'` is refused, although a URL can hold it. A single-quoted attribute ends at it, and `%27` encodes it.
- The rule comes after the markup rule, so `https://x.test/"><script>…` still gets the markup message.
- Alternative: refuse a `data` shortcode inside a tag at the save of the content, for everyone, as the contact-form template rule does for a placeholder. It covers every kind, but it removes the main use of an image field in a shortcode, and it limits an admin. Rejected.
- Alternative: escape the value in the shortcode. The remedy rule forbids a change at render, and an `editor` value must show as markup. Rejected.
- Alternative: refuse a quote in a value of every kind. It refuses ordinary prose. Rejected.

## Risks / Trade-offs

- [An untrusted author who stored `Fish & Chips <today>` in a `text_box` gets a refusal at the next change of that value.] → An unchanged value is not checked again on an unrelated edit (the requirement "An unchanged pre-gate value does not block an unrelated edit"). The changelog names the change. `scan_content` lists the stored values that the scan now refuses.
- [A plugin that writes a value of any kind from a job, with no request context, now gets the scan.] → The value passes when it holds no unsafe markup. A plugin calls `unfiltered_value!` to skip the scan, as it does today for `editor`.
- [A stored URL value with a quote, or with a space before another character, is refused at the next change of that value (D9).] → An unchanged value is not checked again, and `scan_content` lists the value.
- [`scan_content` lists more rows on an install with markup in plain fields.] → The task is read-only. The upgrade note says so.

## Migration Plan

No data migration. Stored values do not change. An operator runs `rake camaleon_cms:security:scan_content` to list the values that the scan now refuses.
