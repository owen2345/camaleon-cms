# frozen_string_literal: true

# The nav menu item settings modal posts its form by XHR. When a custom-field value of the item was
# refused, the admin answered with a redirect and a flash, as for a submitted form. The XHR followed
# the redirect, got the admin page, and the modal closed as if the save had passed. Now a refused
# save answers an XHR with the refusal as text and a 422, and sets no flash. A submitted form, and an
# XHR that loads admin pages in place (camaleon_admin_ajax, `cama_ajax_request`), keep the redirect
# and the flash.
RSpec.describe 'An admin save that is refused answers an XHR with a 422', type: :request do
  init_site

  let(:current_site) { Cama::Site.first.decorate }
  let(:script) { '<p>keep</p><script>alert(1)</script>' }

  before do
    allow_any_instance_of(CamaleonCms::AdminController).to receive(:current_site).and_return(current_site)
  end

  def refusal_of(field)
    I18n.t('camaleon_cms.admin.custom_field.message.value_rejected_html', slug: field.slug)
  end

  describe 'the nav menu item settings' do
    let(:menu_role) { current_site.user_roles.create!(name: 'Menu manager', slug: 'menu-manager-xhr') }
    let(:menu_manager) { create(:user, role: menu_role.slug, site: current_site) }
    let(:menu) { current_site.nav_menus.create!(name: 'XHR menu', slug: 'xhr-menu') }
    let(:item) { menu.append_menu_item({ label: 'Item', type: 'external', link: '#' }) }
    let(:field) do
      group = current_site.custom_field_groups.create!(name: 'Menu fields', slug: '_xhr-menu-fields',
                                                       object_class: 'NavMenu', objectid: menu.id)
      group.add_manual_field({ 'name' => 'Body', 'slug' => 'xhr_body' }, { 'field_key' => 'editor' })
    end

    before do
      menu_role.set_meta("_manager_#{current_site.id}", { 'nav_menu' => 1 })
      sign_in_as(menu_manager, site: current_site)
    end

    def save_item_settings(value, **options)
      post cama_admin_appearances_nav_menu_save_custom_settings_path(nav_menu_id: menu.id, id: item.id),
           params: { field_options: { '0' => { field.slug => { 'id' => field.id.to_s,
                                                               'values' => { '0' => value } } } } },
           **options
    end

    it 'answers an XHR with the refusal as text and a 422, stores nothing and sets no flash' do
      save_item_settings(script, xhr: true)

      expect(response.status).to eq(422)
      expect(response.media_type).to eq('text/plain')
      expect(response.body).to eq(refusal_of(field))
      expect(flash[:error]).to be_nil
      expect(item.reload.get_field_value(field.slug)).to be_blank
    end

    it 'answers an XHR that stores the value with a 200' do
      save_item_settings('<p>plain</p>', xhr: true)

      expect(response).to have_http_status(:ok)
      expect(item.reload.get_field_value(field.slug)).to eq('<p>plain</p>')
    end

    it 'answers a submitted form with the redirect and the flash' do
      save_item_settings(script, headers: { 'HTTP_REFERER' => '/admin/appearances/nav_menus' })

      expect(response).to redirect_to('/admin/appearances/nav_menus')
      expect(flash[:error]).to eq(refusal_of(field))
      expect(item.reload.get_field_value(field.slug)).to be_blank
    end

    it 'answers an XHR that loads admin pages in place with the redirect and the flash' do
      save_item_settings(script, xhr: true, headers: { 'HTTP_REFERER' => '/admin/appearances/nav_menus' })
      expect(response.status).to eq(422)

      post cama_admin_appearances_nav_menu_save_custom_settings_path(nav_menu_id: menu.id, id: item.id),
           params: { cama_ajax_request: 'true',
                     field_options: { '0' => { field.slug => { 'id' => field.id.to_s,
                                                               'values' => { '0' => script } } } } },
           xhr: true, headers: { 'HTTP_REFERER' => '/admin/appearances/nav_menus' }

      expect(response).to redirect_to('/admin/appearances/nav_menus')
      expect(flash[:error]).to eq(refusal_of(field))
    end
  end

  # The other refusal that the admin shows as a flash: a meta or options container that is not a set
  # of fields.
  describe 'a category save with a meta container that is not a set of fields' do
    let(:admin) { create(:user_admin, site: current_site) }
    let(:post_type) { current_site.post_types.find_by(slug: 'post') }

    before { sign_in_as(admin, site: current_site) }

    it 'answers an XHR with the message and a 422, and stores no category' do
      post "/admin/post_type/#{post_type.id}/categories",
           params: 'category[name]=XHR+cat&category[slug]=xhr-cat&meta[]=x',
           headers: { 'CONTENT_TYPE' => 'application/x-www-form-urlencoded' }, xhr: true

      expect(response.status).to eq(422)
      expect(response.body).to eq(I18n.t('camaleon_cms.admin.message.malformed_fields'))
      expect(flash[:error]).to be_nil
      expect(post_type.categories.find_by(slug: 'xhr-cat')&.options).to be_blank
    end
  end

  # The draft save of the post editor sends an XHR too. Its script reads a 422 as a failed save, as it
  # read the admin page that the redirect led to. The draft buffer keeps what the save stored before
  # the custom-field values.
  describe 'the draft save of the post editor' do
    let(:post_type) { current_site.post_types.find_by(slug: 'post') }
    let(:editor) { create(:user, role: 'editor', site: current_site) }
    let(:parent) { create(:post, post_type: post_type, owner: editor, status: 'published') }
    let(:field) do
      group = current_site.custom_field_groups.create!(name: 'Post fields', slug: '_xhr-post-fields',
                                                       object_class: 'PostType_Post', objectid: post_type.id)
      group.add_manual_field({ 'name' => 'Body', 'slug' => 'xhr_post_body' }, { 'field_key' => 'editor' })
    end

    before do
      current_site.user_roles.find_by(slug: 'editor')
                  .set_meta("_post_type_#{current_site.id}", edit: [post_type.id], create: [post_type.id])
      sign_in_as(editor, site: current_site)
    end

    it 'answers a refused value with the refusal and a 422' do
      post "/admin/post_type/#{post_type.id}/drafts",
           params: { post_id: parent.id, post: { title: 'Draft title' },
                     field_options: { '0' => { field.slug => { 'id' => field.id.to_s,
                                                               'values' => { '0' => script } } } } },
           xhr: true

      expect(response.status).to eq(422)
      expect(response.body).to eq(refusal_of(field))
      expect(flash[:error]).to be_nil
      buffer = post_type.posts.drafts.find_by(post_parent: parent.id)
      expect(buffer).to be_present
      expect(buffer.get_field_value(field.slug)).to be_blank
    end
  end
end
