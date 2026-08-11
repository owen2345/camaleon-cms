## 1. Branch

- [x] 1.1 Create branch `security/guard-custom-fields-list-write` off the latest `master` and announce it
- [x] 1.2 Confirm the triage verdict before writing the fix — ✅ legit; a bare GET with `post_id` and no `categories` wipes the post's categories; enumeration in `proposal.md`

## 2. Reproduce first

- [x] 2.1 Add `spec/requests/security/custom_fields_list_get_write_spec.rb`: a post with one category, `GET .../custom_fields/list?post_id=<id>` (no `categories`) leaves the categories unchanged; a POST with `categories` still updates them
- [x] 2.2 Confirm the GET example fails against the unfixed controller (stash the guard, run, restore)

## 3. Fix

- [x] 3.1 Guard the category write in `#list` with `unless request.get?` so only a non-GET (CSRF-verified) request performs it
- [x] 3.2 Change the route to `match 'list', via: %i[get post]` so the write can be POSTed
- [x] 3.3 Confirm the spec from section 2 now passes

## 4. Cover the unchanged paths

- [x] 4.1 Move the two existing `custom_fields_spec` `#list` cases that exercise the write (category update + cross-site filtering) from GET to POST; keep the pure-render case on GET
- [x] 4.2 Run the custom-fields, XSS, field-group and caption specs — green
- [x] 4.3 Run the full `spec/requests/` suite — green

## 5. Verification

- [x] 5.1 `bin/rspec` on the touched specs and `spec/requests/` — green
- [x] 5.2 `bin/rubocop` on touched files only — no offenses
- [x] 5.3 `bin/brakeman --no-pager` — no new warnings
- [x] 5.4 `(cd spec/dummy && bin/rails zeitwerk:check)`

## 6. Changelog and archive

- [x] 6.1 Add a `## Unreleased` **Security fix** entry: the read-named GET that wrote, what it destroyed (a post's category relationships), and that the write now requires a non-GET verb
- [ ] 6.2 Archive the change on the branch before merge, committed as part of the PR (`docs/ai/workflows.md` Phase 4)
