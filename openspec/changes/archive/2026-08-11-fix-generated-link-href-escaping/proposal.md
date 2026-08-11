## Why

`the_url` is a plain (non-`html_safe`) `String`, and a post slug persists byte-for-byte — slug
normalization is commented out in `post_default.rb`, so a slug is stored with only presence and
uniqueness checked. Three server-generated HTML fragments interpolate a `the_url` value directly into
a single-quoted `href` and are rendered through `raw`, so a slug carrying a single quote closes the
attribute and injects a live event handler that runs in the visitor's — and, because the admin panel
is same-origin with the frontend, an administrator's — session.

This is audit finding **H11**. It was explicitly deferred by
[`fix-decorator-html-injection`](../archive/2026-08-02-fix-decorator-html-injection/proposal.md), whose
"Out of scope" section listed these `href='#{the_url}'` sinks as "the same string-built shape, but the
interpolated value is a generated URL, and Rails route generation is expected to percent-encode it.
Unverified either way; needs its own investigation before anyone claims a defect." This change is that
investigation and its fix.

### Triage verdict: legit

Per `docs/ai/workflows.md` Phase 2A.

**Proof of presence.** `ActionDispatch::Journey::Router::Utils.escape_segment` and `escape_path` were
run against the payload directly: they percent-encode `<`, `>`, `"` and space, but **not** the single
quote, `=`, `(`, or `)`. So `the_url` for a slug `x' onmouseover='alert(document.domain)` reaches the
sink with its quotes intact, and the rendered fragment is:

```
<li><a href='http://host/post/x' onmouseover='alert(document.domain)'>label</a></li>
```

The tokenizer closes `href` at the first stored quote and parses a live `onmouseover` handler.
Reproduced at the helper level for all three sinks — each spec fails against unmodified `master`, with
the broken-out handler present in the raw output.

**Precondition.** The default `post` route's segment constraint rejects a quote at generation time, but
the other content routes (`post_of_posttype`, `hierarchy_post`, `post_of_category`) and the taxonomy
routes use a `constraints: lambda`, which does not restrict generation — common for pages and for
category/tag links.

### The three sinks

| Sink | Method | Rendered by |
|---|---|---|
| Breadcrumb link | `NavMenuHelper#breadcrumb_draw` | the default theme breadcrumb partial (`raw`) |
| HTML sitemap post & category links | `CamaleonHelper#cama_sitemap_cats_generator` | `raw(cama_sitemap_cats_generator(...))` in `sitemap.html.erb` |
| Default-theme taxonomy links | `themes/default/default_helper.rb#get_taxonomy` | `<%= raw get_taxonomy(...) %>` in the default theme post list |

The sibling `cama_menu_draw_items` was already hardened this exact way by the #1218 output-escaping pass
(`nav_menu_helper.rb:132` — `href='#{ERB::Util.html_escape(...)}'`); these three were missed by it.

## What Changes

- `breadcrumb_draw` escapes the interpolated URL: `href='#{ERB::Util.html_escape(item[1])}'`.
- `cama_sitemap_cats_generator` escapes both the post URL and the category URL.
- `get_taxonomy` (bundled default theme — both the gem and the `spec/dummy` copy, kept identical by
  `spec/lib/bundled_theme_helper_sync_spec.rb`) escapes the taxonomy URL and the `rel` value.
- Helper specs reproducing each sink.

The escaped output is byte-identical for URLs with no HTML metacharacters, so downstream themes matching
on the rendered markup are unaffected. The interpolated titles are already escaped `SafeBuffer`s from
`the_title` and are left untouched, per the escape-at-the-source contract.

## Out of scope

- **Restoring slug normalization** (`post_default.rb` `before_validating`, commented out). The audit
  floated re-enabling `slug.parameterize` as defense in depth. Rejected here: the escaping above is the
  complete correctness fix (slug content is now irrelevant to safety), and `parameterize` re-slugs every
  post on save (URL/SEO churn) and drops non-ASCII, emptying slugs for non-Latin sites. It belongs in
  its own considered change if pursued. Rationale in `design.md`.
- **Returning a `SafeBuffer`** from these three helpers. They are rendered exclusively through `raw`,
  and the only untrusted interpolations (the URL, and `get_taxonomy`'s `rel`) are now escaped; the
  titles are already `SafeBuffer`s. Marking the whole fragment `html_safe` would additionally assert the
  breadcrumb *label* — `breadcrumb_add`'s first argument, a public entry point — is safe, which it is
  not guaranteed to be. The surgical fix escapes the values that reach the attribute rather than
  restructuring the return contract. Rationale in `design.md`.
- **The `<%= post.the_url %>` sites** in the default theme ERB views. They go through `<%= %>`
  auto-escaping and are already safe; only the string-built, `raw`-rendered helpers were exposed.
