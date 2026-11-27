# Design

## Context

See `proposal.md`, "Why". `_custom_fields.js` has two sortables. One sorts the instances of a
repeatable field group. The other sorts the values of a field that takes more than one value. Both
call `cama_remove_text_editors` at the start of a drag, and
`cama_restore_text_editors` at the drop.

## Decisions

### D1: Find each field from its text editor

Before, each sortable took the element after each `.mce-panel` for the field of that text editor. A
plugin can put its own element between the panel and the field. An example is a plugin that adds
its own editor for the field. In that case, Camaleon did not remove the text editor of the field,
and the document of that editor did not survive the move. At the drop, Camaleon set up a text
editor on the plugin element, and one on a part of the panel.

`cama_remove_text_editors` now reads `tinymce.editors`, and takes each text editor whose element is
in the dragged item. The element of a text editor is its field, so no element between the panel and
the field can change the result.

### D2: Keep the settings of each text editor on its field

Before, the drop used `mceAddEditor`. That command uses the settings of the last `tinymce.init` of
the page. On the post page, that is the init of the post content editor. A dragged text editor of a
custom field thus came back 480px high, not 120px.

`cama_remove_text_editors` now keeps the settings of each text editor in the jQuery data of its
field. `cama_restore_text_editors` gives these settings to `new tinymce.Editor(...).render()`.

### D3: An inline text editor stays

An inline text editor has no panel in the item, and its content is the element itself. The element
survives a move, so the two functions do not touch an inline text editor. This was also true before
the change.

### D4: A new field takes an id that is free

A new text editor field took a random id from 1 to 100000, and nothing made sure that no other
element had it. TinyMCE finds a field by its id, so a new field with the id of another field got no
text editor. TinyMCE also keeps the text editor of a deleted field. A new field with the id of that
text editor got no text editor either. `custom_field_editor` now takes a new random id until no
element of the page and no text editor has it.

## Risks / Trade-offs

- The id loop has no upper bound. A page holds far fewer than 100000 text editor fields, so each
  try finds a free id with a high probability.
