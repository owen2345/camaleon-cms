# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CamaleonCms::Frontend::ApplicationHelper, type: :helper do
  let!(:site) { create(:site).decorate }

  before do
    helper.current_site(site)
  end

  describe 'CurrentRequest-backed frontend state' do
    it 'stores the frontend current path in CurrentRequest' do
      expect(helper.site_current_path).to eq(CurrentRequest.frontend_site_current_path)
    end

    it 'exposes the current site as a legacy instance variable' do
      expect(helper.instance_variable_get(:@current_site)).to eq(site)
    end

    it 'stores SEO settings in CurrentRequest' do
      helper.cama_seo_settings(title: 'Custom title')

      expect(CurrentRequest.frontend_seo_settings).to include(title: 'Custom title')
      expect(helper.cama_the_seo[:title]).to eq('Custom title')
    end

    it 'stores and restores frontend object state during block helpers' do
      post_type = site.the_post_type('post').decorate
      CurrentRequest.frontend_object = post_type

      yielded_post = nil
      helper.the_post('sample-post') do |post|
        yielded_post = post
        expect(CurrentRequest.frontend_object).to eq(post)
        expect(helper.the_title).to eq(post.the_title)
      end

      expect(yielded_post).to be_present
      expect(CurrentRequest.frontend_object).to eq(post_type)
    end

    it 'reads visited state from CurrentRequest and legacy ivars' do
      visited_post = site.the_post('sample-post').decorate
      CurrentRequest.frontend_visited_post = visited_post

      expect(helper.is_page?).to be(true)

      CurrentRequest.reset
      helper.instance_variable_set(:@cama_visited_post, visited_post)

      expect(helper.is_page?).to be(true)
    end

    it 'caches the current theme in CurrentRequest' do
      theme = helper.current_theme

      expect(CurrentRequest.frontend_current_theme).to eq(theme)
    end

    it 'prefers the preview theme over an already cached site theme' do
      preview_theme = instance_double(CamaleonCms::Theme, slug: 'cv')
      cached_theme = instance_double(CamaleonCms::Theme, slug: 'camaleon_cms')
      helper.instance_variable_set(:@_current_theme, preview_theme)
      CurrentRequest.frontend_current_theme = cached_theme

      expect(helper.current_theme).to eq(preview_theme)
      expect(CurrentRequest.frontend_current_theme).to eq(preview_theme)
    end
  end
end
