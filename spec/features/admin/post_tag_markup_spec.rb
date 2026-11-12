# frozen_string_literal: true

# The tag editor of the post form built each tag as HTML from the value of the tags input. The save
# of a post stores a tag name as sent. So an author who is not an administrator can store a name
# with a tag. That tag then ran its event handler in the form of an admin. The tags param of a GET
# link reached the same code. The editor must show a tag name as text.
RSpec.describe 'the tag editor of the post form', :js do
  init_site

  let(:post_type) { @post.post_type }
  let(:tag_name) { '<img src=q onerror="window.tagScriptRan=true">' }

  before { admin_sign_in }

  def posts_path
    "#{cama_root_relative_path}/admin/post_type/#{post_type.id}/posts"
  end

  # The form starts the tag editor one second after the page loads.
  def expect_tag_as_text(name)
    expect(page).to have_css('.tag-editor .tag-editor-tag', exact_text: name, wait: 10)
    expect(page).to have_no_css('.tag-editor img', visible: :all)
  end

  it 'shows a stored tag name with markup as text' do
    @post.update_tags("News,#{tag_name}")
    visit "#{posts_path}/#{@post.id}/edit"

    expect_tag_as_text(tag_name)
    expect(page).to have_css('.tag-editor .tag-editor-tag', exact_text: 'News')
  end

  it 'shows the tags param of a GET link as text' do
    visit "#{posts_path}/new?#{{ tags: tag_name }.to_query}"

    expect_tag_as_text(tag_name)
  end

  # A click on a tag puts its name into a text input. The click point sets only the caret, so the
  # example triggers the handler through jQuery.
  it 'keeps a tag name with a quote when the admin opens the tag' do
    quoted_name = 'a" onfocus="window.tagScriptRan=true'
    @post.update_tags(quoted_name)
    visit "#{posts_path}/#{@post.id}/edit"
    expect_tag_as_text(quoted_name)

    page.execute_script("$('.tag-editor .tag-editor-tag').first().trigger('click')")

    expect(find('.tag-editor .tag-editor-tag.active input').value).to eq(quoted_name)
    expect(page).to have_no_css('.tag-editor [onfocus]', visible: :all)
  end
end
