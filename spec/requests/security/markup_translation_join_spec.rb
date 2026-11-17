# frozen_string_literal: true

# String#translate removes the first marker of the locale on each line, anywhere in the line. The
# content scan read only the stored text, where a marker right after `<` is not inside a tag. The
# page shows the translation, where that `<` and the text after the marker form a tag. So an editor
# without post_content_unfiltered_html could store an event handler that ran on the page.
RSpec.describe 'Security: a tag that a translation joins', type: :request do
  include_context 'with the post editor'

  let(:joined) { "<!--:en--><p>Intro</p>\n<<!--:en-->img src=x onerror=alert(1)><!--:-->" }
  let(:refusal) { ERB::Util.html_escape(I18n.t('camaleon_cms.admin.post.message.content_rejected')) }

  before { sign_in_as(editor, site: current_site) }

  it 'refuses post content whose translation shows an event handler, and the page shows none' do
    expect(joined.translate(:en)).to eq("<p>Intro</p>\n<img src=x onerror=alert(1)>")

    update_published_post(post: { content: joined })

    expect(response.body).to include(refusal)
    expect(stored_post.content).not_to eq(joined)
    get "/#{stored_post.slug}"
    expect(Nokogiri::HTML5.parse(response.body).css('img[onerror]')).to be_empty
  end

  it 'refuses a summary whose translation shows an event handler' do
    update_published_post(meta: { summary: joined })

    expect(response.body).to include(refusal)
    expect(stored_post.get_meta('summary')).to be_blank
  end

  it 'refuses a custom field value whose translation shows an event handler' do
    group = CamaleonCms::CustomFieldGroup.create!(name: 'Extra', slug: 'extra', object_class: 'PostType_Post',
                                                  objectid: post_type.id, site: current_site.model)
    field = group.add_manual_field({ name: 'Body', slug: 'extra_body' }, { field_key: 'editor' })

    patch "/admin/post_type/#{post_type.id}/posts/#{published_post.id}", params: {
      post: { title: 'Changed title', content: 'body', status: 'published' },
      field_options: { '0' => { 'extra_body' => { 'id' => field.id.to_s, 'values' => { '0' => joined } } } }
    }

    expect(flash[:error]).to include('not allowed')
    expect(stored_post.get_field_value('extra_body')).to be_blank
  end

  it 'stores translated content with allowed markup unchanged' do
    translated = { en: "<p>Intro</p>\n<b>bold</b>", es: '<p>Hola</p>' }.to_translate

    update_published_post(post: { content: translated })

    expect(stored_post.content).to eq(translated)
  end
end
