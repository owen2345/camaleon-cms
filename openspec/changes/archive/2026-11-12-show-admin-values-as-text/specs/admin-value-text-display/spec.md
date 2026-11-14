## Purpose

The post form shows a tag name as text in its tag editor and the slug as text in its permalink line.
The media manager shows the `folder` param as text in its breadcrumb. The media manager shows the
`dimension` param as text in the details of an image and in the title of the image editor. The media
manager shows the name and the URL of a file as text in the details of the file and in the image
editor. The Featured Image panel of the post form shows the name of a picked file as text. In these
places, markup in such a value adds no element to the admin page.

The Upload Image link of the Featured Image panel gives the image options of the post type to its
handler as attribute values. A quote in such an option runs no script. The form of a custom field
group shows the help of a placement, and the name of a field, as text. A select with the bundled
bootstrap-select library shows the label of an option group as text. The upload plugin of the media
manager shows the name of a selected file as text. The list of the media manager gives the data of
each file to its script as text.

The `I18n` function of the admin JavaScript reads each value of a translation as text.

## ADDED Requirements

### Requirement: The tag editor shows a tag name as text

The tag editor of the post form SHALL show each tag name as text. A name with markup MUST NOT add
an element to the form. A click on a tag opens it: the editor puts the name into a text input, and
that input SHALL hold the whole name. A name that the admin types again, alone or in a list with a
delimiter, SHALL replace its tag. The editor SHALL give a tag name as text to the `beforeTagDelete`
callback, and its `removeTag` method SHALL take a name as text. For an open tag, the callback SHALL
get the name that the tag had when the admin opened it. The editor SHALL NOT call the callback for a
new tag, which has no such name. A right click SHALL delete an open tag with no text, and MUST NOT
throw an error. A right click on an open tag SHALL delete only that tag, and MUST NOT call the
`beforeTagSave` callback.

The editor SHALL give the name that a tag had to the `old_tag` argument of the `beforeTagSave`
callback, as text.

#### Scenario: A stored tag name with markup

- **WHEN** an admin opens the edit form of a post with a tag whose name holds `img` markup with an
  `onerror` handler
- **THEN** the tag editor shows the whole name as text and adds no `img` element

#### Scenario: A link with the tags param

- **WHEN** an admin opens the form of a new post through a GET link whose `tags` param holds `img`
  markup
- **THEN** the tag editor shows the value as text and adds no `img` element

#### Scenario: The admin opens a tag whose name holds a quote

- **WHEN** the admin opens a tag whose name holds a double quote and an `onfocus` attribute
- **THEN** the text input of the tag holds the whole name and has no `onfocus` attribute

#### Scenario: The admin renames, removes and adds tags

- **WHEN** the admin renames a tag, removes a tag and adds a tag in the tag editor, and saves the post
- **THEN** the post holds the tags that the editor shows, also a tag with `&` in its name

#### Scenario: The admin adds a tag name with markup

- **WHEN** the admin adds a tag whose name holds `img` markup, alone and then in a list with a
  delimiter
- **THEN** the tag editor shows the whole name as text and adds no `img` element

#### Scenario: The admin types names that exist already

- **WHEN** the admin types a list in an open tag, and the list holds the name of that tag and of
  another tag
- **AND** the admin then types the name of a tag again
- **THEN** the tag editor holds one tag for each of these names, also for a name with `&`

#### Scenario: The code of a plugin deletes tags

- **WHEN** a tag editor with a `beforeTagDelete` callback holds tags with `&` or `<` in their names
- **AND** a right click, the `removeTag` method and the Delete key on the selected tags each delete
  one tag
- **THEN** the callback gets each name as text

#### Scenario: The code of a plugin deletes an open tag

- **WHEN** a tag editor with a `beforeTagDelete` callback holds an open tag whose text the admin
  changed, and a new tag with typed text
- **AND** a right click deletes each of the two tags
- **THEN** the callback gets one call, with the name that the first tag had when the admin opened it

#### Scenario: A right click deletes an open tag with no text

- **WHEN** a tag editor with the `clickDelete` option holds a new tag with no text, or an open tag
  whose text the admin removed
- **AND** a right click deletes that tag
- **THEN** the editor removes the tag and throws no error

