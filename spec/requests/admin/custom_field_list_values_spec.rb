# frozen_string_literal: true

# The admin JavaScript renames the `values[]` inputs of a custom field to `values[<index>]`. The
# checkboxes field keeps the `values[]` name, so it submits a list of scalars. The permit that all
# admin saves share keeps both shapes. Without the list filter, a save stores nothing for the
# checkboxes field and removes its stored values. The permit drops a list that holds a non-scalar.
RSpec.describe 'Admin custom field values submitted as a list', type: :request do
  init_site

  let(:current_site) { Cama::Site.first.decorate }
  let(:admin) { create(:user, role: 'admin', site: current_site) }
  let(:post_type) { current_site.post_types.where(slug: 'post').first }
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
  end

  def save_site(field_options)
    patch '/admin/settings/site_saved', params: {
      site: { name: current_site.name, slug: current_site.slug }, field_options: field_options
    }
    expect(response).to have_http_status(:found)
    CamaleonCms::Site.find(current_site.id)
  end

  it "stores a checkboxes field's checked options, in the order submitted" do
    site = save_site('0' => { 'colors' => { 'id' => colors.id.to_s, 'values' => %w[3 1] } })

    expect(site.get_field_values('colors')).to eq(%w[3 1])
    # A database gives no order to rows that have the same `term_order`.
    expect(site.custom_field_values.where(custom_field_slug: 'colors').pluck(:value, :term_order))
      .to eq([['3', 0], ['1', 1]])
  end

  it 'keeps a stored checkboxes value that the save submits again' do
    current_site.set_field_value('colors', %w[1 3])

    site = save_site('0' => { 'colors' => { 'id' => colors.id.to_s, 'values' => %w[1 3] } })

    expect(site.get_field_values('colors')).to eq(%w[1 3])
  end

  it 'stores a field keyed by index and a field submitted as a list from one save' do
    site = save_site('0' => { 'title' => { 'id' => title.id.to_s, 'values' => { '0' => 'a title' } },
                              'colors' => { 'id' => colors.id.to_s, 'values' => %w[2] } })

    expect(site.get_field_values('title')).to eq(['a title'])
    expect(site.get_field_values('colors')).to eq(%w[2])
  end

  it 'stores nothing for a field whose list holds hashes' do
    site = save_site('0' => { 'title' => { 'id' => title.id.to_s, 'values' => { '0' => 'a title' } },
                              'colors' => { 'id' => colors.id.to_s, 'values' => [{ 'attr' => 'a', 'value' => 'b' }] } })

    expect(site.get_field_values('title')).to eq(['a title'])
    expect(site.custom_field_values.where(custom_field_slug: 'colors')).not_to exist
  end

  it "stores a post's checkboxes field" do
    sizes = post_type.add_field({ 'name' => 'Sizes', 'slug' => 'sizes' }, checkboxes_options)
    record = create(:post, post_type: post_type, owner: admin, slug: 'list-values-post', status: 'published')

    patch "/admin/post_type/#{post_type.id}/posts/#{record.id}", params: {
      post: { title: 'List values post', content: 'body', status: 'published' },
      field_options: { '0' => { 'sizes' => { 'id' => sizes.id.to_s, 'values' => %w[1 2] } } }
    }

    expect(response).to have_http_status(:found)
    expect(record.reload.get_field_values('sizes')).to eq(%w[1 2])
  end
end
