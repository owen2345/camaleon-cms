## MODIFIED Requirements

### Requirement: A refused admin save answers by the kind of the request

The admin panel refuses a save in these cases:

- a custom-field value with unsafe or too large content, an invalid group number, or a slug that
  names no custom field
- a post type option that names no post decorator
- a meta or options container that is not a set of fields
- custom-field `values`, or a field entry, in a shape that the shared permit cannot read

Each refusal SHALL answer in the same way, by the kind of the request:

- A submitted form SHALL get a redirect back, with the message as a flash error.
- An XHR that carries the `cama_ajax_request` param (an admin page that `camaleon_admin_ajax` loads
  in place) SHALL get the same redirect and flash.
- Any other XHR SHALL get the message as plain text with a 422, and no flash.

A refused save SHALL store nothing of the refused value. A refusal while the admin panel serves a
GET or HEAD request is no submitted save and SHALL be raised, not answered.

#### Scenario: The nav menu item settings modal shows the refusal

- **WHEN** a user who is not an administrator saves the settings of a nav menu item by XHR
- **AND** an editor value holds a script
- **THEN** the response is a 422 with the refusal as text, no flash is set, and the value is not
  stored
- **AND** the modal stays open and shows the refusal

#### Scenario: A submitted form keeps the flash

- **WHEN** the same save is a submitted form, or an XHR with `cama_ajax_request`
- **THEN** the response redirects back with the refusal in the flash

#### Scenario: The draft save of the post editor

- **WHEN** a draft save by XHR carries a refused value
- **THEN** the response is a 422 with the refusal as text
- **AND** the post editor shows the refusal and keeps the post on the form, as for a refused meta or
  option

#### Scenario: An error page with a 422 is no refusal

- **WHEN** a draft save or a nav menu item settings save gets an error page with a 422, for example
  of a CSRF failure
- **THEN** the post editor or the modal shows its generic failure message, not the body of the page

#### Scenario: A container that is not a set of fields, by XHR

- **WHEN** a category save by XHR carries `meta[]=x`
- **THEN** the response is a 422 with the message as text, and no option is stored
