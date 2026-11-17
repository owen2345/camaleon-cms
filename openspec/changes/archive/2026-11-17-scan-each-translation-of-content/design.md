## Context

See `proposal.md`, "Why". `String#split_locales` (`lib/ext/translator.rb`) splits the text at
`<!--:-->`. In each part, it takes the locale of the first marker at the start of a line. Then it
removes the first marker of that locale on each line.

A line break stays, and two parts are never joined. So a translation can open a new tag only where
a `<` comes right before a removed marker. The guard `marker_inside_tag?` finds a marker inside a tag, but `<<!--:en-->` does not start a tag.

## Decisions

**D1. `unsafe_html?` scans the stored text and each value of `String#translations`.** Each text gets
the same checks. The size bound reads the stored text only, because a translation is shorter.

- The scan reads the text that the page shows, as `docs/security/permissions.md` asks.
- The content shortcode gate reads only the stored text. [#1345](https://github.com/owen2345/camaleon-cms/pull/1345) makes it read each translation in the same way.
- A value that does not start with a marker has no translation, and it gets one scan, as before.
- `String.new` gives the copy that `translations` reads, so the caller's value keeps no result.

Alternatives:

- A scan of each translation in the custom field gate only. Post content, the summary and the
  contact form stay open. Rejected.
- `split_locales` removes only the marker at the start of a part. It changes what each install
  shows for a stored translation. Rejected.
- Refuse a `<` right before a marker. It saves a parse, but it depends on how `split_locales` works
  today. Rejected.
- Refuse a marker that is not at the start of a part. It can refuse imported or hand-written
  translations. Rejected.

The maintainer chose D1, in a PR of its own, on 2026-11-17.

## Risks / Trade-offs

- [A translated value costs one parse for each different translation.] → Only a value that starts with a
  marker has a translation, and a translation is a part of the stored text. A value with a few
  languages costs about two parses. The worst case is many different locale keys. A 1.94 MB value with
  60,000 keys took 34 s, and its stored text alone took 12 s. Only a signed-in role can save such a
  value, and the maintainer accepted this cost on 2026-11-17. A limit on the number of translations
  would add a refusal for all callers.
- [A translation can fail a check that the stored text passes, with no join.] → A translation is the
  stored text without its markers. The admin form writes whole translations, and the specs show
  that they pass.

## Migration Plan

No data migration. Stored values do not change. An unchanged post content is not checked again.
`rake camaleon_cms:security:scan_content` lists a stored value that the scan now refuses.
