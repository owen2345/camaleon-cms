## ADDED Requirements

### Requirement: A text editor writes an empty paragraph as a line break

A TinyMCE text editor that takes the settings of `cama_get_tinymce_settings` SHALL write each
paragraph that has no attributes and no content as `<br />`. This also applies to a paragraph that
the editor empties, for example when it removes a last `br`. A paragraph that still has an
attribute or content after the changes of the editor SHALL stay a paragraph.

#### Scenario: An empty paragraph between two paragraphs

- **WHEN** the content is `<p>a</p><p></p><p>b</p>`
- **THEN** the editor returns `<p>a</p>`, `<br />` and `<p>b</p>`, each on its own line

#### Scenario: A paragraph with only a line break, a space or an empty element

- **WHEN** the content holds `<p><br></p>`, `<p> </p>` or `<p><strong></strong></p>`
- **THEN** the editor returns a `<br />` for each of these paragraphs

#### Scenario: A paragraph that the editor empties after it parses the content

- **WHEN** the content holds a paragraph whose only attribute or content is internal to the editor,
  for example `class="mce-item-x"` or a bookmark
- **THEN** the editor returns a `<br />` for that paragraph

#### Scenario: An empty paragraph in a block

- **WHEN** the content is `<div><p></p></div>`
- **THEN** the editor returns the `div` with one `<br />`

#### Scenario: A paragraph with an attribute or content stays

- **WHEN** the content holds `<p class="x"></p>`, `<p>&nbsp;</p>`, `<p><br><br></p>` or
  `<p><span></span></p>`
- **THEN** the editor returns each of these paragraphs as a paragraph

### Requirement: The empty paragraph rule keeps markup that the editor keeps as text

The rule for empty paragraphs SHALL change elements only. The text of a script, a comment or a
`noscript` element SHALL come back unchanged. This also applies when the text holds `<p></p>` or
`<P></P>`. With the media plugin, an empty paragraph in the content of an `iframe`, `video`,
`audio` or `object` element SHALL stay `<p></p>`. The media plugin writes this content again, for
example `<P></P>` as `<p></p>`. This applies to the content of the editor and to the content of a
selection.

#### Scenario: Paragraph markup in the text of a script

- **WHEN** a text editor keeps scripts, and the content holds `<script>el.innerHTML = '<p></p>';</script>`
- **THEN** the editor returns the script with its text unchanged

#### Scenario: Paragraph markup in the text of a comment

- **WHEN** the content is `<!--<p></p>-->`
- **THEN** the editor returns the comment with its text unchanged

#### Scenario: Paragraph markup in the content of a noscript element

- **WHEN** the content holds `<noscript><p></p></noscript>`
- **THEN** the editor returns the `noscript` element with its content unchanged

#### Scenario: Paragraph markup in a CDATA section or a noframes element

- **WHEN** the content holds `<![CDATA[<p></p>]]>` or `<noframes><p></p></noframes>`
- **THEN** the editor returns each of them with its text unchanged

#### Scenario: An empty paragraph in the content of a media element

- **WHEN** the content holds `<video controls><p></p></video>`
- **THEN** the editor returns the `video` element with `<p></p>` in its content

#### Scenario: Paragraph markup in an iframe element without the media plugin

- **WHEN** a text editor has no media plugin, and the content holds `<iframe><P></P></iframe>`
- **THEN** the editor returns the `iframe` element with its content unchanged

#### Scenario: A selection that holds a script and an empty paragraph

- **WHEN** a selection holds a script with `<p></p>` in its text, and an empty paragraph
- **THEN** the content of the selection holds the script with its text unchanged, and a `<br />`
