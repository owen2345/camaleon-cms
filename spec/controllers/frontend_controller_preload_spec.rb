# frozen_string_literal: true

require 'rails_helper'

# Behavior guard (PR #1169 review, JOIN-PROMOTION): the frontend listing actions paginate
# `<taxonomy>.the_posts`, which runs through verify_front_visibility -> Post.with_eager. The
# paginated relation the controller hands the view must never be `eager_loading?` -- a multi-way
# LEFT JOIN whose filtered join loads partial associations and whose COUNT/pluck duplicate rows.
# This replaces the earlier source-text regex guard, which failed on benign rewrites yet passed on
# a real `.eager_load`/`.references` promotion; `eager_loading?` on the actual relation is the
# property that matters. (verify_front_visibility itself is exercised in the frontend
# application_helper spec; here the focus is the paginated listing wrapper the actions build.)
RSpec.describe CamaleonCms::Frontend::ApplicationHelper, type: :helper do
  let!(:site) { create(:site).decorate }
  let(:post_type) { site.the_post_type('post').decorate }

  before do
    helper.current_site(site)
    allow(helper).to receive(:hooks_run)
  end

  it 'builds a non-eager-loading paginated listing relation' do
    relation = helper.verify_front_visibility(post_type.the_posts.paginate(page: 1, per_page: 5))

    expect(relation.eager_loading?).to be(false)
    expect(relation.to_sql.scan(/LEFT OUTER JOIN/i).size).to be <= 1
  end

  it 'keeps the relation non-eager-loading even if a caller chains a category join filter' do
    relation = helper.verify_front_visibility(post_type.the_posts)
                     .joins(:categories)
                     .where(CamaleonCms::TermRelationship.table_name => { term_taxonomy_id: [0] })

    expect(relation.eager_loading?).to be(false)
  end
end
