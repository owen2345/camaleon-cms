# frozen_string_literal: true

require 'rails_helper'

# Organic, behavioural guard for the multi-language-aware slug lookups.
#
# Background
# ----------
# The custom, multi-language-aware finder `find_by_slug` is defined ONLY on
# `CamaleonCms::PostDefault` (the `posts` table). It matches both the plain slug
# and the localized form, e.g. "<!--:en-->sample-post<!--:--><!--:es-->...".
# Using the plain `find_by(slug: ...)` there silently misses localized slugs
# (the original `/sample-post` 404 bug).
#
# For every other model (categories, post_types, post_tags, nav_menus,
# nav_menu_items, custom_field_groups) `find_by_slug` resolves to Rails' dynamic
# finder, which is functionally identical to `find_by(slug: ...)`. We still keep
# those call sites on `find_by_slug` for a single, uniform convention.
#
# What this spec does (instead of scanning the source files):
#   * For the `posts`-backed call sites it exercises the real public method with
#     a record stored under a LOCALIZED slug. These examples genuinely FAIL if
#     the call is reverted to `find_by(slug:)`, because `find_by(slug:)` cannot
#     match a localized slug.
#   * For the term_taxonomy / custom_field call sites it exercises the real
#     public method (or the exact relation expression the production line uses)
#     against real records, giving organic behavioural coverage of every
#     occurrence.
RSpec.describe 'find_by_slug usage (organic behavioural coverage)' do # rubocop:disable RSpec/DescribeClass
  # localized slug + the plain key used to look it up
  let(:localized_slug) { '<!--:en-->multilang-post<!--:--><!--:es-->multilang-post<!--:-->' }
  let(:plain_key) { 'multilang-post' }

  let(:site) { create(:site) }
  let(:decorator) { site.decorate }

  # ------------------------------------------------------------------
  # posts-backed call sites: localized slug => true revert guards
  # ------------------------------------------------------------------

  describe 'CamaleonCms::PostDefault.find_by_slug (shared finder behind the_posts.find_by_slug)' do
    # Covers every `current_site.the_posts.find_by_slug(...)` / `object.posts.find_by_slug(...)`
    # call site (frontend_controller#render_post, front_cache plugin helper, decorators).
    it 'matches a post stored with a localized slug, unlike find_by(slug:)' do
      post = create(:post, site: site, slug: localized_slug)

      expect(decorator.the_posts.find_by_slug(plain_key)).to eq(post) # rubocop:disable Rails/DynamicFindBy
      # the very behaviour that would break on a revert to find_by(slug:)
      expect(decorator.the_posts.find_by(slug: plain_key)).to be_nil
    end

    it 'still matches a post stored with a plain slug' do
      post = create(:post, site: site, slug: 'plain-post')

      expect(decorator.the_posts.find_by_slug('plain-post')).to eq(post) # rubocop:disable Rails/DynamicFindBy
    end
  end

  describe 'CamaleonCms::SiteDecorator#the_post' do
    it 'finds a post stored with a localized slug (fails if reverted to find_by(slug:))' do
      post = create(:post, site: site, slug: localized_slug)

      result = decorator.the_post(plain_key)

      expect(result).to be_present
      expect(result.id).to eq(post.id)
    end
  end

  describe 'CamaleonCms::TermTaxonomyDecorator#the_post (object.posts.find_by_slug)' do
    it 'finds a post of the post_type stored with a localized slug' do
      post_type = create(:post_type, site: site)
      post = create(:post, post_type: post_type, slug: localized_slug)

      result = post_type.decorate.the_post(plain_key)

      expect(result).to be_present
      expect(result.id).to eq(post.id)
    end
  end

  describe 'CamaleonCms::Site#get_valid_post_slug' do
    it 'detects a clashing post stored with a localized slug and returns a suffixed slug' do
      create(:post, site: site, slug: localized_slug)

      # find_by_slug matches the localized post => the requested slug is taken =>
      # a "-1" suffix is returned. With find_by(slug:) the localized post would
      # not be found and the requested slug would be considered free.
      expect(site.get_valid_post_slug(plain_key.dup)).to eq("#{plain_key}-1")
    end

    it 'returns the requested slug untouched when nothing clashes' do
      expect(site.get_valid_post_slug(+'totally-free-slug')).to eq('totally-free-slug')
    end
  end

  # ------------------------------------------------------------------
  # term_taxonomy / custom_field call sites: organic coverage
  # (functionally identical to find_by(slug:), kept for a uniform convention)
  # ------------------------------------------------------------------

  describe 'CamaleonCms::SiteDecorator#the_post_type' do
    it 'finds a post_type by string slug' do
      post_type = create(:post_type, site: site, slug: 'my-type')

      expect(decorator.the_post_type('my-type').id).to eq(post_type.id)
    end

    it 'finds a post_type by an array of slugs' do
      post_type = create(:post_type, site: site, slug: 'arr-type')

      expect(decorator.the_post_type(['arr-type']).id).to eq(post_type.id)
    end
  end

  describe 'CamaleonCms::SiteDecorator#the_category' do
    it 'finds a category by slug' do
      post_type = create(:post_type, site: site)
      category = post_type.categories.create!(name: 'My Cat', slug: 'my-cat')

      expect(decorator.the_category('my-cat').id).to eq(category.id)
    end
  end

  describe 'CamaleonCms::SiteDecorator#the_tag' do
    it 'finds a post_tag by slug' do
      post_type = create(:post_type, site: site)
      tag = post_type.post_tags.create!(name: 'My Tag', slug: 'my-tag')

      expect(decorator.the_tag('my-tag').id).to eq(tag.id)
    end
  end

  describe 'CamaleonCms::PostTypeDecorator#the_category' do
    it 'finds a category of the post_type by slug' do
      post_type = create(:post_type, site: site)
      category = post_type.categories.create!(name: 'PT Cat', slug: 'pt-cat')

      expect(post_type.decorate.the_category('pt-cat').id).to eq(category.id)
    end
  end

  # NOTE: `CamaleonCms::CategoryDecorator#the_category` (category_decorator.rb)
  # references `object.categories.find_by_slug(...)`, but `CamaleonCms::Category`
  # does not define `categories` (sub-categories are `children`). That makes the
  # `find_by_slug` line unreachable for a real Category, so it cannot be covered
  # organically here (pre-existing latent issue, out of scope for this change).

  describe 'CamaleonCms::PostType#default_category' do
    it 'returns the categories.find_by_slug("uncategorized") category' do
      post_type = create(:post_type, site: site, data_options: { has_category: true })

      expect(post_type.default_category.slug).to eq('uncategorized')
    end
  end

  describe 'nav_menus.find_by_slug (nav_menu_helper, nav_menus_controller)' do
    it 'finds a nav_menu by slug' do
      menu = site.nav_menus.create!(name: 'Footer Menu', slug: 'footer-menu')

      expect(site.nav_menus.find_by_slug('footer-menu')).to eq(menu) # rubocop:disable Rails/DynamicFindBy
    end
  end

  describe 'nav_menu_items.find_by_slug (short_code_helper, runtime_shortcode_theme_concern)' do
    it 'finds a nav_menu_item by its slug/kind' do
      menu = site.nav_menus.create!(name: 'Main', slug: 'main-menu')
      item = menu.children.create!(name: 'Home', slug: 'home-key', description: '/')

      expect(site.nav_menu_items.find_by_slug('home-key')).to eq(item) # rubocop:disable Rails/DynamicFindBy
    end
  end

  describe 'custom field group slug lookups (CustomFieldGroup#get_field, CustomFieldsRead#add_*)' do
    it 'creates and retrieves a custom field group + field by slug' do
      post = create(:post, site: site)
      # add_field -> CustomFieldsRead#add_custom_field_to_default_group ->
      #   get_field_groups.find_by_slug('_default') (custom_fields_read.rb)
      #   + add_custom_field_group -> get_field_groups.find_by_slug(...) when present
      #   + group.add_manual_field -> get_field (custom_field_group.rb)
      post.add_field({ 'name' => 'Sub Title', 'slug' => 'subtitle' }, { 'field_key' => 'text_box' })

      group = post.get_field_groups('Post').find_by_slug('_default') # rubocop:disable Rails/DynamicFindBy
      expect(group).to be_present
      expect(group.get_field('subtitle')).to be_present
    end
  end

  # End-to-end guard for the controller call site: rendering a post by URL must
  # find a post stored with a localized slug. A revert of render_post to
  # find_by(slug:) would make this 404.
  describe 'CamaleonCms::FrontendController#render_post', type: :request do
    init_site

    it 'renders a post whose slug is stored localized (would 404 if reverted to find_by(slug:))' do
      post_type = @site.post_types.find_by_slug('post') # rubocop:disable Rails/DynamicFindBy
      post = post_type.posts.create!(title: 'Multilang Post', slug: localized_slug,
                                     content: 'multilang content', status: 'published',
                                     published_at: Time.current)

      get post.decorate.the_url(as_path: true), headers: { 'HTTP_HOST' => @site.slug }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Multilang Post')
    end
  end
end
