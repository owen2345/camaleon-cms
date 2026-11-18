## ADDED Requirements

### Requirement: Each shortcode output shows as the shortcode gives it

`do_shortcode` and `render_shortcode` SHALL replace each shortcode of a text at its place, from left to right. They SHALL show each output as written, also a backslash sequence in it. They SHALL NOT search an output for a later shortcode. An enclosing shortcode SHALL get its inner text as written. The shortcodes of that text SHALL then be replaced in its output in the same way.

#### Scenario: A backslash sequence in an output shows as written

- **WHEN** the output of a shortcode holds `\0`, `\&`, `\'`, `` \` ``, `\\`, `\1` or `\k<x>`
- **THEN** the rendered text SHALL hold that sequence as written, and no error SHALL be raised

#### Scenario: Two field values do not join into one tag

- **WHEN** an editor saves the `text_box` values `<img src="x" title="\'">` and `" onerror="alert(1)//`
- **AND** the content of a post shows them with two `data` shortcodes, one after the other
- **THEN** the page SHALL show each value as stored, and no element SHALL get an event handler

#### Scenario: An output keeps the text of a later shortcode

- **WHEN** the output of a shortcode holds the text of a later shortcode of the same text
- **THEN** that output SHALL keep the text, and the later shortcode SHALL be replaced at its own place

#### Scenario: A closing tag before its shortcode is text

- **WHEN** a closing tag, such as `[/title]`, is before its shortcode or in an earlier output
- **THEN** the shortcode SHALL be replaced as a shortcode with no closing tag, and no error SHALL be raised

#### Scenario: An output that is no String goes in as before

- **WHEN** the callback of a shortcode returns a Hash
- **THEN** the shortcode SHALL show the value of its own text in the Hash, or nothing when the Hash has no such key
- **AND** an output that is neither a String nor a Hash SHALL raise a `TypeError`

#### Scenario: An enclosing shortcode keeps its contract

- **WHEN** an enclosing shortcode holds other shortcodes, such as `[title][hello name="Owen"][/title]`
- **THEN** it SHALL get `[hello name="Owen"]` as its inner text
- **AND** the shortcodes of that inner text SHALL then be replaced in its output
- **AND** the text SHALL show `<h1>Hello Owen</h1>` when the output of `[title]` is the inner text in an `h1` element
