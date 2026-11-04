## MODIFIED Requirements

### Requirement: A refusal from a save hook surfaces in the admin panel

When a hook run after an admin post type save writes a value the check refuses, the admin panel
SHALL answer with the refusal rather than a server error, as a refused admin save answers in `custom-field-value-rejection` (the requirement "A refused admin save answers by the kind of the request"): a
redirect carrying the refusal as a flash error for a submitted form, the refusal as text with a 422
for an XHR. The post type's own attributes, saved before the hook ran, remain saved. The message
SHALL quote the value only when it is a class name, cut short, and SHALL NOT echo any other value. A refusal that comes
while the admin panel serves a GET or HEAD request is no submitted save and SHALL be raised, not
redirected.

#### Scenario: A hook stores a rejected value

- **WHEN** a hook run after an admin post type save writes a non-decorator class name into the
  option
- **THEN** the response SHALL redirect with the error in the flash, the option SHALL stay unset,
  and posts of the type SHALL decorate with the default decorator

#### Scenario: A hook stores markup or an overlong name

- **WHEN** a hook run after an admin post type save writes markup, or a class name longer than the
  session cookie can carry, into the option
- **THEN** the response SHALL redirect with the error in the flash, the markup SHALL NOT appear in the
  flash or on the next page, and no server error SHALL occur

#### Scenario: Saving a post type that holds a stored value the check would refuse

- **WHEN** an administrator saves the settings of such a post type
- **THEN** the save SHALL succeed and the stored value SHALL remain

#### Scenario: A refusal while serving a page

- **WHEN** a value the check refuses is written while the admin panel serves a GET or HEAD request,
  such as by a hook run before every admin page
- **THEN** the refusal SHALL be raised rather than redirected, so no page redirects to another that
  refuses again
