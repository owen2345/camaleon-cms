# frozen_string_literal: true

require 'rails_helper'

describe CamaleonCms::Frontend::ContentSelectHelper do
  let(:site) { create(:site) }
  let(:post_type) { create(:post_type, slug: 'post', site: site) }

  let(:xss_payload) { '<script>alert("xss")</script>' }

  let!(:post) do
    create(:post, post_type: post_type, title: 'Malicious Post', content: xss_payload, status: 'published').decorate
  end

  describe '#the_content' do
    it 'sanitizes XSS payload in post content' do
      @object = post

      output = the_content

      expect(output).not_to include('<script>')
    end
  end
end
