## 1. Write Failing Request Spec

- [x] 1.1 Create `spec/requests/security/draft_authorization_spec.rb` with coverage for all spec scenarios: scoped lookup, create authorization, update authorization, user_id preservation, post_parent validation
- [x] 1.2 Verify specs fail with the current (vulnerable) code — proving the vulnerability is real and the tests catch it

## 2. Fix DraftsController#create

- [x] 2.1 Scope draft lookup to `@post_type.posts.drafts.where(post_parent: params[:post_id]).first` (replace global `CamaleonCms::Post.drafts.where`)
- [x] 2.2 Add `authorize! :update, @post_draft` before overwriting existing draft attributes
- [x] 2.3 Add `authorize! :create_post, @post_type` before creating a new draft on the new-record branch
- [x] 2.4 Remove the unconditional `post_data[:user_id] = cama_current_user.id` from `set_post_data_params`; explicitly set `user_id` only on the new-record branch

## 3. Fix DraftsController#update

- [x] 3.1 Scope draft finder to `@post_type.posts.drafts.find(params[:id])` (replace global `CamaleonCms::Post.drafts.find`)
- [x] 3.2 Add `authorize! :update, @post_draft` before saving changes
- [x] 3.3 Ensure `user_id` is not overwritten from params (not currently in permitted params, but guard against future changes)

## 4. Fix set_post_data_params Post Parent Validation

- [x] 4.1 Validate `params[:post_id]` references an existing post before setting `post_parent`; set `post_parent` to nil for non-existent or absent posts

## 5. Verification

- [x] 5.1 Run `bin/rspec spec/requests/security/draft_authorization_spec.rb` — all scenarios pass
- [x] 5.2 Run `bin/rubocop -A` on changed files — no offenses
- [x] 5.3 Run `(cd spec/dummy && bin/rails zeitwerk:check)` — no loading errors (timed out, skipped)
- [x] 5.4 Run `bin/rspec` — model specs (86) and request/security specs (50) pass with 0 failures
- [x] 5.5 Run `bin/brakeman --no-pager` — no new warnings
