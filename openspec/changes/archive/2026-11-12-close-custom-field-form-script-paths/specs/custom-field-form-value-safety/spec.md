## Purpose

A link must not put field values into the admin custom-field form. The image preview of the form must
not run markup from its URL, also for a stored value. The capability says which request shows
submitted values in the form, and how the image preview shows its URL.

## ADDED Requirements

### Requirement: The custom-field form shows submitted values only for a request that is not a GET

The custom-fields partial SHALL show the submitted field values for a request that is not a GET,
such as a failed save. For a GET request it SHALL show the values of the record. It MUST NOT show a
field value from the params of a GET request.

#### Scenario: A link with field values opens the form of a new post

- **WHEN** an admin opens the form of a new post through a GET request with `field_options` values in
  its query
- **THEN** the field values of the form hold no value of the query

#### Scenario: A link with field values opens the form of a saved post

- **WHEN** an admin opens the edit form of a post with a stored field value, through a GET link with
  `field_options` values
- **THEN** the form shows the stored value and no value of the query

#### Scenario: A link with field values opens the field list of a post type

- **WHEN** an admin requests the field list of a post type through a GET request with `field_options`
  values in its query
- **THEN** the field values of the list hold no value of the query

#### Scenario: A failed save shows the submitted values

- **WHEN** the create of a category fails its validation and the request holds `field_options` values
- **THEN** the form that renders again shows the submitted values

#### Scenario: A failed update shows the submitted values

- **WHEN** the update of a category fails its validation and the PATCH request holds `field_options`
  values
- **THEN** the form that renders again shows the submitted values

### Requirement: The image preview shows its URL as attribute values

The preview of an image field SHALL set the URL as the `href` of its link and the `src` of its image.
It MUST NOT parse the URL as HTML. For a value that is not empty, the field SHALL show one preview
with one link and one image. A new URL SHALL replace the preview of the old URL. For an empty value,
the field SHALL show no preview.

#### Scenario: A stored URL with a quote and a tag

- **WHEN** the edit form shows an image field whose stored value holds a quote and an `img` tag with an
  `onerror` handler
- **THEN** the preview holds one link and one image, their `href` and `src` are the whole value, and
  the handler does not run

#### Scenario: A new URL replaces the preview

- **WHEN** the URL of an image field that shows a preview changes
- **THEN** the field shows one preview, with the new URL as the `href` of its link

#### Scenario: The remove button empties the URL

- **WHEN** the admin clicks the remove button of an image field that shows a preview
- **THEN** the URL of the field is empty and the field shows no preview
