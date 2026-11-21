# frozen_string_literal: true

# The draft save stored the draft row and its metas before the custom-field values, with no
# transaction. A refused custom-field value then answered the XHR with a 422 and no draft id, and the
# row stayed. The post editor had no draft id, so each later save of a new post created one more
# draft row. Now the draft save writes in one transaction, as the post save does, and a refused
# draft save stores nothing.
RSpec.describe 'A refused draft save stores nothing', type: :request do
  include_context 'with the post editor'

  let(:script) { '<p>keep</p><script>alert(1)</script>' }
  let!(:parent) { create(:post, post_type: post_type, owner: editor, status: 'published') }
  let!(:field) do
    group = current_site.custom_field_groups.create!(name: 'Draft fields', slug: '_refused-draft-fields',
                                                     object_class: 'PostType_Post', objectid: post_type.id)
    group.add_manual_field({ 'name' => 'Body', 'slug' => 'refused_draft_body' }, { 'field_key' => 'editor' })
  end

  before do
    current_site.user_roles.find_by(slug: 'editor')
                .set_meta("_post_type_#{current_site.id}", edit: [post_type.id], create: [post_type.id])
    sign_in_as(editor, site: current_site)
  end

  # The body is a query string, because the request helper of Rails sends a list of hashes in
  # another shape. The post editor sends the draft save by XHR, without cama_ajax_request.
  def save_draft(values, title:, summary:, post_id: nil, draft_id: nil)
    params = { 'post' => { 'title' => title }, 'meta' => { 'summary' => summary },
               'field_options' => { '0' => { field.slug => { 'id' => field.id.to_s, 'values' => values } } } }
    params['post_id'] = post_id.to_s if post_id
    path = "/admin/post_type/#{post_type.id}/drafts"
    body = Rack::Utils.build_nested_query(params)
    draft_id ? patch("#{path}/#{draft_id}", params: body, xhr: true) : post(path, params: body, xhr: true)
  end

  def drafts_of_editor
    CamaleonCms::Post.unscoped.where(status: 'draft_child', user_id: editor.id)
  end

  def post_metas
    CamaleonCms::Meta.where(object_class: 'Post')
  end

  def stored_draft(id)
    CamaleonCms::Post.find(id)
  end

  {
    'a custom-field value that the scan refuses' => [
      ->(example) { { '0' => example.script } }, 'camaleon_cms.admin.custom_field.message.value_rejected_html'
    ],
    'custom-field values in a shape that the permit does not keep' => [
      ->(_example) { [{ 'attr' => 'a' }] }, 'camaleon_cms.admin.custom_field.message.values_unusable'
    ]
  }.each do |refused_values, (values_of, message_key)|
    context "with #{refused_values}" do
      let(:refused) { values_of.call(self) }
      let(:refusal) { I18n.t(message_key, slug: field.slug) }

      def expect_the_refusal
        expect(response).to have_http_status(422) # rubocop:disable RSpecRails/HttpStatus
        expect(response.body).to eq(refusal)
      end

      it 'stores no draft row and no meta when the draft create of a new post is refused' do
        expect { save_draft(refused, title: 'New post draft', summary: 'new summary') }
          .not_to(change { [drafts_of_editor.count, post_metas.count] })

        expect_the_refusal
      end

      it 'stores no draft row when the first draft create under a post is refused' do
        save_draft(refused, title: 'First draft', summary: 'new summary', post_id: parent.id)

        expect_the_refusal
        expect(drafts_of_editor.where(post_parent: parent.id)).not_to exist
      end

      it 'stores one draft row for a draft create that comes after two refused ones' do
        2.times { save_draft(refused, title: 'New post draft', summary: 'new summary') }

        save_draft({ '0' => 'usable' }, title: 'New post draft', summary: 'new summary')

        expect(response).to have_http_status(:ok)
        expect(drafts_of_editor.count).to eq(1)
        expect(response.parsed_body.dig('draft', 'id')).to eq(drafts_of_editor.first.id)
      end

      it 'keeps the buffer as stored when a draft create on that buffer is refused' do
        save_draft({ '0' => 'stored value' }, title: 'Stored title', summary: 'stored summary', post_id: parent.id)
        buffer_id = drafts_of_editor.find_by!(post_parent: parent.id).id

        save_draft(refused, title: 'New title', summary: 'new summary', post_id: parent.id)

        expect_the_refusal
        buffer = stored_draft(buffer_id)
        expect(buffer.title).to eq('Stored title')
        expect(buffer.get_meta('summary')).to eq('stored summary')
        expect(buffer.get_option('draft_status')).to be_blank
        expect(buffer.get_field_values(field.slug)).to eq(['stored value'])
        expect(drafts_of_editor.count).to eq(1)
      end

      it 'keeps the draft as stored when a draft update is refused' do
        save_draft({ '0' => 'stored value' }, title: 'Stored title', summary: 'stored summary')
        draft_id = drafts_of_editor.first.id

        save_draft(refused, title: 'New title', summary: 'new summary', draft_id: draft_id)

        expect_the_refusal
        draft = stored_draft(draft_id)
        expect(draft.title).to eq('Stored title')
        expect(draft.get_meta('summary')).to eq('stored summary')
        expect(draft.get_field_values(field.slug)).to eq(['stored value'])
      end
    end
  end

  it 'stores the draft, its meta, its option and its field value when no value is refused' do
    post "/admin/post_type/#{post_type.id}/drafts", xhr: true, params: {
      post_id: parent.id, post: { title: 'Draft title' }, meta: { summary: 'stored summary' },
      options: { seo_title: 'SEO' },
      field_options: { '0' => { field.slug => { 'id' => field.id.to_s, 'values' => { '0' => 'stored value' } } } }
    }

    draft = stored_draft(response.parsed_body.dig('draft', 'id'))
    expect(draft.title).to eq('Draft title')
    expect(draft.get_meta('summary')).to eq('stored summary')
    expect(draft.get_option('seo_title')).to eq('SEO')
    expect(draft.get_field_values(field.slug)).to eq(['stored value'])
  end
end
