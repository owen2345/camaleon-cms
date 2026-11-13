## Purpose

The post form shows a tag name as text in its tag editor and the slug as text in its permalink line.
The media manager shows the `folder` param as text in its breadcrumb. The media manager shows the
`dimension` param as text in the details of an image and in the title of the image editor. The media
manager shows the name and the URL of a file as text in the details of the file and in the image
editor. The Featured Image panel of the post form shows the name of a picked file as text. In these
places, markup in such a value adds no element to the admin page.

## ADDED Requirements

### Requirement: The tag editor shows a tag name as text

The tag editor of the post form SHALL show each tag name as text. A name with markup MUST NOT add
an element to the form. A click on a tag opens it: the editor puts the name into a text input, and
that input SHALL hold the whole name. A name that the admin types again, alone or in a list with a
delimiter, SHALL replace its tag. The editor SHALL give a tag name as text to the `beforeTagDelete`
callback, and its `removeTag` method SHALL take a name as text.

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

### Requirement: The permalink line of the post form shows the slug as text

The permalink line of the post form SHALL show the slug of the post as text, inside the URL of the
post. A slug with markup MUST NOT add an element to the form. The Preview link and the View link of
the line SHALL hold the slug as the post stores it.

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

### Requirement: The media manager shows the params of its page as text

The media manager SHALL show the `folder` param of its page as the text of its breadcrumb. It SHALL
show the `dimension` param as text in the details of an image and in the title of the image editor.
A param with markup MUST NOT add an element to the page.

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

### Requirement: The Featured Image panel of the post form shows the name of a file as text

The Featured Image panel of the post form SHALL show the name of the file that the admin picks as
text. A name with markup MUST NOT add an element to the form.

#### Scenario: The admin picks a file with markup in its name

- **WHEN** an admin picks a file whose name holds `img` markup as the featured image of a post
- **THEN** the panel shows the whole name as text and adds no `img` element
