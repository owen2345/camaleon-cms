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

    it 'falls back to the controller @object ivar for the frontend object (regression M20)' do
      post = site.the_post('sample-post').decorate
      helper.instance_variable_set(:@object, post)

      expect(helper.the_title).to eq(post.the_title)
    end
  end

  describe '#verify_front_visibility' do
    let(:post_type) { site.the_post_type('post').decorate }

    before do
      allow(helper).to receive(:hooks_run)
    end

    # The with_eager preloads must stay separate queries, never merge into a join. When with_eager
    # was an `includes` (or a listing used eager_load), a later chained join/where collapsed it into
    # ONE multi-way LEFT JOIN, exploding rows and running the will_paginate COUNT over that join.
    it 'does not promote the listing relation into a joined query' do
      filtered = helper.verify_front_visibility(post_type.posts.paginate(page: 1, per_page: 5))

      expect(filtered.eager_loading?).to be(false)
      expect(filtered.eager_load_values).to be_empty

      # The only LEFT OUTER JOIN a preload issues is the :categories through-association joining
      # term_taxonomy for Category's STI condition -- exactly one join; a promotion adds more.
      joins = sql_queries(matching: /LEFT OUTER JOIN/i) { expect(filtered.to_a).to be_present }
      expect(joins).to all(satisfy { |sql| sql.scan(/LEFT OUTER JOIN/i).size <= 1 })
    end

    it 'hides non-published posts through the visibility scope' do
      draft = post_type.the_posts.where(status: 'published').first
      draft.update(status: 'draft')

      filtered = helper.verify_front_visibility(post_type.the_posts)

      expect(filtered.pluck(:id)).not_to include(draft.id)
    end

    it 'preloads listing associations by default but skips them when eager: false' do
      raw = post_type.posts # undecorated relation, no preloads yet

      expect(helper.verify_front_visibility(raw).preload_values)
        .to include(:metas, :categories, :post_tags, post_type: :metas)
      expect(helper.verify_front_visibility(raw, eager: false).preload_values).to be_empty
    end
  end
end
