# Judge the content of a DTD in the upload scan

## Why

Camaleon scans each upload of a user who does not have the `media_unfiltered_upload` permission, and
it refuses unsafe markup. The scan of a markup file in an XML format (SVG, XHTML, XML, XSL) parsed
the file with no entity expansion. So a reference such as `&x;` stayed one node, and no check read
the markup that the entity holds. A browser expands the reference when it shows the file.

The byte patterns of the scan read the entity value as the file writes it. An XML parser decodes a
character reference in an entity value before it reads the value as markup. So an entity value with
`&#111;nerror` gives an `onerror` attribute in the browser, and the scan accepted the file. An entity
value with a `foreignObject` element passed too, because the byte patterns do not list that element.
A visitor reaches this scan through a contact form that has a file field.

A DTD can also declare a default for an attribute, such as `<!ATTLIST svg onload CDATA "...">`. A
browser then gives the `svg` element an `onload` handler, and no tag of the file holds that
attribute. The scan did not read the default, so it accepted the file.

The scan also accepted a file with an entity bomb. The thumbnail step then expanded the entities,
and the upload request did not return.

## What Changes

- The scan reads a file that declares a DTD entity as a browser reads it: each entity reference
  becomes the value of the entity. The same refusal rules then apply to the elements, the attributes
  and the attribute values of that document.
- The scan refuses a file that declares an entity of another resource (`SYSTEM` or `PUBLIC`). The
  scan cannot read that resource, and it does not open it.
- The scan refuses a file whose entities expand past the limit of the XML parser, and a file whose
  entity refers to itself. The parser stops at the limit.
- The scan refuses a file whose DTD declares a default for an attribute with a name that starts
  with `on`. It also refuses a default with a blocked URI scheme.
- **BREAKING**: the scan refuses a file whose DTD holds a default that the XML parser does not
  keep. The parser does not keep a default that does not fit the type of its attribute, or a second
  declaration of one attribute. The scan also refuses a file that declares an attribute when the
  parser gives 100 reports of an error.
- **BREAKING**: the scan refuses a file that declares an entity and has a fatal XML error.
  Before, the scan read such a file up to the error.
- A file with harmless entities passes as before. An example is an SVG file of Adobe Illustrator,
  which declares its namespaces as entities.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `svg-upload-sanitization`: the rule for DTD entities names what the scan reads. New requirements
  cover an entity of another resource, the limit of the expansion, a file with harmless entities,
  an attribute default of the DTD, and a default that the scan cannot read.

## Impact

- `lib/camaleon_cms/svg_content_checker.rb`: the parse of a file that declares an entity, and the
  check of the attribute defaults.
- `docs/upgrading-to-2.9.5.md` and `docs/security/permissions.md`.
- The `camaleon_cms:security:scan_uploads` task uses the same scan, so it lists a stored file that
  the scan now refuses.
- Each plugin that stores a file with `upload_file` or `cama_tmp_upload` gets the same scan.
  `cama_contact_form` is one.
