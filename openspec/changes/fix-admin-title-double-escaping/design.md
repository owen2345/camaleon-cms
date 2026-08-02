## Context

```
   PostDecorator#the_title            "Ben &amp; Jerry&#39;s"   SafeBuffer, html_safe? = true
   TermTaxonomyDecorator#the_title    (inherited by Site, PostType, Category, PostTag decorators)
        │
        ├── passed as an argument ──────▶  link_to / content_tag / safe_join / tag attribute
        │                                    flag survives → sink passes through → correct
        │
        └── interpolated "#{...}" ──────▶  plain String, flag lost
                                             ├── ERB <%= %>        escapes again  → BROKEN
                                             ├── raw(...)          no escape      → correct
                                             └── display_meta_tags strip_tags round-trip → correct
```

Three sink families, three different outcomes. Only the ERB `<%= %>` family is broken, which is why the defect went unnoticed: the SEO path (six interpolation sites) and the `raw` paths both render correctly by accident of what their sinks do.

## Decisions

### D1. Keep escaping at the source; fix the composition sites

Two alternatives were considered and rejected.

**Stop escaping in `the_title`, escape at each sink instead.** This is the idiomatic Rails arrangement and would make interpolation harmless. **Rejected:** it reopens the stored XSS that #1206 and #1143 closed. Escaping at the source is what protects `raw` sinks in themes and plugins that this repo cannot see (`AGENTS.md` §6 — the ecosystem list is the visible surface and more exist). Every one of those would have to be found and fixed first, which is not possible from here.

**Switch the six ERB sinks to `raw`.** Renders correctly, one-line changes. **Rejected:** it converts six escaping sinks into raw sinks whose safety depends entirely on `the_title` continuing to escape. That is the pattern `0ddf2aef` spent a sweep removing, and it trades a cosmetic bug for a latent security one.

The remaining option is to compose with `safe_join`, which keeps the flag intact through to the sink. This is a view-layer change with no public contract implications — except D2.

### D2. `cama_pluralize_text` preserves its input's safeness

```ruby
def cama_pluralize_text(text)
  text.try(:pluralize)          # camaleon_helper.rb:78
end
```

`SafeBuffer#pluralize` returns a plain `String` (`html_safe? → false`). At `post_tags/index.html.erb:6`, `categories/index.html.erb:42` and `post_tags/index.html.erb:40` the flag is therefore already gone when the value reaches the sink, and `safe_join` at the call site cannot recover it.

The helper is changed to propagate the flag it was given, and only that:

```ruby
res = text.try(:pluralize)
text.try(:html_safe?) ? res.try(:html_safe) : res
```

It never marks unsafe input safe, so it cannot make any caller less safe than today. It is nonetheless a public helper whose return type changes for safe inputs, so it is called out for upgraders.

Rejected alternative: leave the helper alone and call `.html_safe` at each call site. That works, but spreads three unguarded `html_safe` calls through views — precisely the pattern the codebase is moving away from, and each one is a place a future edit can feed unescaped data.

### D3. Titleize the unescaped value, and note the missing accessor

`titleize` operates on entities rather than characters once the value is escaped:

```
"Ben &amp; Jerry&#39;s".titleize   →   "Ben &Amp; Jerry&#39;S"
```

`&Amp;` is not a valid entity, so this is corruption rather than double-escaping, and `safe_join` does not address it. `categories/index.html.erb:42` renders a tooltip reading `Ben &Amp; Jerry'S`.

The fix is to titleize before escaping — `item.name.to_s.translate(item.get_locale).titleize`, letting the sink escape the result. That works because the decorator delegates `name` to the model, so the raw translated value is reachable.

The locale is passed explicitly rather than left to `translate`'s `I18n.locale` default. `the_title` resolves through `get_locale`, which prefers the cached *frontend* locale over `I18n.locale` — so on an admin page that has rendered a frontend URL, the bare default would title the tooltip in a different locale than the row it labels. `get_locale` is public on `ApplicationDecorator`, so matching it costs nothing.

It is reachable, but not *offered*. `the_title` welds escaping to translation, so a caller wanting to transform the text has no public path and must reach through to the model attribute. Adding an unescaped accessor for two call sites is not justified here, but the gap is real and the next caller will hit it. Recorded rather than fixed.

## Risks

- **`cama_pluralize_text` contract.** The only downstream-visible change. Propagation-only, so it cannot reduce safety; a caller doing `cama_pluralize_text(x).gsub(...)` still works, since `SafeBuffer < String`.
- **Under-escaping introduced while fixing over-escaping.** This is the real hazard: a careless `raw` or `html_safe` while chasing the entities would reopen the XSS. The regression spec (below) asserts both directions on every touched page, so a fix in that direction fails the suite.
- **Sites already displaying entities.** They start rendering correctly. No data migration — the stored values were never wrong, only their presentation.

## Regression test shape

One request spec pins the contract from both sides at once. Name every fixture `Ben & Jerry's <b>x</b>`, `GET` each affected admin page, and assert:

- `doc.text` contains the literal `Ben & Jerry's <b>x</b>` → catches **double**-escaping
- `doc.css('b')` finds no injected element → catches **under**-escaping

The second assertion is what keeps a future "just use `raw`" from passing.
