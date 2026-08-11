# Design

## D1. Why escape at the sink, and only the URL

The exploitable value is the URL. `the_url` returns a plain `String` and route generation preserves the
single quote (verified: `escape_segment`/`escape_path` encode `<`, `>`, `"`, space — not `'`, `=`, `(`,
`)`). Escaping the interpolated URL with `ERB::Util.html_escape` — the pattern the #1218 pass already
applied at `nav_menu_helper.rb:132` — closes the attribute-breakout completely. It also keeps the
output byte-identical for ordinary URLs, which matters because downstream themes packaged as separate
gems match on the exact rendered bytes and this repo cannot see them.

The titles interpolated in the same fragments are already escaped `SafeBuffer`s from `the_title`
(escape-at-the-source, `generated-markup-escaping`), so they are left untouched. `get_taxonomy`'s `rel`
is a plain `String` reaching an attribute, so it is escaped too, for the same reason the URL is — the
method is a public helper and a caller may pass an un-trusted `rel`.

## D2. Slug normalization is not restored (rejected)

`post_default.rb#before_validating` is commented out, so a post slug is stored verbatim — the supply
side of this finding. Re-enabling `self.slug = slug.to_s.parameterize` would neutralize the class from
the supply side, and taxonomies/custom fields already parameterize their slugs.

Rejected for this change on two grounds:

1. **It is not needed.** Escaping the sink makes the slug's bytes irrelevant to safety. Restoring
   normalization is defense in depth, not the correctness fix.
2. **It is a behavior change with real regressions.** `parameterize` rewrites the slug on every save, so
   existing posts with punctuation in their slug get re-slugged the next time they are edited (URL and
   SEO churn), and `parameterize` drops non-ASCII characters, emptying the slug for non-Latin titles
   (Cyrillic, etc.) — a live concern for multi-locale sites. A defensible version would need
   transliteration configuration and its own migration/consideration, which does not belong bundled into
   a security patch.

If pursued later, it is a standalone change against the supply side, orthogonal to the sink fix here.

## D3. The helpers keep their plain-`String` return (rejected: returning `SafeBuffer`)

`generated-markup-escaping` requires `the_status`/`get_caption` to return a `SafeBuffer` because those
fragments escape *every* value they interpolate. The three helpers here are rendered exclusively through
`raw`, so a `SafeBuffer` return buys nothing at the render site. Adopting it would require the whole
fragment to be truthfully safe — which, for `breadcrumb_draw`, means escaping the *label* (`item[0]`)
too. Labels enter through `breadcrumb_add(label, …)`, a public method a theme may call with arbitrary
content, and the nav-menu convention deliberately treats labels as trusted HTML (`nav_menu_helper.rb:143`).
Escaping the label would change that behavior; not escaping it while returning a `SafeBuffer` would be a
false safety claim. Escaping the values that actually reach the attribute — the URL and `rel` — is the
honest, surgical fix.
