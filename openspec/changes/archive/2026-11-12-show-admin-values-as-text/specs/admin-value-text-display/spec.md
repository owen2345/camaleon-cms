## Purpose

The admin JavaScript shows a value as text. A value with markup adds no element to the admin page.

## ADDED Requirements

### Requirement: The tag editor shows a tag name as text

The tag editor of the post form SHALL show each tag name as text. A name with markup MUST NOT add
an element to the form. When the admin opens a tag, the input of the tag SHALL hold the whole name.

#### Scenario: A stored tag name with a tag

- **WHEN** an admin opens the edit form of a post with a tag whose name holds an `img` tag with an
  `onerror` handler
- **THEN** the tag editor shows the whole name as text and adds no `img` element

#### Scenario: A link with the tags param

- **WHEN** an admin opens the form of a new post through a GET link whose `tags` param holds an `img`
  tag
- **THEN** the tag editor shows the value as text and adds no `img` element

#### Scenario: The admin opens a tag whose name holds a quote

- **WHEN** the admin opens a tag whose name holds a double quote and an `onfocus` attribute
- **THEN** the input of the tag holds the whole name and has no `onfocus` attribute

### Requirement: The permalink line of the post form shows the slug as text

The permalink line of the post form SHALL show the slug of the post as text, inside the URL of the
post. A slug with markup MUST NOT add an element to the form.

#### Scenario: A stored slug with a tag

- **WHEN** an admin opens the edit form of a post whose slug holds an `img` tag with an `onerror`
  handler
- **THEN** the permalink line shows the whole slug as text and adds no `img` element

#### Scenario: A plain slug

- **WHEN** an admin opens the edit form of a post with a plain slug
- **THEN** the permalink line shows the URL of the post, with the slug in it

### Requirement: The media manager shows the params of its page as text

The media manager SHALL show the `folder` param of its page as the text of its breadcrumb. It SHALL
show the `dimension` param as text in the details of an image and in the title of the image editor.
A param with markup MUST NOT add an element to the page.

#### Scenario: A link with a tag in the folder param

- **WHEN** an admin opens the media manager through a link whose `folder` param holds an `img` tag
- **THEN** the breadcrumb shows the value as text and adds no `img` element

#### Scenario: A folder path

- **WHEN** an admin opens the media manager with the `folder` param `/photos/2026`
- **THEN** the breadcrumb holds a link for the root and for `photos`, and the text `2026`

#### Scenario: A link with a tag in the dimension param

- **WHEN** an admin opens the media manager through a link whose `dimension` param holds an `img`
  tag, clicks an image, and opens the image editor
- **THEN** the details of the image and the title of the editor show the value as text and add no
  `img` element
