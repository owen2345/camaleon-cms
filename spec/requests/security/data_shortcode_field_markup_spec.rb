# frozen_string_literal: true

# The data shortcode does not escape a custom field value: `[data field='note']` puts the stored
# value into the post content, and the theme shows that content with `raw`. So the save scans the
# value of every field kind, also a text_box, for an author without post_content_unfiltered_html.
# Before that scan, such an author could put a script in a text_box value. The script ran on each
# page where an administrator put the shortcode. The shortcode can read the field of the same post,
# or of another post (`key=` or `id=`).
RSpec.describe 'Security: data shortcode output of a custom field', type: :request do
  include_context 'with the post editor'

  let(:script) { '<script>alert("note")</script>' }
  let!(:note_field) { add_note_field('Post') }
  let(:refusal) do
    I18n.t('camaleon_cms.admin.custom_field.message.value_rejected_html', slug: 'note')
  end

  # The content that an administrator saves. The save of an administrator passes the content checks,
  # so the example writes the column directly.
  def place_shortcode(post, shortcode)
    post.update_column(:content, "<p>Before</p>#{shortcode}<p>After</p>") # rubocop:disable Rails/SkipsModelValidations
  end

  def save_note(post, value, field: note_field)
    patch "/admin/post_type/#{post_type.id}/posts/#{post.id}", params: {
      post: { title: post.title, content: post.content, status: post.status },
      field_options: { '0' => { field.slug => { 'id' => field.id.to_s, 'values' => { '0' => value } } } }
    }
  end

  def scripts_on_page(post)
    get "/#{post.slug}"
    expect(response).to have_http_status(:ok)
    Nokogiri::HTML5.parse(response.body).css('script').map(&:text).grep(/alert\("note"\)/)
  end

  it 'refuses the script of an editor, and the data shortcode of the same post shows none' do
    place_shortcode(published_post, "[data field='note']")
    sign_in_as(editor, site: current_site)

    save_note(stored_post, script)

    expect(flash[:error]).to include(refusal)
    expect(stored_post.get_field_value('note')).to be_blank
    expect(scripts_on_page(stored_post)).to be_empty
  end

  # Without the scan, the save of the contributor stores the value and sets the post to pending. The
  # shortcode reads only a published post, so the example publishes the post again, as an
  # administrator does after a review.
  it 'refuses the script of a contributor, and the data shortcode of another post shows none' do
    own_post = create(:post, post_type: post_type, owner: contributor, title: 'Bio', slug: 'contributor-bio',
                             status: 'published')
    place_shortcode(published_post, "[data key='contributor-bio' field='note']")
    sign_in_as(contributor, site: current_site)

    save_note(own_post, script)

    expect(flash[:error]).to include(refusal)
    expect(own_post.reload.get_field_value('note')).to be_blank
    own_post.update_column(:status, 'published') # rubocop:disable Rails/SkipsModelValidations
    expect(scripts_on_page(stored_post)).to be_empty
  end

  # A shortcode inside a tag puts the value into an attribute. The value `x" onerror="alert(1)` has no
  # `<`, so the markup rule passes it. A URL kind also refuses each character that ends an attribute.
  it 'refuses a quote in an image value, and the shortcode inside a tag adds no event handler' do
    photo = post_type.add_field({ 'name' => 'Photo', 'slug' => 'photo' }, { 'field_key' => 'image' }, 'Post')
    place_shortcode(published_post, %(<img src="[data field='photo']" alt="Photo">))
    sign_in_as(editor, site: current_site)

    save_note(stored_post, 'x" onerror="alert(1)', field: photo)

    expect(flash[:error]).to include(
      I18n.t('camaleon_cms.admin.custom_field.message.value_rejected_url_characters', slug: 'photo')
    )
    expect(stored_post.get_field_value('photo')).to be_blank
    get "/#{stored_post.slug}"
    expect(Nokogiri::HTML5.parse(response.body).css('img[onerror]')).to be_empty
  end

  # Without quotes, the attribute value ends at whitespace. When the shortcode follows other characters
  # of the value, a leading space in the image value ends the attribute, and the rest of the value
  # becomes a new attribute.
  it 'refuses a leading space in an image value, and the shortcode with no quotes adds no event handler' do
    photo = post_type.add_field({ 'name' => 'Photo', 'slug' => 'photo' }, { 'field_key' => 'image' }, 'Post')
    place_shortcode(published_post, "<img src=https://cdn.example.test/[data field='photo'] alt=Photo>")
    sign_in_as(editor, site: current_site)

    save_note(stored_post, ' onerror=alert(1)', field: photo)

    expect(flash[:error]).to include(
      I18n.t('camaleon_cms.admin.custom_field.message.value_rejected_url_characters', slug: 'photo')
    )
    expect(stored_post.get_field_value('photo')).to be_blank
    get "/#{stored_post.slug}"
    expect(Nokogiri::HTML5.parse(response.body).css('img[onerror]')).to be_empty
  end

  it 'keeps a plain value of the field on the page' do
    place_shortcode(published_post, "[data field='note']")
    sign_in_as(editor, site: current_site)

    save_note(stored_post, 'Plain <b>note</b>')

    get "/#{stored_post.slug}"
    expect(response.body).to include('Plain <b>note</b>')
  end
end
