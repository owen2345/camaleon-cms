## ADDED Requirements

### Requirement: The HTML sitemap renders the category tree

`GET /sitemap.html` SHALL render the category tree — each category with its posts and
subcategories — for every post type that manages categories. `cama_sitemap_cats_generator` SHALL
apply default (empty) skip lists when the caller passes none, so a bare
`cama_sitemap_cats_generator(cats)` call never raises.

#### Scenario: Sitemap renders for a site with categories

- **WHEN** a visitor requests `/sitemap.html` on a site with at least one category
- **THEN** the response is HTTP 200
- **AND** the body contains the category's title and link

### Requirement: The sitemap hook's skip lists are honored in the HTML variant

The `on_render_sitemap` hook config (`skip_cat_ids`, `skip_post_ids`) SHALL be passed through to
the HTML category generator by the shipped template, so hooks can exclude categories and posts
from the HTML sitemap exactly as they can from the XML variant.

#### Scenario: A hook-excluded category is absent from the HTML sitemap

- **WHEN** an `on_render_sitemap` hook adds a category's id to `skip_cat_ids`
- **THEN** `/sitemap.html` renders without that category's entry
