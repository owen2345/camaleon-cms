# frozen_string_literal: true

# The custom-fields partial of the admin forms reads `params[:field_options]` as a set of groups, each
# a set of fields, to show the submitted values again after a refused or a failed save. The partial
# leaves out each part that has the wrong shape, so a malformed param gives no 500 in the view.
# The post save refuses a `field_options` that is not a set of groups, before any write, and renders
# its form again (meta_container_refusal_spec.rb). A failed validation renders the form again on every
# form with the partial. The category form stands in for those forms.
RSpec.describe 'Security: the admin form renders again with a malformed field_options', type: :request do
  include_context 'with the post editor'

  def update_post(params)
    patch "/admin/post_type/#{post_type.id}/posts/#{published_post.id}",
          params: "post[title]=Changed&post[content]=body&#{params}",
          headers: { 'CONTENT_TYPE' => 'application/x-www-form-urlencoded' }
  end

  # The malformed shapes of the param, and of a group or a field entry inside it.
  param_shapes = { 'field_options is a scalar' => 'field_options=foo',
                   'field_options is a list' => 'field_options[]=x' }
  group_shapes = { 'a group is a scalar' => 'field_options[0]=x',
                   'a group is a list' => 'field_options[0][]=x',
                   'a field entry is a list' => 'field_options[0][note][]=x' }

  before { sign_in_as(admin, site: current_site) }

  context 'with a field group of the post' do
    before { add_note_field('Post') }

    param_shapes.each do |shape, field_options|
      it "renders the refused post form when #{shape}" do
        update_post("post[status]=published&#{field_options}")

        expect(response).to have_http_status(:ok)
        expect(response.body).to include(I18n.t('camaleon_cms.admin.post.message.malformed_group',
                                                group: 'field_options'))
        expect(stored_post.title).not_to eq('Changed')
      end
    end

    group_shapes.merge('a field entry is a scalar' => 'field_options[0][note]=x').each do |shape, field_options|
      it "renders the refused post form with an unknown status when #{shape}" do
        update_post("post[status]=nope&#{field_options}")

        expect(response).to have_http_status(:ok)
        expect(response.body)
          .to include(I18n.t('camaleon_cms.admin.post.message.status_not_offered', field: 'post[status]'))
        expect(stored_post.title).not_to eq('Changed')
      end
    end

    it 'shows the submitted value again in the refused post form' do
      update_post('post[status]=nope&field_options[0][note][values][0]=kept+note')

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('{"note":["kept note"]}')
    end
  end

  # A category with the slug of another category of the post type fails its validation.
  # The note field in the body shows that the form rendered the custom-fields partial.
  param_shapes.merge(group_shapes).each do |shape, field_options|
    it "renders the category form again when the category is invalid and #{shape}" do
      add_note_field('Category')
      post_type.categories.create!(name: 'Taken', slug: 'taken')

      post "/admin/post_type/#{post_type.id}/categories",
           params: "category[name]=Taken+again&category[slug]=taken&#{field_options}",
           headers: { 'CONTENT_TYPE' => 'application/x-www-form-urlencoded' }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(I18n.t('camaleon_cms.admin.post.message.requires_different_slug'))
      expect(response.body).to include('data-field-key="note"')
      expect(post_type.categories.where(slug: 'taken').count).to eq(1)
    end
  end
end
