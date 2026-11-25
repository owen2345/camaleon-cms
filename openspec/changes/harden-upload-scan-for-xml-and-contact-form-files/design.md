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

## Risks / Trade-offs

- [A user uploads an SVG file with a fatal XML error that an editor tolerated] → Chrome 158 shows
  an error for a file with an element that has no end tag. The upgrade guide names the change, the
  limits of the parser and a command that shows the error.
