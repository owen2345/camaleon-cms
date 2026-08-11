# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CamaleonCms::CamaleonHelper, type: :helper do
  describe '#cama_is_admin_request?' do
    it 'returns true when the admin compatibility helper exposes a frontend locale' do
      helper.define_singleton_method(:cama_get_i18n_frontend) { :es }

      expect(helper.cama_is_admin_request?).to be(true)
    end

    it 'returns false when the helper is running outside the admin compatibility context' do
      expect(helper.cama_is_admin_request?).to be(false)
    end
  end

  describe '#cama_sitemap_cats_generator' do
    # H11: both `post.the_url` and `cat.the_url` are plain (non-html_safe) Strings interpolated into a
    # single-quoted href that the sitemap view renders through `raw`. A post slug persists byte-for-byte,
    # so a quote in the URL would otherwise close the href and inject an event handler.
    it 'escapes the post and category hrefs so a malicious slug URL cannot break out of the attribute (H11)' do
      malicious_url = "/post/x' onmouseover='alert(document.domain)"
      escaped_href = "href='/post/x&#39; onmouseover=&#39;alert(document.domain)'"
      post = double(id: 1, the_url: malicious_url, the_title: 'Post title')
      cat = double(
        id: 2, the_url: malicious_url, the_title: 'Category title',
        the_posts: double(decorate: [post]), the_categories: double(decorate: [])
      )
      cats = double(decorate: [cat])

      result = helper.cama_sitemap_cats_generator(cats)

      expect(result).to include("<li><a #{escaped_href}>Post title</a></li>")
      expect(result).to include("<a #{escaped_href}>Category title</a>")
      expect(result).not_to include("x' onmouseover='alert(document.domain)")
    end
  end
end
