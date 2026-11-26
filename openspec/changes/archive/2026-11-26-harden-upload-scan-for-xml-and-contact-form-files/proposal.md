# Harden the upload scan for XML files

## Why

The upload scan parses an SVG, XHTML, XML or XSL file as XML. The requirement "XML parse errors
reject the upload" says that the scan refuses a file that does not parse. The code did not do that.

Its parser ran in recover mode, so it repaired a file with a fatal XML error and raised nothing. The
scan then gave its verdict on the repaired document. A browser does not read that repaired document,
so the scan and the browser did not read the same document.

The scan refuses the `link` and `style` elements, because they load a stylesheet. An
`xml-stylesheet` processing instruction loads one too, and the scan accepted it. Chrome 158 loaded
the CSS file that the instruction of an SVG file names.

With the type `text/xsl`, the instruction names an XSLT stylesheet of the same origin. A browser
with XSLT then shows the result of that stylesheet as the page. A stylesheet is a program. It can
build the name of a handler when it runs, so no scan of the stylesheet file finds that handler. The
scan refused a stylesheet only when it had an `xsl:template` element, because `template` is a
banned element name. A stylesheet with no template passed.

The scan refuses a blocked URI scheme, such as `javascript:`. It decoded a numeric character
reference before the match, and it did not decode a named one. A browser reads `&colon;` as a colon
in an HTML file, and in an XML file with a public XHTML DOCTYPE. So a file with
`href="javascript&colon;alert(1)"` passed the scan, and a click on that link ran the script.

The scan parses an HTML file with the HTML parser of libxml2, which follows HTML 4. A browser
follows the HTML5 rules, and the two parsers do not build the same tree. Inside an `xmp` element,
a browser reads `<!--` as text, and libxml2 reads the start of a comment. So an element with a
handler after the end tag passed the scan.

The `camaleon_cms:security:scan_uploads` task lists the stored files that the scan now refuses. It
read the media folders, and it did not read `public/contact_form`. The `cama_contact_form` plugin
stores the files of visitors there, and Camaleon installs that plugin as a dependency.

## What Changes

- **BREAKING**: the scan refuses a file in an XML format that has a fatal XML error. Examples are an
  element with no end tag, text after the root element, and an undeclared entity in a file with no
  DOCTYPE. Before, the scan refused only a file with no root element.
- A file with an error that is not fatal passes as before. An example is a prefix with no
  namespace.
- **BREAKING**: the scan refuses a markup file with an `xml-stylesheet` processing instruction.
- **BREAKING**: the scan refuses a file in an XML format that declares the XSLT namespace, used or
  not.

- **BREAKING**: before the scheme match, the scan decodes eight named character references, such as
  `&colon;`. The rule holds for an HTML file, for a file in an XML format and for a file of another
  type.

- **BREAKING**: the scan refuses an XML file that declares an entity and uses one of the eight
  names with no declaration.

- **BREAKING**: the scan also reads an HTML file with an HTML5 parser, and it applies its rules to
  that tree too. It refuses an HTML file past a limit of that parser, such as 400 nested elements.
  It also refuses an HTML file with a `select` element.

- The `camaleon_cms:security:scan_uploads` task also reads the whole `public/contact_form` folder.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `svg-upload-sanitization`: the requirement "XML parse errors reject the upload" gets scenarios for
  a fatal error in a file that has a root element. New requirements cover the stylesheet
  instruction, the XSLT namespace, and a dropped named reference in a file that declares an entity.
  A new requirement covers the HTML5 parse of an HTML file.

- `upload-content-security`: the task that lists stored files also reads the contact form folder.
  The requirement "Content is normalized before pattern matching" names the named references.

## Impact

- `lib/camaleon_cms/svg_content_checker.rb`: the options of the XML parse, and the stylesheet
  rule.
- `lib/camaleon_cms/content_security.rb`: the references that the normalization decodes, and the
  order of its steps.
- `lib/tasks/unsafe_stored_uploads.rake`: the folders that the task reads.
- `docs/upgrading-to-2.9.5.md` and `docs/security/permissions.md`.
- The `camaleon_cms:security:scan_uploads` task uses the same scan, so it lists a stored file with
  a fatal XML error.
