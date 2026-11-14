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
- A check of a folder name at an upload or at the creation of a folder. A folder with markup in its
  name stays valid.
- A check of an image option of a post type at save. A stored option stays as it is.
- A scan of a category name at save. The stored name stays as the author wrote it.
- A scan of a post type name at save. The stored name stays as the author wrote it.
- The language codes of a site in the tabs of a translatable field. Only a role with the `settings`
  permission stores them, and that role is trusted (`docs/security/permissions.md`, "The gating
  rule").
- The JSON that the admin layout, `_get_items`, `_meta_data` and the post form write into a `script`
  element. Rails escapes `<` in JSON by default. Camaleon renders three of these views, and their
  values come from a role with the `settings` or the `custom_fields` permission.

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
`removeTag` method use the name as text too. The right-click delete of an open tag gives
`beforeTagDelete` the name that the tag had when the admin opened it.

**D3. The media manager sets the name and the URL of a file as text.** The URL of a file holds the
names of its folders. An upload and the creation of a folder take the folder from the request, and
the server refuses only `..` and `://` in it. So the URL is a value of a request, as the `folder`
param is. An upload cleans the name of a file, but a file that reaches the storage another way keeps
its name.

- *Alternative: refuse a folder name with markup.* Rejected: a stored folder with such a name keeps
  its files, and the code that writes the HTML stays wrong.

**D4. One function encodes text for an HTML string.** `cama_escape_html` in `_modal.js` encodes text
for the content of an element. The media manager and the post form call it. The function is in
`_modal.js`, because `uploader_manifest.js` loads that file. A plugin such as `camaleon-spree` loads
the uploader manifest without `_libraries.js`.

**D5. The message of a failed image request gets the URL as the text of an element.** The message
is HTML, and the URL is text. So the template gets an empty element for the URL, and the code sets
the URL as the text of that element. Before D16, `I18n` also read a pattern such as `$&` in a value,
and changed a value that held a later placeholder.

**D6. The Featured Image panel of the post form sets the name of a picked file as text.** The panel
gets the file that the admin picks in the media manager. The name of that file can hold markup (D3),
so the panel sets it as text.

**D7. The Upload Image link holds the options of the post type as attribute values.** The link put
the three image options of the post type into the JavaScript of its `onclick` attribute. A view
escapes a value for HTML, and the browser decodes it before it reads the handler, so a quote ended
the String. The link now holds each option in a `data-` attribute, and the handler reads it from
there. The image field of a custom field group gives its options the same way.

- *Alternative: escape each option for JavaScript with `j`.* Rejected: the value stays in the code
  of the handler, and each new option needs the same escape.
- *Alternative: refuse an option that is no list of sizes at save.* Rejected: a stored option stays,
  and the code that writes the handler stays wrong.

**D8. The custom field group form sets the help of a placement as text.** The form put the
`data-help` of the selected option into HTML. The option of a category gives its name with one
escape since 2.9.3, so a name with a tag added an element. The other options with a name gave it
with two escapes, and the HTML write hid that. The form now sets the help as text, and each of these
options gives its name with one escape.

The form also kept the help of a placement when the admin selected a placement with no help. It
now removes that help.

For a key with no translation, the view helper `t` gives an html_safe span, and `safe_join` kept
that span as markup in the `data-help` attribute. Each of these options now gives its translation as
a plain String, which `safe_join` escapes.

- *Alternative: give the category name with two escapes again.* Rejected: the requirement of
  `escaped-title-composition` asks for the literal name in the attribute, and the code that writes
  the HTML stays wrong.

**D9. The bundled bootstrap-select encodes the label of an option group.** The library put the
`label` property of an `optgroup` element into the HTML of a group header. The browser decodes the
attribute, so the escape of the view gave no protection. The Front Cache settings page gives the
name of each post type as such a label. The library now encodes the label first, and each select
with option groups gets the fix.

- *Alternative: a newer release of the library.* Rejected: a new release changes much more than
  this one line.
- *Alternative: no bootstrap-select on the Front Cache settings page.* Rejected: the page loses the
  search in its lists, and each other select with option groups keeps the path.

**D10. The bundled upload plugin sets the name of a file as text.** The plugin put the name of each
selected file into the HTML of its status bar, and into each message that refuses a file. The status
bar now gets the name with `.text()`, and a function `camaText` encodes the name for a message. The
media manager sets no option that refuses a file, but a plugin or a theme can set one. The code for
a browser with no File API gets the same call, and no example can reach that code.

- *Alternative: no change, because the user selects the file.* Rejected: another person can give
  the file to the user, and the code that writes the HTML stays wrong.

**D11. A part of the dimension with no digit sets no size limit.** The image editor reads a number
from each part of the `dimension` param. A part with no digit gave no number, and the code that
starts the editor threw. The loading bar then stayed on the page. The editor now reads such a part
as an empty part.

- *Alternative: refuse the param in the media controller.* Rejected: a check of the param there is
  a Non-Goal.

**D12. A link holds the slug as one segment of the path.** `post_url` joined the raw slug into the
URL of the Preview link and of the View link. A slug with `?` or `#` then ended the path, and the
link lost its draft id. `post_url` now encodes the slug, and then restores the characters
`$ & + , ; = : @`, which Rails writes as they are in a segment of a path. The permalink line still
shows the slug as the post stores it.

- *Alternative: remove `?` from the slug that the form makes.* Rejected: a stored slug with `?` or
  `#` keeps its wrong links.

**D13. The blur handler leaves a tag that the right-click delete removes.** Chrome fires blur on the
text input of an open tag when the tag leaves the page. The blur handler then read the input as a
new tag. It removed a tag with no text again, so the removal of the right-click delete threw
`NotFoundError`. For typed text, it called `beforeTagSave` and removed a closed tag with that name.

The right-click delete marks its tag before the removal, and the blur handler now returns for such
a tag. Only an editor with the `clickDelete` option has this delete, and the post form does not set
that option.

- *Alternative: catch the error of the second removal.* Rejected: the blur handler still saves the
  typed text of the tag that the admin deletes.

**D14. The list of the media manager writes the data of a file with the HTML escape.** The view
wrote the JSON of each file into a hidden `textarea` with `raw`. Rails writes `<` and `&` of JSON as
escapes, but a host app can turn that setting off. A folder name with a closing `textarea` tag then
ended the element, and the markup after it ran. The view now writes the JSON with `<%= %>`, and the
browser gives the same text to the script.

**D15. A URL with no placeholder stays as it is.** The form splits the URL of the post at the
placeholder `__-__`, and joined the slug to the end of a URL with no placeholder. The line and the
links now hold such a URL as it is. With no URL for the language of the form, the code that starts
the form threw. The form now shows the slug alone, and removes the Preview link and the View link.

The line shows no slug for a URL with no placeholder, so its Edit link opened no input. The form now
removes that link.

**D16. `I18n` puts each value into a translation as text.** The function gave each value to
`String.prototype.replace` as a replacement String, and replaced one placeholder after the other.
It now replaces the placeholders in one pass, with a function that returns the value. So it also
replaces each occurrence of a placeholder, where the old code replaced only the first. The element
of D5 stays, because the message is HTML and the URL is text.

A translation that is not a String has no placeholder. The function returns it as it is, as the old
code did for a call with no values.

**D17. The custom field group form sets the name of a field as text.** The form wrote the value of
the name input of a field into the HTML of the title of its panel. A role with the `custom_fields`
permission can store a field name with markup. So the form now sets the name as text.
