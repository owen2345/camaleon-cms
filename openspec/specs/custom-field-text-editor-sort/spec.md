# custom-field-text-editor-sort Specification

## Purpose

A TinyMCE text editor does not survive a move of its panel in the page. Pin that a drag of a custom field group or of a field value sets up each text editor again. Each text editor keeps its own settings. Pin also that a new text editor field gets an id that TinyMCE can use.

## Requirements

### Requirement: A drag sets up each text editor of the dragged item again

An admin can drag an instance of a repeatable field group, or a value of a field that takes more
than one value. Camaleon SHALL then remove each TinyMCE text editor whose field is in the item. At
the drop, it SHALL set up a text editor for each of these fields again, with the content of the
field. Camaleon SHALL find each field from its text editor, so an element between the panel and the
field does not change the result.

#### Scenario: The text editor of a dragged instance works after the drop

- **WHEN** an admin drags an instance of a repeatable field group that holds a text editor field
- **THEN** that field gets a new text editor at the drop, with its content
- **AND** the text editor uses the document of its own frame

#### Scenario: The text editor of a dragged value works after the drop

- **WHEN** an admin drags a value of a text editor field that takes more than one value
- **THEN** that field gets a new text editor at the drop, with its content

#### Scenario: Each text editor of the dragged item works after the drop

- **WHEN** an admin drags an instance of a repeatable field group that holds two text editor fields
- **THEN** each of the two fields gets a new text editor at the drop

#### Scenario: A plugin element between the panel and the field

- **WHEN** a plugin puts its own element between the panel of a text editor and its field
- **AND** an admin drags the item that holds the field
- **THEN** the field gets a new text editor at the drop
- **AND** Camaleon sets up no text editor on the plugin element or on a part of the panel

### Requirement: A text editor keeps its own settings after a drag

Camaleon SHALL set up each text editor of a dragged item again with the settings that the text
editor had before the drag. It MUST NOT take the settings of the last `tinymce.init` of the page,
which can be the init of another editor.

#### Scenario: A later init of the page does not change the settings

- **WHEN** the page sets up another text editor with a height of 480px, after the custom fields
- **AND** an admin drags a value of a text editor field whose height is 120px
- **THEN** the text editor of that field has a height of 120px after the drop

### Requirement: A drag keeps an inline text editor

Camaleon SHALL NOT remove or set up again an inline TinyMCE text editor of a dragged item. An inline
text editor has no frame, so it survives the move.

#### Scenario: An inline text editor stays after the drop

- **WHEN** an instance of a repeatable field group holds an inline text editor
- **AND** an admin drags that instance
- **THEN** the inline text editor after the drop is the same text editor as before the drag

### Requirement: A new text editor field gets an id that is free

A new text editor field SHALL get a random id that no other element of the page has. The id SHALL
also not be the id of a text editor that TinyMCE keeps, for example the text editor of a deleted
field. TinyMCE finds a field by its id, and it gives no text editor to a field with an id that is
not free.

#### Scenario: The random id is the id of another field

- **WHEN** the random id of a new text editor field is the id of a field on the page
- **THEN** the new field gets another id and its own text editor

#### Scenario: The random id is the id of a deleted field

- **WHEN** an admin deletes an instance of a repeatable field group with a text editor field
- **AND** the random id of a new text editor field is the id of the deleted field
- **THEN** the new field gets another id and its own text editor
