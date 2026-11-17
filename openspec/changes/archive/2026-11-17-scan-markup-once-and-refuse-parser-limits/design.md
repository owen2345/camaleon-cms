# Design

## Context

See `proposal.md`, "Why". `Nokogiri::XML::DocumentFragment#css` calls `NodeSet#css` on the children
of the fragment. `NodeSet#css` runs the query on each node and adds the result to the set so far
(`set + result`). So the cost grows with the square of the number of top-level nodes.
`DocumentFragment#xpath` does not do this: it runs once on the fragment.

## Decisions

### D1: One walk with no recursion, over element children

The gate walks the tree with a list of pending nodes, not with `Node#traverse`, which recurses. The
walk reads only element children, because only an element contains elements. A probe on a value
with 36,000 translated blocks: the walk over all children took 0.43 s, the walk over element
children 0.07 s. `traverse` and `fragment.xpath('.//*')` were slower than the walk.

### D2: One list for the three checks

The css check writes the scrubbed style back to its node. It changes only attribute values, so the
list of the elements stays correct for the two checks after it.

### D3: Refuse a value that the parser cannot read

`parse` catches `ArgumentError` and gives `nil`, and `unsafe_html?` then refuses the value. The gate
cannot scan such a value, so it fails closed. This holds for each `ArgumentError` of the parser, not
only for the two limits that we know. The limits stay at the defaults of Nokogiri: a higher limit
makes a deeper tree, and Loofah scrubs the tree with recursion.

The author gets the markup refusal, not a new message. The value can be clean, but such a depth or
attribute count does not occur in authored content.

The fallback parser of an older Loofah (`Loofah.fragment`) does not raise. It drops the elements
past its depth limit, and the check for dropped tags refuses the value.
