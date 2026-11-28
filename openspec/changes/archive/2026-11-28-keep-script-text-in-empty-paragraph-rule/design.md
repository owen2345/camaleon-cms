# Design

## Context

See `proposal.md`, "Why". The settings of `cama_get_tinymce_settings` give the `p` element the
valid element `p[*]`. That rule has no padding rule for an empty paragraph. The serializer of
TinyMCE 4.9 thus writes an empty paragraph as `<p></p>`, not as `<p>&nbsp;</p>`.

The serializer parses the content into elements. Then its filters change the elements, and then it
writes them. `PostProcess` gets the output text.

## Decisions

### D1: Mark the paragraphs as elements, and replace only the mark

A node filter for `p` gives each paragraph an attribute, `data-cama-paragraph`. The value of the
attribute is random, and one text editor uses the same value for all its content. `PostProcess`
replaces each `<p>` that holds only this attribute and no content with `<br />`. Then it removes
the attribute from the other paragraphs.

The text of a script or a comment cannot hold the mark, because nobody knows the random value.
The rule thus does not change that text. The rule finds no script in the markup either.

### D2: Do not replace the paragraph in the filter

A filter that replaces an empty paragraph with a `br` element changes the output for content
outside scripts. The filters for different element names run in the sequence in which the content
names them first. Thus other filters can run after this filter:

- The filter that removes the last `br` of a block. It keeps a `br` after another `br`. For
  `<div><p></p></div>`, a new `br` element thus kept the `br` at the end of the `div`, and the
  output had two line breaks, not one.
- The filter that removes two `br` elements at the end of the content.
- The filters that remove bookmarks and some internal attributes. They can empty a paragraph after
  this filter.

The writer also puts a line feed before and after a paragraph, but not around a `br`. The mark of
D1 keeps each paragraph a paragraph until the output text exists. The other filters thus change
the same elements as before.

### D3: Keep a mark attribute of the content

A paragraph of the content that has a `data-cama-paragraph` attribute keeps its value and gets no
mark. That paragraph has an attribute, so the old rule did not change it either.

### D4: No mark without PostProcess

A call with `no_events`, or a call that returns the tree, does not fire `PostProcess`. The filter
then sets no mark, so no mark stays in the result. The old rule did not apply to these calls
either.

## Risks / Trade-offs

- The rule depends on the order of filters in TinyMCE 4.9: node filters, then attribute filters,
  then the writer, then `PostProcess`. A TinyMCE upgrade needs the spec run again.
- A `PostProcess` handler that runs before this one sees the marks. The handler of Camaleon is added
  in the `setup` of the editor, before the plugins add theirs, as the old handler was.
