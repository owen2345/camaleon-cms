## 1. Branch

- [x] 1.1 Create branch `security/fix-decorator-html-injection` off the latest `master` and announce it — branched from `master` at `c27dbcc4`
- [x] 1.2 Confirm the triage verdict before writing the fix — ✅ legit, both defects reproduced end-to-end against `spec/dummy`; enumeration in `proposal.md`
- [x] 1.3 Confirm the *reported* vulnerability ("Stored XSS via Draft Post Title") is not present — ❌ false positive against `master`; fixed in 2.9.2 by [#1143](https://github.com/owen2345/camaleon-cms/pull/1143), access-control half by [#1139](https://github.com/owen2345/camaleon-cms/pull/1139). `spec/decorators/post_decorator_spec.rb` and `spec/requests/security/draft_authorization_spec.rb` already cover it

## 2. Reproduce first

- [x] 2.1 Add `spec/requests/security/post_status_output_escaping_spec.rb`: store a script payload directly in `posts.status`, sign in as an administrator, `GET` the post list with `s=all`, and assert Nokogiri finds no `<script>` inside `#posts-table-list` and the payload appears as escaped text
- [x] 2.2 Extend it with the post edit form and the admin search (`kind=content`) sinks
- [x] 2.3 Add a case proving the source is reachable at contributor privilege: a user whose role grants only `edit` on the post type creates a post with `post[status]` set to the payload, and the column holds it verbatim
- [x] 2.4 Add a case for the `options[:status_default]` → trash → update → restore path, asserting the payload reaches the column via `update_column` **and** still renders inert. This pins D2 — it is the evidence that a model `inclusion:` validation would not have helped
- [x] 2.5 Add `spec/requests/security/custom_field_group_caption_escaping_spec.rb`: name a nav menu with a script payload, place a field group on it, `GET` the custom fields settings page, assert no `<script>` element and the name present as escaped text
- [x] 2.6 Extend 2.5 with the `Widget::Main` and `Theme` placement families
- [x] 2.7 Confirm every example in 2.1–2.6 fails against unmodified `master` before writing any fix

## 3. Fix the sinks

- [x] 3.1 Escape the interpolated status in `PostDecorator#the_status` and return a `SafeBuffer`, keeping the surrounding markup byte-identical per `design.md` D1 — do **not** convert to `content_tag`
- [x] 3.2 Escape the three unescaped model names in `CustomFieldGroup#get_caption` (`Widget::Main#name`, `Theme#name`, `NavMenu#name`) and return a `SafeBuffer`, keeping the `<b>` wrappers as they are — plus the `object_class` fallback in the `else` arm, found while writing 2.5 and reproduced there; it is attacker-settable and would otherwise stay live in a method now returning a `SafeBuffer`
- [x] 3.3 Apply the same treatment to `TermTaxonomyDecorator#the_status` for consistency — not exploitable today, in scope per `design.md` D3
- [x] 3.4 Leave `posts.status` writes untouched. No `inclusion:` validation, no controller allowlist — `design.md` D2
- [x] 3.5 Confirm the specs from section 2 now pass

## 4. Cover the unchanged paths

- [x] 4.1 Add decorator specs asserting `the_status` output is byte-identical to the pre-change string for all five canonical statuses, and that the return value is a `SafeBuffer`
- [x] 4.2 Add a spec asserting a caption for a legitimately named nav menu renders exactly as before
- [x] 4.3 Run the existing admin posts, custom fields, and search specs and confirm they stay green
- [x] 4.4 Confirm `spec/decorators/post_decorator_spec.rb` and `spec/requests/security/draft_authorization_spec.rb` still pass — this change must not disturb the 2.9.2 fixes

## 5. Verification

- [x] 5.1 `bin/rspec` — full suite green
- [x] 5.2 `bin/rubocop -A` on touched files only
- [x] 5.3 `bin/brakeman --no-pager` — no new warnings
- [x] 5.4 `(cd spec/dummy && bin/rails zeitwerk:check)`

## 6. Changelog and archive

- [ ] 6.1 Add a `## Unreleased` **Security fix** entry covering both defects: the privilege each requires, the sinks, why `titleize` was not a mitigation, and an explicit note that the externally reported draft-title XSS was already fixed in 2.9.2 and is not what this addresses
- [ ] 6.2 Note in the entry that non-canonical statuses already stored now render as visible escaped text rather than executing, so operators can spot a poisoned row
- [ ] 6.3 Archive the change on the branch before merge, committed as part of the PR (`docs/ai/workflows.md` Phase 4)
