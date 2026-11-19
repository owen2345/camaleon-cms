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

  # String#translate removes the first marker of the locale on each line, anywhere in the line. So a
  # translation can join `javascript:` that a marker splits in the stored text, and the shortcode
  # shows that translation.
  it 'refuses a script URL that a translation joins, and the shortcode inside a link adds none' do
    link = post_type.add_field({ 'name' => 'Link', 'slug' => 'link' }, { 'field_key' => 'url' }, 'Post')
    place_shortcode(published_post, %(<a href="[data field='link']">Shop</a>))
    sign_in_as(editor, site: current_site)
    value = "<!--:-->java<!--:en-->script:alert(1)\n<!--:en-->"
    expect(value.translate(:en)).to eq("javascript:alert(1)\n")

    save_note(stored_post, value, field: link)

    expect(flash[:error]).to include(I18n.t('camaleon_cms.admin.custom_field.message.value_rejected_uri', slug: 'link'))
    expect(stored_post.get_field_value('link')).to be_blank
    get "/#{stored_post.slug}"
    hrefs = Nokogiri::HTML5.parse(response.body).css('a').map { |anchor| anchor['href'].to_s.strip }
    expect(hrefs.grep(/\Ajavascript:/i)).to be_empty
  end

  # String#translate shows a marker that is not at the start of a translation. In an attribute with no
  # quotes, the `>` of that marker ends the tag, and the rest of the tag shows as text.
  it 'refuses a marker that the shortcode shows in an image value, and the tag keeps its attributes' do
    photo = post_type.add_field({ 'name' => 'Photo', 'slug' => 'photo' }, { 'field_key' => 'image' }, 'Post')
    place_shortcode(published_post, "<img src=https://cdn.example.test/[data field='photo'] alt=Photo>")
    sign_in_as(editor, site: current_site)

    save_note(stored_post, 'https://a.example.test/x<!--:-->y', field: photo)

    expect(flash[:error]).to include(
      I18n.t('camaleon_cms.admin.custom_field.message.value_rejected_url_characters', slug: 'photo')
    )
    expect(stored_post.get_field_value('photo')).to be_blank
    get "/#{stored_post.slug}"
    image = Nokogiri::HTML5.parse(response.body).at_css('img[src^="https://cdn.example.test/"]')
    expect(image['alt']).to eq('Photo')
  end

  # JSON.parse keeps only the last member of a key that occurs twice. The shortcode puts the stored
  # JSON into the page, with each member. So the scan reads each member, also one that a later
  # member of the same key replaces.
  it 'refuses a script in a member that a duplicate JSON key hides, and the shortcode shows none' do
    specs = post_type.add_field({ 'name' => 'Specs', 'slug' => 'specs' }, { 'field_key' => 'field_attrs' }, 'Post')
    place_shortcode(published_post, "[data field='specs']")
    sign_in_as(editor, site: current_site)

    save_note(stored_post, %({"attr":"#{script.gsub('"', '\"')}","attr":"Color"}), field: specs)

    expect(flash[:error]).to include(
      I18n.t('camaleon_cms.admin.custom_field.message.value_rejected_html', slug: 'specs')
    )
    expect(stored_post.get_field_value('specs')).to be_blank
    expect(scripts_on_page(stored_post)).to be_empty
  end

  # JSON.parse accepts a comment, and the shortcode puts the stored JSON with the comment into the page.
  it 'refuses a script in a JSON comment, and the shortcode shows none' do
    specs = post_type.add_field({ 'name' => 'Specs', 'slug' => 'specs' }, { 'field_key' => 'field_attrs' }, 'Post')
    place_shortcode(published_post, "[data field='specs']")
    sign_in_as(editor, site: current_site)

    save_note(stored_post, %({"attr":"Color"} /* #{script} */), field: specs)

    expect(flash[:error]).to include(
      I18n.t('camaleon_cms.admin.custom_field.message.value_rejected_html', slug: 'specs')
    )
    expect(stored_post.get_field_value('specs')).to be_blank
    expect(scripts_on_page(stored_post)).to be_empty
  end

  # The shortcode puts the stored JSON into the page. There `\"` does not escape the quote, so the
  # quote ends the attribute, and the text after it becomes an event handler.
  it 'refuses an escaped quote that ends an attribute in a JSON value, and the shortcode adds no event handler' do
    specs = post_type.add_field({ 'name' => 'Specs', 'slug' => 'specs' }, { 'field_key' => 'field_attrs' }, 'Post')
    place_shortcode(published_post, "[data field='specs']")
    sign_in_as(editor, site: current_site)

    save_note(stored_post, %({"attr":"a","value":"<img src=x title=\\"a onerror=alert(1);//\\">"}), field: specs)

    expect(flash[:error]).to include(
      I18n.t('camaleon_cms.admin.custom_field.message.value_rejected_html', slug: 'specs')
    )
    expect(stored_post.get_field_value('specs')).to be_blank
    get "/#{stored_post.slug}"
    expect(Nokogiri::HTML5.parse(response.body).css('img[onerror]')).to be_empty
  end

  # A theme can show a value of each kind with the_json_field, which parses the value as JSON and shows
  # the decoded members. The Rails JSON encoder escapes `<`, so the stored text has no tag, but the
  # decoded member has one.
  it 'refuses a script in a JSON member of a text_box value, which the_json_field shows' do
    sign_in_as(editor, site: current_site)
    value = { label: script }.to_json
    expect(value).not_to include('<')
    expect(JSON.parse(value).values).to include(script)

    save_note(stored_post, value)

    expect(flash[:error]).to include(refusal)
    expect(stored_post.get_field_value('note')).to be_blank
  end

  # String#sub reads a backslash sequence in a String replacement: `\'` gives the text after the match.
  # So the output of the first shortcode took in the second shortcode, and the second value then ended
  # the title attribute of the first value. Each value passes the scan alone.
  it 'shows two values as stored, and the second value does not end an attribute of the first' do
    second = post_type.add_field({ 'name' => 'Second', 'slug' => 'note2' }, { 'field_key' => 'text_box' }, 'Post')
    place_shortcode(published_post, "<p>[data field='note']</p><p>[data field='note2']</p>")
    sign_in_as(editor, site: current_site)
    first_value = %q(<img src="x" title="\'">)
    second_value = '" onerror="alert(1)//'

    patch "/admin/post_type/#{post_type.id}/posts/#{stored_post.id}", params: {
      post: { title: stored_post.title, content: stored_post.content, status: stored_post.status },
      field_options: { '0' => {
        note_field.slug => { 'id' => note_field.id.to_s, 'values' => { '0' => first_value } },
        second.slug => { 'id' => second.id.to_s, 'values' => { '0' => second_value } }
      } }
    }

    expect(flash[:error]).to be_blank
    expect(stored_post.get_field_value('note2')).to eq(second_value)
    get "/#{stored_post.slug}"
    expect(Nokogiri::HTML5.parse(response.body).css('img[onerror]')).to be_empty
    expect(response.body).to include("<p>#{first_value}</p><p>#{second_value}</p>")
  end

  it 'keeps a plain value of the field on the page' do
    place_shortcode(published_post, "[data field='note']")
    sign_in_as(editor, site: current_site)

    save_note(stored_post, 'Plain <b>note</b>')

    get "/#{stored_post.slug}"
    expect(response.body).to include('Plain <b>note</b>')
  end
end
