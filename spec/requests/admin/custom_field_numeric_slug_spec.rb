# frozen_string_literal: true

# A custom field can have a slug of digits only, such as `2020`. The form posts each field as
# `field_options[<index>][<slug>]`, so such a field gives a numeric key with a hash value. Rails
# reads a hash with such a key as nested attributes when a nested filter permits it. The permit that
# all admin saves share then kept only the numeric keys of the group and dropped its other fields.
# From Rails 7.0, Rails does not do this when the filter names a numeric key.
RSpec.describe 'Admin custom field values beside a field with a numeric slug', type: :request do
  init_site

  let(:current_site) { Cama::Site.first.decorate }
  let(:admin) { create(:user, role: 'admin', site: current_site) }
  let(:post_type) { current_site.post_types.where(slug: 'post').first }
  let(:post_type_group) do
    CamaleonCms::CustomFieldGroup.create!(name: 'Post fields', slug: 'post-fields', object_class: 'PostType_Post',
                                          objectid: post_type.id, site: current_site)
  end
  let!(:subtitle) { text_box(post_type_group, 'subtitle') }
  let(:record) { create(:post, post_type: post_type, owner: admin, title: 'A post') }

  before do
    allow_any_instance_of(CamaleonCms::AdminController).to receive(:current_site).and_return(current_site)
    sign_in_as(admin, site: current_site)
    record.set_field_value('subtitle', 'old')
  end

  def text_box(group, slug)
    group.add_manual_field({ 'name' => slug, 'slug' => slug }, { 'field_key' => 'text_box' })
  end

  def entry(field, value)
    { 'id' => field.id.to_s, 'group_number' => '0', 'values' => { '0' => value } }
  end

  def save_post(field_options)
    patch "/admin/post_type/#{post_type.id}/posts/#{record.id}", params: {
      post: { title: 'A post', content: '<p>plain</p>', status: 'published' }, field_options: field_options
    }
    expect(response).to have_http_status(:found)
    expect(flash[:error]).to be_nil
    CamaleonCms::Post.find(record.id)
  end

  # The post editor also shows the field groups of the post itself. It gives index 0 to the first
  # instance of each field group, so the fields of two groups arrive in one `field_options[0]`. The
  # post save stores only the fields of the post type.
  context 'when a field group of the post itself holds a field with a numeric slug' do
    let(:own_group) do
      CamaleonCms::CustomFieldGroup.create!(name: 'Own fields', slug: 'own-fields', object_class: 'Post',
                                            objectid: record.id, site: current_site)
    end
    let!(:year) { text_box(own_group, '2020') }

    it 'stores the value of the post type field from the post save' do
      saved = save_post('0' => { 'subtitle' => entry(subtitle, 'new'), '2020' => entry(year, 'a year') })

      expect(saved.get_field_values('subtitle')).to eq(['new'])
    end

    it 'stores the value of the post type field from the draft save' do
      post "/admin/post_type/#{post_type.id}/drafts", params: {
        post_id: record.id, post: { title: 'A draft' },
        field_options: { '0' => { 'subtitle' => entry(subtitle, 'new'), '2020' => entry(year, 'a year') } }
      }

      draft = post_type.posts.drafts.find_by!(post_parent: record.id)
      expect(draft.get_field_values('subtitle')).to eq(['new'])
    end
  end

  it 'stores the value of a registered field beside a numeric slug that names no field' do
    saved = save_post('0' => { 'subtitle' => entry(subtitle, 'new'),
                               '2020' => { 'id' => '1', 'values' => { '0' => 'a year' } } })

    expect(saved.get_field_values('subtitle')).to eq(['new'])
    expect(saved.custom_field_values.where(custom_field_slug: '2020')).not_to exist
  end

  it 'stores the value of a registered field with a numeric slug and the values beside it' do
    year = text_box(post_type_group, '2020')

    saved = save_post('0' => { 'subtitle' => entry(subtitle, 'new'), '2020' => entry(year, 'a year') })

    expect(saved.get_field_values('subtitle')).to eq(['new'])
    expect(saved.get_field_values('2020')).to eq(['a year'])
  end

  # Only a forged request sends a numeric key inside the entry of a field. Before, Rails kept only
  # that key, and the save removed the stored values of the post.
  it 'stores the values of an entry that also holds a numeric key' do
    saved = save_post('0' => { 'subtitle' => entry(subtitle, 'new').merge('0' => { 'id' => '1' }) })

    expect(saved.get_field_values('subtitle')).to eq(['new'])
  end
end
