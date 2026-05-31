# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CamaleonCms::SiteDecorator do
  let(:site) { create(:site) }
  let(:decorator) { site.decorate }

  before do
    allow(site).to receive(:get_languages).and_return(%w[en es])
    allow(decorator.h).to receive(:asset_path).and_return('/assets/en.png')
    allow(decorator.h).to receive(:cama_url_to_fixed) do |_helper_name, options|
      "/?locale=#{options[:locale]}"
    end
  end

  describe '#draw_languages' do
    it 'escapes labels returned by the block' do
      output = decorator.draw_languages('langs', true) { |_lang, _current| '<script>alert(1)</script>' }

      expect(output).to include('&lt;script&gt;alert(1)&lt;/script&gt;')
      expect(output).not_to include('<script>')
    end
  end

  describe '#the_post' do
    it 'finds a post stored with a localized (multi-language) slug' do
      post = create(:post, site: site,
                           slug: '<!--:en-->sample-post<!--:--><!--:es-->sample-post<!--:-->')

      result = decorator.the_post('sample-post')

      expect(result).to be_present
      expect(result.id).to eq(post.id)
    end

    it 'finds a post stored with a plain slug' do
      post = create(:post, site: site, slug: 'plain-slug')

      expect(decorator.the_post('plain-slug').id).to eq(post.id)
    end
  end
end
