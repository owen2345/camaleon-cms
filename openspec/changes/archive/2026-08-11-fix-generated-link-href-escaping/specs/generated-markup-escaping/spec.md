## ADDED Requirements

### Requirement: Link fragments built by helpers and rendered through `raw` MUST escape their interpolated URL

A helper that assembles an `<a href='…'>` HTML fragment by string interpolation, and whose result is
rendered through `raw`, SHALL HTML-escape every interpolated value that reaches an attribute and is not
already an `ActiveSupport::SafeBuffer` — in particular the `the_url` value in the `href`. A post slug
and a taxonomy slug persist byte-for-byte, and Rails route generation does not percent-encode the single
quote, so an un-escaped URL can close the attribute and introduce an event handler.

This applies to `NavMenuHelper#breadcrumb_draw`, `CamaleonHelper#cama_sitemap_cats_generator` (both the
post and the category URL), and the bundled default theme's `get_taxonomy` (the taxonomy URL and the
`rel` value).

The escaped output MUST remain byte-identical to the current output for URLs that contain no HTML
metacharacters, so that downstream themes matching on the rendered markup are unaffected. Interpolated
titles are already `SafeBuffer`s from `the_title` and are left unchanged.

#### Scenario: A breadcrumb link escapes a quote-carrying URL

- **WHEN** a breadcrumb item's URL is `/post/x' onmouseover='alert(document.domain)`
- **AND** it is not the last (active) item, so it renders as a link
- **THEN** `breadcrumb_draw` emits the URL with the single quotes HTML-escaped (`&#39;`)
- **AND** the rendered fragment contains no live `onmouseover` handler

#### Scenario: The HTML sitemap escapes a quote-carrying post or category URL

- **WHEN** a post's or category's `the_url` is `/post/x' onmouseover='alert(document.domain)`
- **AND** `cama_sitemap_cats_generator` renders it
- **THEN** the emitted `href` carries the single quotes HTML-escaped
- **AND** the fragment contains no live `onmouseover` handler

#### Scenario: A default-theme taxonomy link escapes a quote-carrying URL

- **WHEN** a category's or tag's `the_url` is `/category/x' onmouseover='alert(document.domain)`
- **AND** the default theme renders it through `raw get_taxonomy(...)`
- **THEN** the emitted `href` carries the single quotes HTML-escaped
- **AND** the fragment contains no live `onmouseover` handler

#### Scenario: A URL with no HTML metacharacters is unchanged

- **WHEN** a breadcrumb, sitemap, or taxonomy link URL contains no HTML-significant characters (for
  example `/blog/my-post`)
- **THEN** the emitted `href` is byte-identical to the pre-change output
