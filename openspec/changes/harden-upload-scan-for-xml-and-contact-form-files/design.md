# Design

## Context

See `proposal.md`, "Why". `CamaleonCms::SvgContentChecker.parse_document` called
`Nokogiri::XML(content, &:nonet)`. The default options of Nokogiri hold `RECOVER`, so the
`rescue Nokogiri::XML::SyntaxError` of that method never ran. The checker refused a file only when
the repaired document had no root element.

The change `judge-dtd-content-in-upload-scan` already parses a file that declares an entity in
strict mode.

## Goals / Non-Goals

**Goals:**

- The scan gives a verdict only on a document that a browser also builds.

**Non-Goals:**

- No probe found a file that runs a script in a browser and passes the scan because of the recover
  mode. This change makes the code do what the requirement says.
- The scan of an HTML file does not change. An HTML parser reports no fatal error.

## Decisions

**D1. The XML parse is strict.** `parse_document` parses with the `strict` and `nonet` options. A
fatal error raises `Nokogiri::XML::SyntaxError`, and the checker refuses the file. Probes with
Nokogiri 1.19.7 show what raises.

These errors raise:

- An element with no end tag.
- Text after the root element.
- An attribute that an element has two times.
- A byte that is not valid in the encoding of the file.
- An undeclared entity in a file with no DOCTYPE.
- A file past a limit of the parser: 300 levels of `g` elements, or an attribute value of 11 MB.
  Chrome 158 shows these two files with no error.

These errors do not raise:

- A prefix with no namespace.
- A namespace URI that is not absolute.
- An undeclared entity in a file whose DOCTYPE names an external DTD, unless the file has
  `standalone="yes"`. An XHTML file with `&nbsp;` and the public XHTML DOCTYPE is such a file.

- *Alternative: change the requirement to say what the code did.* Rejected: a verdict on a repaired
  document is a verdict on a document that no browser shows.

**D2. The checker refuses each `xml-stylesheet` processing instruction.** The rule holds at any
place in an XML file and for any type. A browser reads the instruction only before the root element,
but a rule for one place adds a case and no value. The rule also runs in HTML mode, for each
instruction that the parser of the scan keeps as a node. A browser reads it there as a comment.

The HTML parser keeps no node for `<!DOCTYPE html [<?xml-stylesheet href="x.css"?>]>`, and that
file passes. Chrome 158 reads that text as a part of the DOCTYPE.

The XPath of the tree does not reach each child of the DTD. So the checker also reads the
instructions of the DTD, and it refuses an `xml-stylesheet` instruction there. Chrome 158 does not
load the stylesheet of an instruction in the DTD.

Chromium 156 and Chrome 158 applied the CSS file that the instruction of an SVG file names. In
both, an XML file with an XSL instruction shows no result, and Chromium 156 does not define
`XSLTProcessor`. So no probe ran an XSLT stylesheet. The rule for XSLT fails closed for the browsers that
have XSLT.

**D3. The checker refuses each file that declares the XSLT namespace.** The checker reads the
namespace declarations of each element. They hold a namespace that an entity gives, in the
expanded document, and one that an attribute default of the DTD gives. A declaration that no element
uses refuses the file too. Text that names the namespace URI does not.

- *Alternative: the XPath namespace axis, `//namespace::*`.* Rejected: the axis gives each element
  one node for each namespace in scope. With the axis, the check of a file of 30 KB with 1000
  namespaces and 2000 elements took 10 seconds.
- *Alternative: refuse only the instructions that build a name, such as `xsl:element` and
  `xsl:attribute`.* Rejected: XSLT has more ways to give output, such as `xsl:copy-of`,
  `xsl:value-of` with `disable-output-escaping`, and `xsl:include`. A list of them is a denylist of
  a programming language.
- *Alternative: add `xsl` and `xslt` to the script extensions.* Rejected: a browser loads a
  stylesheet by its address, so a stylesheet in an `.xml` file works too.

**D4. The task reads the whole contact form folder.** The task scans `public/contact_form`, where
`ContactFormControllerConcern#perform_save_form` of `cama_contact_form` stores a file under
`<site id>`. The plugin names that folder by the site id, also when `media_slug_folder` is set. The
folder of a deleted site can stay in `public/`, and the web server still serves its files. So the
task does not limit the scan to the sites that exist.

- *Alternative: scan `public/contact_form/<site id>` for each site that exists.* Rejected: the
  report then leaves out the files of a deleted site, which a visitor stored and the server still
  serves.
- *Alternative: a hook that lets a plugin name its folders.* Rejected for now: the contact form
  folder is the one such folder that this change found.

## Risks / Trade-offs

- [A role without `media_unfiltered_upload` uploads XSLT stylesheets today] → Each stylesheet with
  an `xsl:template` element was refused already. The upgrade guide names the permission.
- [A user uploads an SVG file with a fatal XML error that an editor tolerated] → Chrome 158 shows
  an error for a file with an element that has no end tag. The upgrade guide names the change, the
  limits of the parser and a command that shows the error.
