## ADDED Requirements

### Requirement: The scan reads each translation that the page shows

The content scan (`UnsafeMarkup.unsafe_html?`) SHALL read the stored text and each translation that
`String#translate` gives for it. A value SHALL be refused when one of these texts fails a check.
`translate` removes the first marker of the locale on each line, anywhere in the line. So a
translation can join a `<` and the text after a marker into a tag.

#### Scenario: A tag that a translation joins is refused

- **WHEN** a contributor saves post content that holds `<!--:en--><p>Intro</p>`, a line break and
  `<<!--:en-->img src=x onerror=alert(1)><!--:-->`
- **THEN** the save SHALL fail with a validation error on `content`, because the English
  translation shows `<img src=x onerror=alert(1)>`
- **AND** nothing SHALL be persisted

#### Scenario: A summary whose translation joins a tag is refused

- **WHEN** an editor without `post_content_unfiltered_html` saves a summary whose translation joins
  a tag with an event handler
- **THEN** the save SHALL be refused, and no summary SHALL be stored

#### Scenario: Translated content with allowed markup is stored unchanged

- **WHEN** a contributor saves translated content whose translations hold only allowed markup
- **THEN** the save SHALL succeed and the persisted content SHALL equal the authored content