#### Scenario: A right click deletes an open tag with typed text

- **WHEN** a tag editor with the `clickDelete` option holds two tags
- **AND** the admin opens one tag, types the name of the other tag and deletes the open tag with a
  right click
- **THEN** the editor removes only the open tag
- **AND** the `beforeTagSave` callback gets no call

#### Scenario: The code of a plugin reads the old name of a tag

- **WHEN** a tag editor with a `beforeTagSave` callback holds a tag with `&` in its name
- **AND** the admin opens that tag and types another name
- **THEN** the callback gets the old name as text in its `old_tag` argument

### Requirement: The permalink line of the post form shows the slug as text

The permalink line of the post form SHALL show the slug of the post as text, inside the URL of the
post. A slug with markup MUST NOT add an element to the form. The Preview link and the View link of
the line SHALL hold the slug as one segment of the path of the URL. A slug with `?` or `#` MUST NOT
change the query or the fragment of a link. The characters that Rails writes as they are in a
segment of a path SHALL stay as they are in the links. A draft save SHALL change only the draft id
of the Preview link.

For a URL with no place for the slug, the line and the links SHALL hold that URL as it is. The line
SHALL then have no Edit link. With no URL for the language of the form, the form SHALL start. The
line SHALL then show the slug alone, with no Preview link and no View link.

#### Scenario: A stored slug with a tag

- **WHEN** an admin opens the edit form of a post whose slug holds an `img` tag with an `onerror`
  handler
- **THEN** the permalink line shows the whole slug as text and adds no `img` element

#### Scenario: A plain slug

- **WHEN** an admin opens the edit form of a post with a plain slug
- **THEN** the permalink line shows the URL of the post, with the slug in it

#### Scenario: A stored slug with a replacement pattern

- **WHEN** an admin opens the edit form of a published post whose slug holds `$&`
- **THEN** the Preview link and the View link hold the URL that the permalink line shows

#### Scenario: A stored slug with a question mark and a number sign

- **WHEN** an admin opens the edit form of a published post whose slug holds `?`, `#` and a space
- **THEN** the Preview link and the View link hold these characters in their percent-encoded form
- **AND** the Preview link keeps its `draft_id` param

#### Scenario: A stored slug with characters that a segment of a path can hold

- **WHEN** an admin opens the edit form of a published post whose slug holds `+`, `,`, `;`, `=`,
  `:` and `@`
- **THEN** the Preview link and the View link hold the URL that the permalink line shows

#### Scenario: A draft save for a slug that holds the text of the draft param

- **WHEN** an admin opens the edit form of a post whose slug holds `&draft_id=`, and the form saves a
  draft
- **THEN** the Preview link holds the URL that the permalink line shows, with the id of the draft

#### Scenario: A draft save for a Preview link with one more param

- **WHEN** other code adds a param after the draft id of the Preview link, and the form saves a draft
- **THEN** the Preview link holds the id of the draft and keeps that param

#### Scenario: The admin edits the slug

- **WHEN** an admin clicks Edit in the permalink line, types a slug and clicks Cancel
- **THEN** the line shows the same URL as before
- **WHEN** the admin clicks Edit again, types a slug and clicks Accept
- **THEN** the line shows one URL, with the new slug in it

#### Scenario: A URL with no place for the slug

- **WHEN** a post decorator gives a URL with no placeholder for the slug
- **THEN** the permalink line, the Preview link and the View link hold that URL, with no slug after it
- **AND** the line has no Edit link

#### Scenario: No URL for the language of the form

- **WHEN** a post decorator gives no URL for the language of the form
- **THEN** the form starts, and the permalink line shows the slug alone
- **AND** the line has no Preview link and no View link

### Requirement: The media manager shows the params of its page as text

The media manager SHALL show the `folder` param of its page as the text of its breadcrumb. It SHALL
show the `dimension` param as text in the details of an image and in the title of the image editor.
A param with markup MUST NOT add an element to the page. The image editor SHALL start for a
`dimension` param that has a part with no digit. Such a part SHALL set no size limit.

#### Scenario: A link with a tag in the folder param

- **WHEN** an admin opens the media manager through a link whose `folder` param holds an `img` tag
- **THEN** the breadcrumb shows the value as text and adds no `img` element

