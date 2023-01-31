# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'routes for Post Types', type: :routing do
  init_site

  it 'routes for /test-post-type' do
    post_type = create(:post_type)
    expect(post_type.id).to be_present
    expect(get("/#{post_type.slug}"))
      .to route_to('camaleon_cms/frontend#post_type', post_type_id: post_type.id, post_type_slug: post_type.slug)
  end
end
