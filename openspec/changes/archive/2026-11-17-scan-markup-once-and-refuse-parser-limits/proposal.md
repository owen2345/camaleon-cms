# Scan markup once, and refuse a value past the parser limits

## Why

`CamaleonCms::UnsafeMarkup.unsafe_html?` is the markup gate of post content, of the post summary and
of custom-field values. It had two defects:

- It searched the parsed fragment with `fragment.css` in three checks. A Nokogiri fragment runs such
  a search once for each top-level node and adds each result to the set so far. The cost grows with
  the square of the number of top-level nodes, and each translated block adds top-level nodes. A
  value with 20,000 translation markers took about 27 s to scan.
- The HTML5 parser raises `ArgumentError` past 400 nested elements, or past 400 attributes on one
  element. The gate did not catch the error, so a save of such content gave a server error.

## What Changes

- The gate gets the elements of the parse from one walk of the tree, with no recursion. The three
  checks share that list. The value of the example above now scans in about 3 s.
- The gate refuses a value that its parser cannot read. The author gets the markup refusal.
- For a value that the gate could read before, no verdict changes.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `post-content-sanitization`: two new requirements of the shared markup gate.

## Impact

- `lib/camaleon_cms/unsafe_markup.rb`.
- `spec/lib/camaleon_cms/unsafe_markup_spec.rb`, `spec/models/post_content_rejection_spec.rb`.
- No public API changes.