#### Scenario: A link with a tag and a quote in a parent folder

- **WHEN** an admin opens the media manager through a link whose `folder` param holds an `img` tag and
  a quote in its parent folders
- **THEN** the breadcrumb shows each parent folder as the text of a link, and adds no `img` element

#### Scenario: A folder path

- **WHEN** an admin opens the media manager with the `folder` param `/photos/2026`
- **THEN** the breadcrumb holds a link for the root and for `photos`, and the text `2026`

#### Scenario: A link with a tag in the dimension param

- **WHEN** an admin opens the media manager through a link whose `dimension` param holds an `img`
  tag, clicks an image, and opens the image editor
- **THEN** the details of the image and the title of the editor show the value as text and add no
  `img` element

#### Scenario: A dimension param with no digit

- **WHEN** an admin opens the media manager with the `dimension` param `abc`, and opens the image
  editor
- **THEN** the editor shows the image, and the width and the height have no limit

#### Scenario: A dimension param whose height has no digit

- **WHEN** an admin opens the media manager with the `dimension` param `30xabc`, and opens the
  image editor
- **THEN** the editor shows the image with the width 30, and the height has no limit

### Requirement: The media manager shows the name and the URL of a file as text

The media manager SHALL show the name and the URL of a file as text in the details of the file. The
image editor SHALL show the name as text in its title, and SHALL set the URL as the source of its
image. The message of a failed image request SHALL show the URL as text. A name or a URL with markup
MUST NOT add an element to the page.

#### Scenario: A file in a folder with markup in its name

- **WHEN** an admin clicks a file whose name and folder hold `img` markup and a quote
- **THEN** the details show the name and the URL as text, and the link holds the whole URL

#### Scenario: The image editor of a file in a folder with markup in its name

- **WHEN** an admin opens the image editor for an image whose name and folder hold `img` markup and
  a quote
- **THEN** the title shows the name as text, and the image has the whole URL as its source

#### Scenario: A failed image request in the image editor

- **WHEN** the image editor cannot read such an image again
- **THEN** its message shows the URL as text and adds no `img` element

#### Scenario: A failed image request for a URL with a replacement pattern

- **WHEN** the image editor cannot read again an image whose folder name holds `$&`
- **THEN** its message shows the whole URL as text

### Requirement: The list of the media manager gives the data of a file as text

The list of the media manager SHALL write the JSON data of each file as text in its hidden
`textarea`. The data MUST NOT add an element to the page, also for a host app that turns off the
`escape_html_entities_in_json` setting of Active Support. The script of the media manager SHALL get
the same data as before.

#### Scenario: A host app writes JSON with no HTML escapes

- **WHEN** a host app sets `escape_html_entities_in_json` to `false`
- **AND** an admin opens a folder whose path holds a closing `textarea` tag and an `img` tag
- **THEN** the list adds no `img` element from that path
- **AND** a click on the file shows its whole URL in the details

### Requirement: The Featured Image panel of the post form shows the name of a file as text

The Featured Image panel of the post form SHALL show the name of the file that the admin picks as
text. A name with markup MUST NOT add an element to the form.

#### Scenario: The admin picks a file with markup in its name

- **WHEN** an admin picks a file whose name holds `img` markup as the featured image of a post
- **THEN** the panel shows the whole name as text and adds no `img` element

### Requirement: The Upload Image link gives the options of the post type to its handler as text

The Upload Image link of the Featured Image panel SHALL hold three options of the post type as
attribute values. The options are `posts_thumb_versions`, `posts_thumb_size` and
`posts_image_dimension`. The handler of the link SHALL read them from there. An option with a quote
MUST NOT run as script.

#### Scenario: A post type option with a quote

- **WHEN** a post type holds an image option with a quote and script after it
- **AND** an admin clicks Upload Image in the form of a post of that type
- **THEN** the file picker gets the whole option as text, and the script does not run

### Requirement: The custom field group form shows the help of a placement as text

The form of a custom field group SHALL show the help of the selected placement as text. The help can
hold the name of a category, a post type or a post. A name with markup MUST NOT add an element to
the form. The `data-help` attribute of an option with such a name SHALL hold the name with one
escape. The form then shows the name as the author wrote it. A selected placement with no help
SHALL show no help.

