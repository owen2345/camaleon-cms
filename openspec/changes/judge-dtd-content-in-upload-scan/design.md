# Design

## Context

See `proposal.md`, "Why". `CamaleonCms::SvgContentChecker` parses a file in an XML format with
`Nokogiri::XML` and the default options, which hold `RECOVER` and `NONET`. Its checks then read the
tree: the banned elements, each attribute whose name starts with `on`, the scheme of each `href`,
and the serialized document.

These facts come from probes with Nokogiri 1.19.7 (libxml2 2.13.9) and Chromium 156:

- Chromium ran the handler of three files that the server sent as `image/svg+xml`. Their entity
  values held `&#111;nerror`, a `foreignObject` element, and an entity that a parameter entity
  declares. It ran the handler of an `.xml` file whose entity holds an XHTML `img` element.
- Chromium ran the `onload` default of `<!ATTLIST svg onload CDATA "...">`. The tree of the parser
  does not hold a default. The `dtdattr` option adds the defaults, and it also tries to load the
  external DTD of the file.
- With the `noent` option, the tree holds the elements and the attributes of each entity value. An
  attribute default then holds the value of each entity that it refers to.
- With the `noent` option, the parser reads a local file that an entity with `SYSTEM` names.
- Chromium 156 did not load an entity with `SYSTEM` from the same origin.
- libxml2 reports a fatal error for entities that expand past its limit. It reports that error with
  and without `noent`, and it stops at the limit.

## Goals / Non-Goals

**Goals:**

- The scan reads the markup that an entity gives in a browser, for each format that takes the XML
  parse.
- The scan reads no other resource, and an entity bomb costs it no more than the parser limit
  permits.
- A file with harmless entities passes.

**Non-Goals:**

- A file that declares no entity keeps its parse in recover mode. The scan still accepts such a
  file with a fatal XML error when a root element is there.
- The byte patterns of `CamaleonCms::ContentSecurity` do not change.
- A stored file is not scanned again and is not changed.

## Decisions

**D1. A second parse expands the entities.** When the DTD of the file declares an entity, the
checker parses the file again with the `strict`, `nonet` and `noent` options. Its checks then read
that tree, and no check changes. The tree holds the elements and the attributes that an XML parser
of a browser builds from the entities of the file. It does not hold the attribute defaults of the
DTD, which D5 reads.

- *Alternative: parse each entity value alone as a fragment.* Rejected: the scan then decides how a
  value combines with its context, and each difference from the browser is a new gap.
- *Alternative: refuse each file that declares an entity.* Rejected: an SVG file of Adobe
  Illustrator declares its namespaces as entities. `docs/security/permissions.md` asks for a
  verdict on the content when a scan can give one.
- *Alternative: use `noent` for each file in one parse.* Rejected, because of D2.

**D2. An entity of another resource is refused before the second parse.** The checker reads the
entity declarations of the first parse. That parse loads no resource. When a declaration has a type
other than internal general or internal parameter, the checker refuses the file and does not parse
it again. The list of the first parse holds the entities that a parameter entity declares.

Chromium 156 did not load such an entity, but the scan cannot know the content that another client
loads. So the scan fails closed.

**D3. The parser limit is the limit of the expansion.**

libxml2 counts the expanded size during the parse, and it stops with a fatal error past its limit.
The `strict` option makes Nokogiri raise that error. The checker then refuses the file.

libxml2 2.13.9 refused a file of 160 KB that expands to 2 GB in 2 ms. It accepted a file of 4 KB
that expands to 0.9 MB, and it refused one that expands to 1 MB. The checker must never set the
`huge` option, which removes the limit.

Before this change, the scan accepted the 160 KB file. ImageMagick then read it for the thumbnail,
and it still ran after 20 seconds with 258 MB of memory.

- *Alternative: count the expanded size in Ruby before the parse.* Rejected: the count needs the
  number of references, from a scan of the raw bytes. That scan misses a reference in an encoding
  that is not ASCII-compatible, so the parser limit stays the real limit.

**D4. The second parse is strict.** A fatal error in a file that declares an entity refuses the
file. The checker can tell an entity bomb from another fatal error only with a list of libxml2
error codes. A browser shows an error page for each fatal error. An undeclared entity in a file
with an internal DTD and no external DTD is such an error.

**D5. The checker reads an attribute default from its declaration.** For each `ATTLIST`
declaration with a default, the checker applies the handler rule to the name and the scheme rule to
the default. It reads the declarations of the expanded document when the file declares an entity.
A declaration with `#IMPLIED` or `#REQUIRED` gives no attribute, so it passes. The checker refuses a
default also when no element of the file has the name that the declaration gives.

A default with the `xmlns` prefix declares a namespace, so the handler rule does not apply to its
name.

- *Alternative: the `dtdattr` option, which puts each default in the tree.* Rejected: the option
  makes the parser load the external DTD, from the network or from a local file.

## Risks / Trade-offs

- [A file with entity declarations and a fatal XML error is now refused] → The parser gives no
  document for such a file, so the checker has nothing to judge. The upgrade guide names the
  change.
- [Another libxml2 version can have another limit] → The checker does not hold a number. It
  refuses on each fatal error of the parser.
- [The second parse doubles the parse time of a file with entities] → Only a file that declares an
  entity gets the second parse.
