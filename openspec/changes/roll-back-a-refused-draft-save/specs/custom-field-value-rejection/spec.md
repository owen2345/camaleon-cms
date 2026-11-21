## MODIFIED Requirements

### Requirement: A refused value rolls the save back and surfaces as an error

An admin post save SHALL be atomic across the parent post and its metas, field values and options:
they are written in one transaction, so a value the gate refuses rolls the parent save back with it —
no half-applied post, and no orphan post on create. The response SHALL surface the refusal naming
the field, as a refused admin save answers (the requirement "A refused admin save answers by the kind of the request"), and the refusal SHALL NOT produce an unhandled 500.

The draft save of the post editor SHALL be atomic in the same way, for a draft create and for a
draft update. A refused custom-field value, and custom-field `values` in a shape that the shared
permit does not keep, SHALL roll the whole draft save back. A refused draft create MUST store no
draft row and no meta. A refused draft update MUST keep the draft as stored: its attributes, metas,
options and custom-field values. A refused draft create on a buffer that exists MUST keep that
buffer in the same way.

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

#### Scenario: A draft create after refused ones stores one draft row

- **WHEN** two draft creates of a new post are refused, and a third one carries no refused value
- **THEN** the user has one draft row, and the response names its id

#### Scenario: A refused draft create on a buffer keeps the buffer as stored

- **WHEN** a user has a draft buffer under a post
- **AND** a draft create under that post carries a new title, a new meta and a refused value
- **THEN** the buffer keeps its title, its meta and its custom-field values, and it gets no
  `draft_status` option

#### Scenario: A refused draft update keeps the draft as stored

- **WHEN** a draft update carries a new title, a new meta and a refused value
- **THEN** the draft keeps its title, its meta and its custom-field values
