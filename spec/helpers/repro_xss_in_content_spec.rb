# frozen_string_literal: true

require 'rails_helper'

describe CamaleonCms::Frontend::ContentSelectHelper do
  let(:site) { create(:site) }
  # the site install already creates a 'post' post type; a second one with the
  # same slug under the same site is (correctly) rejected as a duplicate
  let(:post_type) { site.post_types.find_by!(slug: 'post') }
  let(:xss_payload) { '<script>alert("xss")</script>' }
  let!(:post) do
    create(:post, post_type: post_type, title: 'Malicious Post', content: xss_payload, status: 'published').decorate
  end

  before do
    # a second site exists (the suite-wide shared one), so pin this spec's own
    # site as current instead of relying on single-site fallback resolution
    store_current_site(site.decorate)
  end

  describe '#the_content' do
    it 'sanitizes XSS payload in post content' do
      CurrentRequest.frontend_object = post

      output = the_content

      expect(output).not_to include('<script>')
    end
  end
end
