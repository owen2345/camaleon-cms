## Purpose

Pin that ordering a collection by a custom-field value through `sort_by_field` treats the
caller-supplied direction as data, not SQL: only a sort direction is honored and the ordered column is
a fixed, quoted identifier. `sort_by_field` is a public API themes and plugins reach across the trust
boundary as `collection.sort_by_field(key, params[:order])`, so a user-controlled direction must not be
able to inject `ORDER BY` terms or turn the query into an error.

## ADDED Requirements

### Requirement: sort_by_field honors only a sort direction

`CollectionProxy#sort_by_field` SHALL interpret its `order` argument as a sort direction only: a
case-insensitive `DESC` orders descending, and every other value — including the default — orders
ascending. It SHALL NOT interpolate the argument into the SQL `ORDER BY` clause, and SHALL order by the
custom-field value column as a quoted identifier.

#### Scenario: Ascending direction sorts ascending

- **WHEN** `sort_by_field(key, 'asc')` is called on a collection whose members carry values for `key`
- **THEN** the members are returned in ascending order of that value

#### Scenario: Descending direction sorts descending

- **WHEN** `sort_by_field(key, 'desc')` is called on the same collection
- **THEN** the members are returned in descending order of that value

#### Scenario: The default direction is ascending

- **WHEN** `sort_by_field(key)` is called with no direction
- **THEN** the members are returned in ascending order of that value

### Requirement: A hostile direction cannot inject or error

`sort_by_field` SHALL neutralize any direction that is not `asc`/`desc`: the query SHALL NOT raise a
database error, the generated `ORDER BY` SHALL NOT include attacker-supplied terms, and the result SHALL
fall back to an ascending sort. This SHALL hold without depending on ActiveRecord's implicit raw-SQL
guard.

#### Scenario: A stacked or comment payload is neutralized

- **WHEN** `sort_by_field` is called with a direction containing stacked or comment SQL (for example
  `"ASC; DROP TABLE ...; --"`)
- **THEN** executing the relation does not raise, and the members are returned in ascending order

#### Scenario: A comma continuation is not honored

- **WHEN** `sort_by_field` is called with a direction that appends an extra column term (for example
  `"ASC, some_table.some_column DESC"`)
- **THEN** the generated SQL orders only by the custom-field value column and does not include the
  injected term
