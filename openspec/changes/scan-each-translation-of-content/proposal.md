# Scan each translation of authored content

## Why

`String#translate` removes the first marker of the locale on each line, anywhere in the line. The
page shows that translation. `UnsafeMarkup.unsafe_html?` scanned only the stored text. There a
marker right after `<` is not inside a tag, so the guard for a marker inside a tag does not see it.

An example is this stored text, in which a line break follows `<p>Intro</p>`:

```text
<!--:en--><p>Intro</p>
<<!--:en-->img src=x onerror=alert(1)><!--:-->
```

The scan passes it, and the English page shows `<img src=x onerror=alert(1)>`. So a role without
`post_content_unfiltered_html` can store an event handler. Post content, the summary of a post
and a gated custom field value are open.

## What Changes

- `UnsafeMarkup.unsafe_html?` scans the stored text and each translation of it, with the same
  checks.
- A value with no translation gets one scan, as before.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `post-content-sanitization`: the scan reads each translation that the page shows.

## Impact

- `lib/camaleon_cms/unsafe_markup.rb`. Each caller of `unsafe_html?` gets the change: the post
  content, the post summary, the custom field values and the cama_contact_form gate, which
  delegates to it.
- No stored value changes. `rake camaleon_cms:security:scan_content` now lists a stored value whose
  translation the scan refuses.
