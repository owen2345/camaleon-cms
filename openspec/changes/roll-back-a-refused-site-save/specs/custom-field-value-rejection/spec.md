## MODIFIED Requirements

### Requirement: A refused value rolls the save back and surfaces as an error

An admin post save SHALL be atomic across the parent post and its metas, field values and options:
they are written in one transaction, so a value the gate refuses rolls the parent save back with it —
no half-applied post, and no orphan post on create. The response SHALL surface the refusal naming
the field, as a refused admin save answers (the requirement "A refused admin save answers by the kind of the request"), and the refusal SHALL NOT produce an unhandled 500.

The draft save of the post editor SHALL be atomic in the same way, for a draft create and for a
draft update. A refused custom-field value, and custom-field `values` in a shape that the shared
permit does not keep, SHALL roll the whole draft save back. A refused draft create MUST store no
draft row, no meta and no link to a category or a tag. A refused draft update MUST keep the draft as
stored: its attributes, metas, categories, tags, options and custom-field values. A refused draft
create on a buffer that exists MUST keep that buffer in the same way. A refused draft save MUST
store no new tag.

The site settings save SHALL be atomic in the same way across the site and its options, metas and
custom-field values. Each of these refusals SHALL roll the whole save back:

- a refused custom-field value
- custom-field `values` in a shape that the shared permit does not keep
- an options or metas container that is not a set of fields

A refused site settings save MUST keep the site as stored: its name, its slug, its description, its
options, its metas and its custom-field values. So the redirect of the refusal MUST lead to a host
that names the site.

#### Scenario: Posts controller surfaces the refusal atomically

- **WHEN** an untrusted author submits a post update whose editor field value contains a script
- **THEN** the response redirects back with a flash error naming the field, the value is not stored,
  and the parent post's other changes in that submission are not persisted either

#### Scenario: Value persistence does not destroy the prior value

- **WHEN** an author's new value for a field is refused (through the single-value write path)
- **THEN** the previously stored value for that field is unchanged

#### Scenario: A refused draft create stores no draft row

- **WHEN** the draft create of a new post, or the first draft create under a post, carries a
  refused value
- **THEN** the response is the refusal with a 422, and no draft row and no meta are stored

#### Scenario: A refused draft create stores no category or tag

- **WHEN** the draft create of a new post carries a category, a new tag and a refused value
- **THEN** no link to a category or a tag is stored, and no new tag is stored

#### Scenario: A draft create after refused ones stores one draft row

- **WHEN** two draft creates of a new post are refused, and a third one carries no refused value
- **THEN** the user has one draft row, and the response names its id

#### Scenario: A refused draft create on a buffer keeps the buffer as stored

- **WHEN** a user has a draft buffer under a post
- **AND** a draft create under that post carries a new title, a new meta and a refused value
- **THEN** the buffer keeps its title, its meta and its custom-field values, and it gets no
  `draft_status` option

#### Scenario: A refused draft update keeps the draft as stored

- **WHEN** a draft update carries a new title, a new meta, a new category, a new tag and a refused
  value
- **THEN** the draft keeps its title, its meta, its categories, its tags and its custom-field values,
  and no new tag is stored

#### Scenario: A refused site settings save keeps the slug of the site

- **WHEN** an install has two sites
- **AND** a site settings save carries a new slug, a new name, a new option and a refused part
- **THEN** the response redirects back to the form with a flash error
- **AND** the site keeps its slug, its name, its options and its custom-field values
- **AND** the form at the redirect location answers with a 200

#### Scenario: A refused site settings save by XHR keeps the slug of the site

- **WHEN** the same save is an XHR without the `cama_ajax_request` param
- **THEN** the response is the refusal as text with a 422, and the site keeps its slug

#### Scenario: A site settings save that passes stores each part

- **WHEN** a site settings save carries a new slug, a new name, a new option and a custom-field
  value that passes
- **THEN** each of them is stored, and the response redirects to the form on the new host