#### Scenario: A group of a category with markup in its name

- **WHEN** an admin opens the edit form of a custom field group whose placement is a category with
  `img` markup in its name
- **THEN** the help shows the whole name as text and adds no `img` element

#### Scenario: A group of a post type with markup in its name

- **WHEN** an admin opens the edit form of a custom field group whose placement is the posts of a
  post type named `Ben & Jerry's <b>x</b>`
- **THEN** the help shows the name as the author wrote it and adds no `b` element

#### Scenario: A group of a post with markup in its title

- **WHEN** an admin opens the edit form of a custom field group whose placement is a post with
  `img` markup in its title
- **THEN** the help shows the whole title as text and adds no `img` element

#### Scenario: The admin selects a placement with no help

- **WHEN** an admin opens the edit form of a custom field group whose placement has a help
- **AND** the admin selects a placement with no help
- **THEN** the form shows no help

#### Scenario: The help attribute of a placement option

- **WHEN** a post type and a post are named `Ben & Jerry's <b>x</b>`
- **AND** an admin opens the form of a new custom field group
- **THEN** the `data-help` attribute of each option of that post type, and of that post, reads the
  name literally

### Requirement: The custom field group form shows the name of a field as text

The form of a custom field group SHALL show the name of a field as text in the title of the panel
of that field. A name with markup MUST NOT add an element to the form.

#### Scenario: The admin changes a field name with markup

- **WHEN** an admin opens the edit form of a custom field group that has a field with an `img` tag
  in its name
- **AND** the admin types in the name input of that field
- **THEN** the title of the panel shows the whole name as text and adds no `img` element

### Requirement: A select of the admin shows the label of an option group as text

The bundled bootstrap-select library SHALL show the label of an option group as text. A label with
markup MUST NOT add an element to the page.

#### Scenario: The Front Cache settings page for a post type with markup in its name

- **WHEN** a post type with a post holds `img` markup in its name
- **AND** an admin opens the Front Cache settings page
- **THEN** each list of posts shows the whole name as the text of a group header and adds no `img`
  element

### Requirement: The upload plugin shows the name of a selected file as text

The bundled upload plugin of the media manager SHALL show the name of a selected file as text in its
status bar. It SHALL show the name as text in each message that refuses a file. A name with markup
MUST NOT add an element to the page.

#### Scenario: The admin selects a file with markup in its name

- **WHEN** an admin selects a file whose name holds `img` markup in the media manager
- **THEN** the status bar shows the whole name as text and adds no `img` element

#### Scenario: The plugin refuses a file with markup in its name

- **WHEN** code starts the plugin with an option that refuses such a file
- **AND** the option is a limit on the file type, the file size, the count of files or a second
  file with the same name
- **THEN** the message shows the whole name as text and adds no `img` element

#### Scenario: Code adds a status bar with createProgress

- **WHEN** code calls `createProgress` of the plugin with such a name
- **THEN** the status bar shows the whole name as text and adds no `img` element

### Requirement: The I18n function of the admin JavaScript reads a value as text

The `I18n` function SHALL put each value of its third argument into the translation as text. A
replacement pattern of JavaScript in a value, such as `$&`, MUST NOT change the result. A value
that holds a placeholder SHALL stay as it is. The function SHALL replace each occurrence of a
placeholder, and SHALL keep a placeholder with no value. The function SHALL return a translation
that is not a String as it is.

#### Scenario: A value with a replacement pattern

- **WHEN** code calls `I18n` with a value that holds the patterns `$&`, `$'` and `$$`
- **THEN** the result holds the value as it is

#### Scenario: A value that holds a placeholder

- **WHEN** code calls `I18n` with a value that holds the placeholder of a later value
- **THEN** the result holds that placeholder as text

#### Scenario: A placeholder with no value

- **WHEN** code calls `I18n` with a number for one placeholder and no value for a second placeholder
- **THEN** the result holds the number, and keeps the second placeholder

#### Scenario: A placeholder that the translation holds twice

- **WHEN** code calls `I18n` for a translation that holds one placeholder twice
- **THEN** the result holds the value at both places

#### Scenario: A translation that is not a String

- **WHEN** code calls `I18n` for a key whose translation is a list, or with a number as the default
  value
- **THEN** the function returns that value as it is
