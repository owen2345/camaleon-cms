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

## What Changes

- **BREAKING**: the scan refuses a file in an XML format that has a fatal XML error. Examples are an
  element with no end tag, text after the root element, and an undeclared entity in a file with no
  DOCTYPE. Before, the scan refused only a file with no root element.
- A file with an error that is not fatal passes as before. An example is a prefix with no
  namespace.
- **BREAKING**: the scan refuses a markup file with an `xml-stylesheet` processing instruction.
- **BREAKING**: the scan refuses a file in an XML format that declares the XSLT namespace, used or
  not.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `svg-upload-sanitization`: the requirement "XML parse errors reject the upload" gets scenarios for
  a fatal error in a file that has a root element. New requirements cover the stylesheet
  instruction and the XSLT namespace.

## Impact

- `lib/camaleon_cms/svg_content_checker.rb`: the options of the XML parse, and the stylesheet
  rule.
- `docs/upgrading-to-2.9.5.md` and `docs/security/permissions.md`.
- The `camaleon_cms:security:scan_uploads` task uses the same scan, so it lists a stored file with
  a fatal XML error.
