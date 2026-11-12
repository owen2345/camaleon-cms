# frozen_string_literal: true

# After a failed save, the custom-fields partial of an admin form shows the submitted field values
# again, so the admin keeps what they entered. It read those values from the params of a GET request
# too. So a link such as posts/new?field_options[0][photo][values][]=<value> put its value into the
# form of the admin who opened it. The image preview of the form could then run markup from that
# value. A failed save never comes from a GET request. A GET request must show the
# values of the record, and a failed save must show the submitted values.
RSpec.describe 'Security: a GET request does not put field values into the admin form', type: :request do
  include_context 'with the post editor'

  let(:link_value) { 'value-from-the-link' }
  # The field values of the form, as the script of the partial gets them. The page also shows its
  # own URL, with the query, in its meta tags.
  let(:link_value_json) { %({"note":["#{link_value}"]}) }

  def add_group(object_class)
    group = CamaleonCms::CustomFieldGroup.create!(name: "#{object_class} fields", slug: object_class.underscore,
                                                  object_class: object_class, objectid: post_type.id,
                                                  site: current_site)
    group.add_manual_field({ 'name' => 'Note', 'slug' => 'note' }, { 'field_key' => 'text_box' })
  end

  def link_params
    { field_options: { '0' => { 'note' => { 'values' => [link_value] } } } }
  end

  before do
    add_group('PostType_Post')
    add_group('PostType_Category')
    sign_in_as(admin, site: current_site)
  end

  it 'shows no value of the link in the form of a new post' do
    get "/admin/post_type/#{post_type.id}/posts/new", params: link_params

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('build_custom_field_group(')
    expect(response.body).not_to include(link_value_json)
  end

  it 'shows the stored value and no value of the link in the form of an existing post' do
    published_post.set_field_value('note', 'stored-note')

    get "/admin/post_type/#{post_type.id}/posts/#{published_post.id}/edit", params: link_params

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('{"note":["stored-note"]}')
    expect(response.body).not_to include(link_value_json)
  end

  # A category with the slug of another category of the post type fails its validation.
  it 'shows the submitted value again after a failed create' do
    post_type.categories.create!(name: 'Taken', slug: 'taken')

    post "/admin/post_type/#{post_type.id}/categories",
         params: { category: { name: 'Taken again', slug: 'taken' } }.merge(link_params)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(I18n.t('camaleon_cms.admin.post.message.requires_different_slug'))
    expect(response.body).to include(link_value_json)
  end

  # An admin update is a PATCH request. A failed update must show the submitted values too.
  it 'shows the submitted value again after a failed update' do
    post_type.categories.create!(name: 'Taken', slug: 'taken')
    category = post_type.categories.create!(name: 'Other', slug: 'other')

    patch "/admin/post_type/#{post_type.id}/categories/#{category.id}",
          params: { category: { name: 'Other', slug: 'taken' } }.merge(link_params)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(I18n.t('camaleon_cms.admin.post.message.requires_different_slug'))
    expect(response.body).to include(link_value_json)
  end
end
