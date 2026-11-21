# frozen_string_literal: true

# The permit that all admin saves share keeps `values` as a hash keyed by index or as a list of
# scalars. It does not keep `values` in any other shape. set_field_values deletes each stored value
# of the record before it writes. So an entry that lost its `values` in the permit removed the stored
# values of its field, and the save reported success. So did a field entry that is a scalar or a
# list, which the permit left out of the payload. Now the permit refuses such a save. An entry with
# no `values` still removes the stored values of its field: the form sends that entry for a
# checkboxes field with no option checked.
RSpec.describe 'Admin custom field values submitted in a shape that the permit does not keep', type: :request do
  init_site

  let(:current_site) { Cama::Site.first.decorate }
  let(:admin) { create(:user, role: 'admin', site: current_site) }
  let(:site_group) do
    current_site.custom_field_groups.create!(name: 'Site Group', slug: '_site-group', object_class: 'Site',
                                             objectid: current_site.id)
  end
  let(:checkboxes_options) do
    { 'field_key' => 'checkboxes',
      'multiple_options' => %w[1 2 3].map { |value| { 'title' => "Option #{value}", 'value' => value } } }
  end
  let!(:colors) { site_group.add_manual_field({ 'name' => 'Colors', 'slug' => 'colors' }, checkboxes_options) }
  let!(:title) { site_group.add_manual_field({ 'name' => 'Title', 'slug' => 'title' }, { 'field_key' => 'text_box' }) }

  before do
    allow_any_instance_of(CamaleonCms::AdminController).to receive(:current_site).and_return(current_site)
    sign_in_as(admin, site: current_site)
    current_site.set_field_value('title', 'stored title')
    current_site.set_field_value('colors', %w[1 3])
  end

  # The body is a query string, because the request helper of Rails sends a nested list
  # (`values[][]`) as a list of scalars.
  def save_site(field_options)
    patch '/admin/settings/site_saved', params: Rack::Utils.build_nested_query(
      'site' => { 'name' => current_site.name, 'slug' => current_site.slug }, 'field_options' => field_options
    )
    CamaleonCms::Site.find(current_site.id)
  end

  def title_entry(value)
    { 'id' => title.id.to_s, 'values' => { '0' => value } }
  end

  def colors_entry(values)
    { 'id' => colors.id.to_s, 'values' => values }
  end

  def refusal_of(field)
    I18n.t('camaleon_cms.admin.custom_field.message.values_unusable', slug: field.slug)
  end

  {
    'a list of hashes' => [{ 'attr' => 'a', 'value' => 'b' }],
    'a nested list' => [%w[1 3]],
    'a list that holds a scalar and a hash' => ['1', { 'attr' => 'a' }],
    'a scalar' => 'foo'
  }.each do |shape, unusable|
    it "refuses a save with a field whose values are #{shape}, and keeps each stored value" do
      site = save_site('0' => { 'title' => title_entry('new title'), 'colors' => colors_entry(unusable) })

      expect(response).to redirect_to(cama_admin_dashboard_path)
      expect(flash[:error]).to eq(refusal_of(colors))
      expect(flash[:notice]).to be_nil
      expect(site.get_field_values('colors')).to eq(%w[1 3])
      expect(site.get_field_values('title')).to eq(['stored title'])
    end
  end

  { 'a scalar' => 'foo', 'a list' => %w[1 3], 'a list of hashes' => [{ 'values' => %w[1 3] }] }.each do |shape, entry|
    it "refuses a save with a field entry that is #{shape}, and keeps each stored value" do
      site = save_site('0' => { 'title' => title_entry('new title'), 'colors' => entry })

      expect(flash[:error]).to eq(refusal_of(colors))
      expect(flash[:notice]).to be_nil
      expect(site.get_field_values('colors')).to eq(%w[1 3])
      expect(site.get_field_values('title')).to eq(['stored title'])
    end
  end

  it 'answers an XHR without cama_ajax_request with the refusal as text and a 422' do
    patch '/admin/settings/site_saved', xhr: true, params: Rack::Utils.build_nested_query(
      'site' => { 'name' => current_site.name, 'slug' => current_site.slug },
      'field_options' => { '0' => { 'colors' => colors_entry('foo') } }
    )

    expect(response).to have_http_status(422) # rubocop:disable RSpecRails/HttpStatus
    expect(response.body).to eq(refusal_of(colors))
    expect(CamaleonCms::Site.find(current_site.id).get_field_values('colors')).to eq(%w[1 3])
  end

  it 'refuses a post save, and stores no attribute of the post' do
    post_type = current_site.post_types.where(slug: 'post').first
    sizes = post_type.add_field({ 'name' => 'Sizes', 'slug' => 'sizes' }, checkboxes_options)
    record = create(:post, post_type: post_type, owner: admin, slug: 'unusable-values-post', status: 'published',
                           title: 'Stored post title')
    record.set_field_value('sizes', %w[2])

    patch "/admin/post_type/#{post_type.id}/posts/#{record.id}", params: Rack::Utils.build_nested_query(
      'post' => { 'title' => 'New post title', 'content' => 'body', 'status' => 'published' },
      'field_options' => { '0' => { 'sizes' => { 'id' => sizes.id.to_s, 'values' => [{ 'attr' => 'a' }] } } }
    )

    expect(flash[:error]).to eq(refusal_of(sizes))
    record = CamaleonCms::Post.find(record.id)
    expect(record.title).to eq('Stored post title')
    expect(record.get_field_values('sizes')).to eq(%w[2])
  end

  # The theme save writes the theme_fields payload before the field_options payload. The permit of
  # both payloads must come before the first write, or the refusal comes after a delete.
  it 'refuses a theme save with usable theme_fields, and keeps each stored value of the theme' do
    theme = current_site.get_theme
    theme_group = theme.add_field_group({ name: 'Theme Group', slug: '_theme-group' })
    footer = theme_group.add_manual_field({ 'name' => 'Footer', 'slug' => 'footer' }, { 'field_key' => 'text_box' })
    tones = theme_group.add_manual_field({ 'name' => 'Tones', 'slug' => 'tones' }, checkboxes_options)
    theme.set_field_value('footer', 'stored footer')
    theme.set_field_value('tones', %w[2])

    post '/admin/settings/save_theme', params: Rack::Utils.build_nested_query(
      'theme_fields' => { '0' => { 'footer' => { 'id' => footer.id.to_s, 'values' => { '0' => 'new footer' } } } },
      'field_options' => { '0' => { 'tones' => { 'id' => tones.id.to_s, 'values' => [{ 'attr' => 'a' }] } } }
    )

    expect(flash[:error]).to eq(refusal_of(tones))
    theme = CamaleonCms::Theme.find(theme.id)
    expect(theme.get_field_values('footer')).to eq(['stored footer'])
    expect(theme.get_field_values('tones')).to eq(%w[2])
  end

  it 'removes the stored values of a checkboxes field that the form submits with no option checked' do
    site = save_site('0' => { 'title' => title_entry('new title'),
                              'colors' => { 'id' => colors.id.to_s, 'group_number' => '0' } })

    expect(response).to have_http_status(:found)
    expect(flash[:error]).to be_nil
    expect(site.get_field_values('title')).to eq(['new title'])
    expect(site.custom_field_values.where(custom_field_slug: 'colors')).not_to exist
  end

  it 'removes the stored values of a field whose values are an empty String' do
    site = save_site('0' => { 'title' => title_entry('new title'), 'colors' => colors_entry('') })

    expect(flash[:error]).to be_nil
    expect(site.get_field_values('title')).to eq(['new title'])
    expect(site.custom_field_values.where(custom_field_slug: 'colors')).not_to exist
  end
end
