# frozen_string_literal: true

# With two sites, Camaleon finds the site of a request by its host, and the slug of a site is that
# host. The site settings save stored the new slug first. Then it stored the options, the metas and
# the custom-field values, with no transaction. A refusal of one of them redirects back to the
# form, which is on the old host. The new slug stayed, so the old host named no site.
RSpec.describe 'A refused site settings save', type: :request do
  init_site

  let(:admin) { create(:user, role: 'admin', site: @site) }
  let(:old_slug) { @site.slug }
  let(:old_name) { @site.name }
  let(:new_slug) { 'renamed.example.test' }
  let(:form_url) { "http://#{old_slug}/admin/settings/site" }
  let(:site_group) do
    @site.custom_field_groups.create!(name: 'Site Group', slug: '_site-group', object_class: 'Site', objectid: @site.id)
  end
  let!(:title) { site_group.add_manual_field({ 'name' => 'Title', 'slug' => 'title' }, { 'field_key' => 'text_box' }) }
  let(:stored_site) { CamaleonCms::Site.find(@site.id) }

  # Each entry is a part of the request that the save refuses after it stored the site.
  let(:refused_parts) do
    {
      'custom-field values that the permit cannot read' =>
        { 'field_options' => { '0' => { 'title' => { 'id' => title.id.to_s, 'values' => 'foo' } } } },
      'a custom-field value with a group number that is not valid' =>
        { 'field_options' => { '0' => { 'title' => { 'id' => title.id.to_s, 'group_number' => 'x',
                                                     'values' => { '0' => 'new title' } } } } },
      'a metas container that is not a set of fields' => { 'metas' => ['x'] }
    }
  end

  before do
    create(:site, slug: 'other.example.test', name: 'Other site')
    host! old_slug
    sign_in_as(admin, site: @site)
    @site.set_field_value('title', 'stored title')
    old_name
  end

  def save_site(site_attrs, extra = {}, **request_options)
    params = { 'site' => { 'name' => 'New name', 'slug' => old_slug }.merge(site_attrs),
               'options' => { 'probe_option' => 'new option' } }.merge(extra)
    patch '/admin/settings/site_saved', params: params, headers: { 'HTTP_REFERER' => form_url }, **request_options
  end

  def expect_site_as_stored
    expect(stored_site).to have_attributes(slug: old_slug, name: old_name)
    expect(stored_site.get_option('probe_option')).to be_nil
    expect(stored_site.get_field_values('title')).to eq(['stored title'])
    expect(cached_slug).to eq(old_slug)
  end

  # The slug of the site in the list that PluginRoutes caches for the routes.
  def cached_slug
    PluginRoutes.get_sites.find { |site| site.id == @site.id }.slug
  end

  [
    'custom-field values that the permit cannot read',
    'a custom-field value with a group number that is not valid',
    'a metas container that is not a set of fields'
  ].each do |part|
    it "keeps the slug for #{part}, and the redirect leads to the form of the site" do
      save_site({ 'slug' => new_slug }, refused_parts.fetch(part))

      expect(response).to redirect_to(form_url)
      expect(flash[:error]).to be_present
      expect(flash[:notice]).to be_nil
      expect_site_as_stored

      follow_redirect!

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('id="site_settings_form"')
    end
  end

  it 'stores nothing of a refused save that keeps the slug' do
    save_site({}, refused_parts.fetch('custom-field values that the permit cannot read'))

    expect(response).to redirect_to(form_url)
    expect_site_as_stored
  end

  it 'keeps the slug for an XHR without cama_ajax_request, and answers the refusal as text with a 422' do
    save_site({ 'slug' => new_slug }, refused_parts.fetch('custom-field values that the permit cannot read'),
              xhr: true)

    expect(response).to have_http_status(422) # rubocop:disable RSpecRails/HttpStatus
    expect(response.body).to eq(I18n.t('camaleon_cms.admin.custom_field.message.values_unusable', slug: 'title'))
    expect_site_as_stored
  end

  it 'stores a save that passes, and redirects to the form on the new host' do
    entry = { 'id' => title.id.to_s, 'values' => { '0' => 'new title' } }
    save_site({ 'slug' => new_slug }, { 'field_options' => { '0' => { 'title' => entry } } })

    expect(response).to redirect_to("http://#{new_slug}/admin/settings/site")
    expect(stored_site).to have_attributes(slug: new_slug, name: 'New name')
    expect(stored_site.get_option('probe_option')).to eq('new option')
    expect(stored_site.get_field_values('title')).to eq(['new title'])
    expect(cached_slug).to eq(new_slug)
  end

  it 'shows the form again for a slug that another site has, and stores nothing' do
    save_site({ 'slug' => 'other.example.test' })

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('id="site_settings_form"')
    expect_site_as_stored
  end
end
