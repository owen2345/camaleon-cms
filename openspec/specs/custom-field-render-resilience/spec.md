# custom-field-render-resilience Specification

## Purpose
The admin edit form must render every custom field of a record regardless of what any one field
holds or how its renderer behaves: a save replaces all of a record's field values with what the
form posts, so a field left unrendered posts nothing and its stored value is silently blanked.
The capability pins that isolation and the value handling of the field kinds whose rendering used
to break it.

## Requirements

### Requirement: One field's failure does not abort the rest of the form

The admin edit form SHALL render each custom field of a record independently. A field whose
stored value or per-kind render callback fails SHALL degrade alone: the failure is reported as a
console warning naming the callback, the form's field build does not throw, and every field
registered after it renders with its stored value, as do the page initialisers registered after
the field build. A render callback whose name resolves to no function SHALL be reported the same
way rather than thrown.

#### Scenario: A broken render callback warns and leaves the rest of the form intact

- **WHEN** a custom field's render callback throws while the edit form builds its fields
- **THEN** a console warning naming the callback is emitted, the build completes, and the fields
  after it render with their stored values

#### Scenario: Fields after a colorpicker holding a non-colour value keep their values

- **WHEN** a colorpicker field stores the free-text value `2` and a text field is registered after
  it on the same record
- **THEN** both render, the text field shows its stored value, and a save preserves it

### Requirement: The colorpicker accepts any stored value as text

The colorpicker field SHALL initialise for any stored value — a colour, free text, a number-like
string, `true`, `null` or JSON — and show the stored value verbatim in its input, treating it as
text no matter what type the value arrives as. A stored colour SHALL render on the swatch. A field
with no stored value SHALL keep the markup's declared default colour (white) rather than an empty
value, and a falsy-but-real value such as `0` SHALL be preserved as the text `0`. The plain
initialiser that themes can name as a render callback SHALL tolerate markup whose colour
attribute is coercible or absent. Markup missing the swatch internals (no addon, or an addon
without its icon) SHALL still initialise, an unrecognised colour format SHALL fall back to hex,
and rendering the field again with a new value SHALL repaint the swatch.

#### Scenario: A number-like stored value initialises the picker

- **WHEN** the stored value is `2`
- **THEN** the picker initialises and its input shows `2`

#### Scenario: Other typed shapes initialise the picker

- **WHEN** the stored value is `true`, `null` or `{"a":1}`
- **THEN** the picker initialises and the fields after it keep their stored values

#### Scenario: A stored colour renders on the swatch

- **WHEN** the stored value is `#00ff00`
- **THEN** the input shows `#00ff00` and the swatch is green

#### Scenario: No stored value keeps the default white

- **WHEN** the field has no stored value
- **THEN** the picker initialises and the swatch is white

#### Scenario: A numeric zero survives as text

- **WHEN** the field is rendered with the value `0`
- **THEN** the widget's colour reads as the text `0`

#### Scenario: The plain initialiser tolerates a coercible or missing colour attribute

- **WHEN** the plain initialiser runs on markup whose colour attribute is `2`, or has none
- **THEN** the widget initialises

#### Scenario: Themed markup without the swatch internals initialises

- **WHEN** the markup has no addon, or an addon without its icon
- **THEN** the widget initialises

#### Scenario: An unrecognised colour format falls back to hex

- **WHEN** the markup declares an unrecognised colour format, a colour is picked and the picker
  closes
- **THEN** the input holds the picked colour in hex

#### Scenario: Re-rendering with a new value repaints

- **WHEN** the field is rendered with one colour and then rendered again with another
- **THEN** the swatch shows the second colour

### Requirement: An untouched picker leaves the stored value alone

Opening and dismissing the colorpicker without choosing a colour SHALL NOT write to the field: the
input keeps its stored value, free text or blank included. After an actual pick — a slider
interaction or a programmatic set — dismissing the picker SHALL write the formatted colour back.

#### Scenario: Opening and dismissing the picker untouched changes nothing

- **WHEN** the stored value is `2` and the picker is opened, then dismissed without a pick
- **THEN** the input still reads `2`

#### Scenario: A pick is written back on dismiss

- **WHEN** a colour is picked and the picker is dismissed
- **THEN** the input holds the picked colour

### Requirement: Choice fields match stored values as text

The checkbox, checkboxes and radio fields SHALL select the option or options whose value equals
the stored value by comparing values as text, so an option value holding a quote or another
selector-significant character is selected and does not break the form. The checkboxes field
SHALL accept a scalar stored value as well as a list.

#### Scenario: A radio option holding a quote renders checked

- **WHEN** a radio field's option value is `Bob's pick`, that value is stored, and a text field is
  registered after the radio
- **THEN** the option renders checked and the text field renders with its stored value

#### Scenario: A checkboxes option holding a quote renders checked from a scalar value

- **WHEN** a checkboxes field stores the scalar value `Bob's tag`
- **THEN** that option renders checked

### Requirement: A disabled field renders read-only

A custom field whose definition carries the disabled (or readonly) option SHALL render its inputs
read-only in the edit form.

#### Scenario: A disabled text field is read-only

- **WHEN** a text field is defined with the disabled option and holds a stored value
- **THEN** its input renders read-only

### Requirement: The translation decoder accepts typed values

The admin translation decoder that translatable fields read their values through SHALL accept a
value that arrives as a number or boolean, treating it as its text form, instead of throwing.

#### Scenario: A numeric or boolean value decodes

- **WHEN** the decoder receives `1` or `true`
- **THEN** it returns without throwing
