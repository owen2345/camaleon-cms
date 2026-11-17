# frozen_string_literal: true

# The admin form of a post sends each stored custom field value again, and set_field_values deletes
# the value rows and creates them again. The content_shortcodes gate checked each new row. So an
# editor without content_shortcodes could not save a post whose field held a shortcode that an
# administrator wrote, also when the editor changed only the title. The markup gate already skips
# such an unchanged value, and the shortcode gate now skips it too.
RSpec.describe 'Security: the shortcode gate and an unchanged field value', type: :request do
  include_context 'with the post editor'

  let!(:note_field) { add_note_field('Post') }
  let(:shortcode) { "[data field='other']" }
  let(:refusal) { I18n.t('camaleon_cms.admin.shortcodes.message.rejected') }

  # The value that an administrator saved. The example writes the column, because a save outside a
  # request is untrusted.
  def store_admin_value(value)
    published_post.set_field_value('note', 'plain')
    published_post.custom_field_values.find_by(custom_field_slug: 'note')
                  .update_column(:value, value) # rubocop:disable Rails/SkipsModelValidations
  end

  def save_post(title:, note:)
    patch "/admin/post_type/#{post_type.id}/posts/#{published_post.id}", params: {
      post: { title: title, content: published_post.content, status: 'published' },
      field_options: { '0' => { 'note' => { 'id' => note_field.id.to_s, 'values' => { '0' => note } } } }
    }
  end

  before do
    store_admin_value(shortcode)
    sign_in_as(editor, site: current_site)
  end

  it 'saves a title change of an editor and keeps the shortcode of the administrator' do
    save_post(title: 'Changed title', note: shortcode)

    expect(flash[:error]).to be_blank
    expect(stored_post.title).to eq('Changed title')
    expect(stored_post.get_field_value('note')).to eq(shortcode)
  end

  it 'still refuses a changed shortcode of an editor' do
    save_post(title: 'Changed title', note: "#{shortcode} [data field='note']")

    expect(flash[:error]).to include(refusal)
    expect(stored_post.title).to eq('Published post')
    expect(stored_post.get_field_value('note')).to eq(shortcode)
  end
end
