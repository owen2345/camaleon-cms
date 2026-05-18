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

    it 'stores current site in CurrentRequest' do
      expect(CurrentRequest.site).to eq(site)
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

    it 'reads visited state from CurrentRequest only' do
      visited_post = site.the_post('sample-post').decorate
      CurrentRequest.frontend_visited_post = visited_post

      expect(helper.is_page?).to be(true)
    end

    it 'caches the current theme in CurrentRequest' do
      theme = helper.current_theme

      expect(CurrentRequest.frontend_current_theme).to eq(theme)
    end

    it 'returns current request theme when already set' do
      preview_theme = instance_double(CamaleonCms::Theme, slug: 'cv')
      CurrentRequest.frontend_current_theme = preview_theme

      expect(helper.current_theme).to eq(preview_theme)
      expect(CurrentRequest.frontend_current_theme).to eq(preview_theme)
    end

    it 'prefers preview theme ivar over stale current request theme' do
      stale_theme = instance_double(CamaleonCms::Theme, slug: 'camaleon_cms')
      preview_theme = instance_double(CamaleonCms::Theme, slug: 'cv')
      CurrentRequest.frontend_current_theme = stale_theme
      helper.instance_variable_set(:@_current_theme, preview_theme)

      expect(helper.current_theme).to eq(preview_theme)
      expect(CurrentRequest.frontend_current_theme).to eq(preview_theme)
    end

    it 'does not use controller ivar fallback for frontend object' do
      helper.instance_variable_set(:@object, site.the_post('sample-post').decorate)

      expect(helper.the_title).to be_nil
    end
  end
end
