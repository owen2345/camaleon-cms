## Why

Admin headings show raw HTML entities instead of the characters they encode. A site named `Ben & Jerry's` renders as:

```
Configuration Site: Ben &amp; Jerry&#39;s        settings/site.html.erb:6
Edit Post: Ben &amp; Jerry&#39;s                posts/form.html.erb:12
```

Both verified in rendered HTML against `master` at `c27dbcc4`. The markup emitted is `Ben &amp;amp; Jerry&amp;#39;s` — escaped twice.

This is the tail of [#1206](https://github.com/owen2345/camaleon-cms/pull/1206) and [#1143](https://github.com/owen2345/camaleon-cms/pull/1143), which fixed stored XSS by escaping at the **source**: `PostDecorator#the_title` and `TermTaxonomyDecorator#the_title` now return `h.h(...)`, an already-escaped `SafeBuffer`. That was the right call and must stay — most themes and plugins live in separate gems and many render titles through `raw`, so source-side escaping is what makes those unseeable sinks safe.

But a `SafeBuffer` interpolated into a plain Ruby string loses its safe flag, and an ERB sink then escapes it again:

```
safe_join(['Edit: ', the_title])   →  SafeBuffer  →  ERB passes through  →  Ben & Jerry's   ✓
"Edit: #{the_title}"               →  String      →  ERB escapes again   →  Ben &amp; …     ✗
tag.span('x', title: the_title)    →  attribute   →  passed through      →  ✓
tag.span('x', title: "#{the_title} - y")  →  String  →  escaped again    →  ✗
```

The rule in both element and attribute context: **pass the value as an argument; never interpolate it.**

### Not affected

- **The SEO surface is clean.** `cama_the_seo` interpolates `the_title` into plain strings at six places, but the sink is `display_meta_tags` (meta-tags gem), whose `strip_tags` normalization unescapes and re-escapes, absorbing the extra layer. Verified: `<title>` renders `Ben & Jerry's <Best> Cakes` correctly. No fix needed, and no contract change for theme authors. The `camaleon-cms-seo` plugin overwrites `seo_data[:title]` with a raw option value and is likewise unaffected.
- **`raw` sinks.** `posts/index.html.erb:10` interpolates into a string handed to `raw`, which renders correctly. Left alone — converting it would be churn, and it is not broken.
- **Argument-passing sites.** `posts/index.html.erb:54` (`link_to title, …`) already renders `Ben & Jerry's` correctly, because the `SafeBuffer` is passed, not interpolated.

## What changes

Six ERB sites compose the escaped title with `safe_join` instead of string interpolation. Two blockers make this more than mechanical:

**Blocker 1 — `cama_pluralize_text` drops the safe flag.** `text.try(:pluralize)` returns a plain `String` for a `SafeBuffer` input, so the flag is gone before the call site can use `safe_join`. The helper is changed to *preserve* its input's safeness — never to add it. This is a public-helper return-contract change and is the only piece of this change with downstream exposure; it belongs in the changelog's upgrader notes.

**Blocker 2 — `titleize` mangles entities.** `"Ben &amp; Jerry&#39;s".titleize` yields `"Ben &Amp; Jerry&#39;S"`, and `&Amp;` is not a valid entity, so `categories/index.html.erb:42` renders a tooltip reading `Ben &Amp; Jerry'S`. `safe_join` does not touch this. The fix is to titleize the *unescaped* translated value and let the sink escape it.

## Out of scope

- **Changing the escape-at-source contract.** `the_title` keeps returning an escaped `SafeBuffer`. Alternatives considered in `design.md` D1.
- **Adding a public unescaped-but-translated accessor.** The gap is real — `the_title` welds escaping to translation, leaving callers that need to transform the text with nowhere to go — but two call sites do not justify a new public method. Recorded in `design.md` D3 for whoever hits it next.
- **`href='#{the_url}'`** in `cama_sitemap_cats_generator`, `breadcrumb_draw`, and the default theme helper. Same interpolation shape, but the value is a generated URL and the question is percent-encoding, not double-escaping. Unverified; needs its own investigation.
- **The two stored XSS defects** in `PostDecorator#the_status` and `CustomFieldGroup#get_caption`, handled by `fix-decorator-html-injection`.
