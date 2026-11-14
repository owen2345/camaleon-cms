# frozen_string_literal: true

# `PostDecorator#the_title` and `TermTaxonomyDecorator#the_title` return an already-escaped
# SafeBuffer (#1206, #1143). Interpolating one into a plain Ruby string drops the safe flag, and the
# ERB sink then escapes it a second time, so an administrator reads `Ben &amp; Jerry&#39;s` instead
# of the name.
#
# Every example pins both directions at once. The literal must be readable -- that fails while the
# value is escaped twice -- and the markup inside it must not become an element, which is what stops
# a future "just use `raw`" from passing.
#
# Each example scopes its assertions to the element under test. The admin layout renders the site
# name correctly elsewhere on the page, so asserting against the whole document passes vacuously.
RSpec.describe 'Admin heading title escaping', type: :request do
  init_site

  let(:current_site) { Cama::Site.first.decorate }
  let(:admin) { create(:user, role: 'admin', site: current_site) }
  let(:name) { "Ben & Jerry's <b>x</b>" }
  let(:post_type) { current_site.post_types.where(slug: 'post').first.decorate }
  let(:doc) { Nokogiri::HTML5.parse(response.body) }

  before do
    allow_any_instance_of(CamaleonCms::AdminController).to receive(:current_site).and_return(current_site)
    sign_in_as(admin, site: current_site)
  end

  shared_examples 'an element that renders the name literally' do
    it 'reads the name as typed, and does not turn its markup into an element' do
      get path

      expect(response).to have_http_status(:ok)
      expect(scope).to be_present
      expect(scope.text).to include(name)
      # The pages carry legitimate `<b>` elements of their own, so match the payload's own content
      # rather than the tag name.
      expect(scope.css('b').map(&:text)).not_to include('x')
    end
  end

  describe 'the site settings heading' do
    let(:path) { '/admin/settings/site' }
    let(:scope) { doc.at_css('.page-content-wrap .panel-heading h4') }

    before { current_site.update!(name: name) }

    it_behaves_like 'an element that renders the name literally'
  end

  describe 'the post edit form heading' do
    let(:target_post) { current_site.the_post('sample-post') }
    let(:path) { "/admin/post_type/#{post_type.id}/posts/#{target_post.id}/edit" }
    let(:scope) { doc.at_css('.content-frame-body .panel-heading h4') }

    before { target_post.update!(title: name) }

    it_behaves_like 'an element that renders the name literally'
  end

  describe 'the categories index heading' do
    let(:path) { "/admin/post_type/#{post_type.id}/categories" }
    let(:scope) { doc.at_css('.col-md-8 .panel-heading h4') }

    before { post_type.object.update!(name: name) }

    it_behaves_like 'an element that renders the name literally'
  end

  describe 'the tags index heading' do
    let(:path) { "/admin/post_type/#{post_type.id}/post_tags" }
    let(:scope) { doc.at_css('.col-md-4 .panel-heading h4') }

    before { post_type.object.update!(name: name) }

    it_behaves_like 'an element that renders the name literally'
  end

  describe 'the sites form heading' do
    let(:path) { "/admin/settings/sites/#{current_site.id}/edit" }
    let(:scope) { doc.at_css('.page-content-wrap .panel-heading h4') }

    before { current_site.update!(name: name) }

    it_behaves_like 'an element that renders the name literally'
  end

  describe 'the custom fields category select' do
    let(:path) { '/admin/settings/custom_fields/new' }
    let(:scope) { doc.at_css("#select_category_simple option[value='Category_Post,#{category.id}']") }
    let!(:category) do
      CamaleonCms::Category.create!(name: name, slug: 'ben-jerrys', site_id: current_site.id,
                                    parent_id: post_type.id, taxonomy: :category, status: post_type.id)
    end

    it_behaves_like 'an element that renders the name literally'

    it 'reads the name literally in the option help attribute' do
      get path

      expect(scope['data-help']).to include(name)
    end
  end

  # The custom field group form shows the `data-help` of an option as text, so the attribute must hold
  # the name with one escape.
  describe 'the custom fields placement select' do
    let(:path) { '/admin/settings/custom_fields/new' }

    %w[PostType_Post PostType_Category PostType_PostTag].each do |placement|
      it "reads the post type name literally in the help attribute of the #{placement} option" do
        post_type.object.update!(name: name)
        get path

        option = doc.at_css("#select_assign_group option[value='#{placement},#{post_type.id}']")
        expect(option['data-help']).to include(name)
      end
    end

    # The t helper of a view gives an html_safe span for a key with no translation. The option must
    # hold that span as text in its help attribute.
    it 'keeps the help attribute whole for a help with no translation' do
      allow_any_instance_of(ActionView::Base).to receive(:t).and_wrap_original do |original, key, **options|
        key = 'camaleon_cms.admin.no_such_key' if key.to_s.end_with?('.add_custom_field_posts')
        original.call(key, **options)
      end
      post_type.object.update!(name: name)
      get path

      option = doc.at_css("#select_assign_group option[value='PostType_Post,#{post_type.id}']")
      expect(option.attribute_nodes.map(&:name)).to eq(%w[value data-help])
      expect(option['data-help']).to end_with(name)
    end

    it 'reads the post title literally in the help attribute of the post option' do
      target_post = current_site.the_post('sample-post')
      target_post.update!(title: name)
      get path

      option = doc.at_css("#select_post_simple option[value='Post,#{target_post.id}']")
      expect(option['data-help']).to include(name)
    end
  end

  # `posts/index.html.erb:54` passes the SafeBuffer to `link_to` as an argument instead of
  # interpolating it, so it renders correctly today. It is pinned so the fix does not regress it.
  describe 'the posts index title cell' do
    let(:target_post) { current_site.the_post('sample-post') }
    let(:path) { "/admin/post_type/#{post_type.id}/posts" }
    let(:scope) { doc.at_css("#posts-table-list tbody tr[data-id='#{target_post.id}'] td:nth-child(2)") }

    before { target_post.update!(title: name) }

    it_behaves_like 'an element that renders the name literally'
  end

  # `titleize` runs on entities rather than characters once the value is escaped:
  # `"Ben &amp; Jerry&#39;s".titleize` yields `"Ben &Amp; Jerry&#39;S"`, and `&Amp;` is not a valid
  # entity. `safe_join` does not address that -- the transformation has to happen before escaping.
  describe 'the categories index action-button tooltip' do
    let(:plain_name) { "Ben & Jerry's" }
    let!(:category) do
      CamaleonCms::Category.create!(name: plain_name, slug: 'ben-jerrys', site_id: current_site.id,
                                    parent_id: post_type.id, taxonomy: :category, status: post_type.id)
    end

    it 'titleizes the name without corrupting its entities' do
      get "/admin/post_type/#{post_type.id}/categories"

      tooltip = doc.at_css("#categories-table-list tr[data-id='#{category.id}'] a.btn-default")['title']
      expect(tooltip).to include(plain_name)
      expect(tooltip).not_to include('&Amp;')
    end
  end
end
