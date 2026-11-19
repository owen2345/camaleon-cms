# frozen_string_literal: true

# The content_shortcodes gate scans the stored text. But some renderers change the text before they
# give it to do_shortcode, so a stored text with no shortcode can show one:
# - String#translate removes the translation marker of a later line, so it joins `[data` and
#   ` field='secret']`. Post content, a taxonomy description and a field value are translated.
# - the_json_field parses a field value as JSON, and gives the text of each member to do_shortcode.
#   A JSON escape of a bracket shows a bracket there. A member that is an object shows as Ruby text
#   on one line, so it joins two strings that a line break of the stored text keeps apart.
# Before the fix, an author without content_shortcodes saved such a value, and the shortcode ran at
# render.
RSpec.describe 'Security: a shortcode that a renderer shows from a stored text without one', type: :request do
  include_context 'with the post editor'

  let!(:note_field) { add_note_field('Post') }
  let(:refusal) { I18n.t('camaleon_cms.admin.shortcodes.message.rejected') }
  let(:shortcode) { CamaleonCms::ShortcodeRegistry }

  def save_note(post, value)
    patch "/admin/post_type/#{post_type.id}/posts/#{post.id}", params: {
      post: { title: post.title, content: post.content, status: post.status },
      field_options: { '0' => { 'note' => { 'id' => note_field.id.to_s, 'values' => { '0' => value } } } }
    }
  end

  # The JSON escape of a character, built from its code: a backslash, `u` and four hex digits.
  def json_escape(char)
    "#{92.chr}u#{char.ord.to_s(16).rjust(4, '0')}"
  end

  # The texts that parse_html_json of CustomFieldsConcern gives to do_shortcode.
  def rendered_members(value)
    JSON.parse(value).with_indifferent_access.values.map { |member| member.to_s.translate(:en) }
  end

  before { sign_in_as(editor, site: current_site) }

  it 'refuses a field value whose JSON member escapes the brackets of a shortcode' do
    value = %({"attr":"Color","value":"#{json_escape('[')}data field='secret'#{json_escape(']')}"})
    expect(shortcode.content_has_shortcode?(value)).to be false
    expect(rendered_members(value)).to include("[data field='secret']")

    save_note(stored_post, value)

    expect(flash[:error]).to include(refusal)
    expect(stored_post.get_field_value('note')).to be_blank
  end

  it 'refuses a field value whose object member shows a shortcode as Ruby text' do
    value = %({"attr":"Color","value":{"a":"[data ",\n"b":"]"}})
    expect(shortcode.content_has_shortcode?(value)).to be false
    expect(rendered_members(value).any? { |text| shortcode.content_has_shortcode?(text) }).to be true

    save_note(stored_post, value)

    expect(flash[:error]).to include(refusal)
    expect(stored_post.get_field_value('note')).to be_blank
  end

  it 'refuses a field value whose translation joins a shortcode' do
    value = "<!--:en-->Note\n[data<!--:en--> field='secret']<!--:-->"
    expect(shortcode.content_has_shortcode?(value)).to be false
    expect(value.translate(:en)).to eq("Note\n[data field='secret']")

    save_note(stored_post, value)

    expect(flash[:error]).to include(refusal)
    expect(stored_post.get_field_value('note')).to be_blank
  end

  it 'refuses post content whose translation joins a shortcode' do
    content = "<!--:en--><p>Intro</p>\n[data<!--:en--> field='secret']<!--:-->"
    expect(content.translate(:en)).to eq("<p>Intro</p>\n[data field='secret']")

    update_published_post(post: { content: content })

    expect(response.body).to include(CGI.escapeHTML(refusal))
    expect(stored_post.content).not_to eq(content)
  end

  it 'stores a JSON field value with escaped brackets and no shortcode unchanged' do
    value = %({"attr":"Color","value":"<!--:en-->#{json_escape('[')}red#{json_escape(']')}<!--:-->"})

    save_note(stored_post, value)

    expect(flash[:error]).to be_blank
    expect(stored_post.get_field_value('note')).to eq(value)
  end

  it 'stores a translated field value with no shortcode unchanged' do
    value = "<!--:en-->Note\n[red]<!--:--><!--:es-->Nota<!--:-->"

    save_note(stored_post, value)

    expect(flash[:error]).to be_blank
    expect(stored_post.get_field_value('note')).to eq(value)
  end
end
