# frozen_string_literal: true

require 'rails_helper'

# Source guard (PR #1169 review, JOIN-PROMOTION): the frontend listing actions build
# @posts with preload(:metas). If they go back to eager_load(:metas), any theme call to
# verify_front_visibility merges its includes into one multi-way LEFT JOIN (row
# explosion + COUNT over the same join). Behavior specs cannot see this: in-repo views
# never call the helper, so the merged query never runs here -- the guard watches the
# only place the regression can start. @categories/@post_tags keep single-association
# eager_loads on purpose (no merge partner) and are out of scope.
RSpec.describe CamaleonCms::FrontendController do
  it 'builds @posts with preload, not eager_load' do
    source = File.read(CamaleonCms::Engine.root.join('app/controllers/camaleon_cms/frontend_controller.rb'))

    listing = /the_posts\.paginate\([^)]*\)\.(preload|eager_load)\(:metas\)/m
    shapes = source.scan(listing).flatten

    expect(shapes).not_to include('eager_load')
    expect(shapes).to eq(%w[preload preload preload])
  end
end
