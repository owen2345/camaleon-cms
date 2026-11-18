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

### Requirement: Each code value shows as written

`String#cama_replace_codes` SHALL replace all codes of the text in one pass. It SHALL show each value as written, also a backslash sequence in it. It SHALL NOT search a value that it put in for another code.

#### Scenario: A backslash sequence in a value shows as written

- **WHEN** a value holds `\0`, `\&`, `\'`, `` \` ``, `\\`, `\1` or `\k<x>`
- **THEN** the text SHALL hold that sequence as written, and no error SHALL be raised

#### Scenario: A value keeps the code of a later value

- **WHEN** the value of `[c1]` holds the text `[c2]`, and `[c2]` is also a code of the call
- **THEN** the value of `[c1]` SHALL keep the text `[c2]`, and the code `[c2]` of the text SHALL get its own value

#### Scenario: A list value shows its items joined with commas

- **WHEN** a value is a list
- **THEN** the text SHALL show its items joined with commas, as before

#### Scenario: The first value of a key counts

- **WHEN** a key is given as a Symbol and as a String
- **THEN** the first value of the two SHALL count, as before

#### Scenario: An unknown format gives the text as it is

- **WHEN** the format is not `[`, `{` or `%{`
- **THEN** the method SHALL give the text as it is, as before

### Requirement: The menu container shows its items as rendered

`draw_menu` SHALL put the rendered menu items into the menu container with no replacement. A backslash sequence in an item name SHALL show as written.

#### Scenario: A backslash sequence in a menu item name shows as written

- **WHEN** the name of a menu item holds `\0`, `\'`, `` \` ``, `\\`, `\1` or `\k'x'`
- **THEN** the menu SHALL show that name as written, and no error SHALL be raised

#### Scenario: A site with no menu gets an empty container

- **WHEN** the site has no menu
- **THEN** `draw_menu` SHALL give the container with no items, as before
