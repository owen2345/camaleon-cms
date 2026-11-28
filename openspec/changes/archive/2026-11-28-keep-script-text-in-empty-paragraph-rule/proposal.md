# Keep the text of a script out of the empty paragraph rule

## Why

The TinyMCE text editors of Camaleon write an empty paragraph as a line break. An example is a post
body that holds `<p>a</p><p></p>`: the editor returns `<p>a</p>` and a `<br />`. A `PostProcess`
handler did this with a regular expression on the output text.

The output text also holds the text of each script and each comment. The camaleon_editor plugin
makes the text editors keep scripts. A script such as `el.innerHTML = '<p></p>';` thus came back as
`el.innerHTML = '<br />';`, and the script did a different thing.

## What Changes

- The text editors find the empty paragraphs as elements, not in the output text. The text of a
  script or a comment does not change.
- The text of other elements that the editor keeps as text, such as `noscript` and `iframe`, does
  not change either. The old rule changed `<p></p>` in that text too.
- The output for all other content does not change.

## Capabilities

### New Capabilities

- `text-editor-empty-paragraphs`: a text editor writes an empty paragraph as a line break. The
  text of a script or a comment does not change.

### Modified Capabilities

None.

## Impact

- `cama_get_tinymce_settings` in `app/assets/javascripts/camaleon_cms/admin/_data.js` holds the
  rule. It applies to each text editor that takes these settings.
- The spec is `spec/features/admin/post_editor_empty_paragraph_spec.rb`.
