# Design

## Context

See `proposal.md`, "Why". Each value is text that the page shows to the admin. The page does not
use it as markup.

## Goals / Non-Goals

**Goals:**

- A value that the admin JavaScript shows adds no element to the admin page.

**Non-Goals:**

- A scan of a tag name at save. The stored name stays as the author wrote it.
- The `tags` param of a GET request. The post form still shows it, as text.
- A scan or a change of a slug at save. A stored slug, and each URL that holds it, stays as it is.
- A check of the `folder` param or of the `dimension` param in the media controller. An unknown
  folder still gives an empty list.
- The name and the URL of a file in the media manager. They come from the list of the server.

## Decisions

**D1. The fix is at the code that writes the HTML.** The code sets the value as text, or encodes it
before the value joins an HTML string. That is the normal output encoding of a value, as `<%= %>`
gives it in a view. The remedy rule (`docs/security/permissions.md`) is about content that an author
stores as markup, and these values are no markup. One fix covers a stored value and the value of a
link.

- *Alternative: refuse a tag name with markup at save.* Rejected: a scan at save cannot reach the
  `tags` param of a link, and the code that writes the HTML stays wrong.
- *Alternative: read no `tags` param on a GET request.* Rejected: it closes only the link.

**D2. The tag editor reads a tag as text.** The editor read a tag back with `.html()` to compare
names, and to fill the text input that a click on a tag opens. For a name that the editor shows as
text, `.html()` returns the encoded form. So the editor reads a tag with `.text()` and sets the input
with `.val()`. The `beforeTagDelete` callback, the `old_tag` argument of `beforeTagSave` and the
`removeTag` method use the name as text too.
