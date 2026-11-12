# frozen_string_literal: true

# The post form shows the slug in its permalink line. The form code put the slug into the HTML of
# that line. No server code changes a slug. So an author who is not an administrator can store a
# slug with a tag through a request of their own. That tag then ran its event handler in the form of
# an admin. The permalink line must show the slug as text.
RSpec.describe 'the permalink line of the post form', :js do
  init_site

  let(:slug) { '<img src=q onerror="window.slugScriptRan=true">' }

  before { admin_sign_in }

  it 'shows a stored slug with markup as text' do
    @post.object.update!(slug: slug)
    visit "#{cama_root_relative_path}/admin/post_type/#{@post.post_type.id}/posts/#{@post.id}/edit"

    expect(page).to have_css('.sl-slug-edit .sl-url', exact_text: slug, wait: 10)
    expect(page).to have_no_css('.sl-slug-edit img', visible: :all)
  end

  it 'shows the URL of the post around a plain slug' do
    visit "#{cama_root_relative_path}/admin/post_type/#{@post.post_type.id}/posts/#{@post.id}/edit"

    expect(page).to have_css('.sl-slug-edit .sl-url', exact_text: @post.slug, wait: 10)
    expect(find('.sl-slug-edit .sl-link').text).to match(%r{\Ahttp.+/#{Regexp.escape(@post.slug)}})
  end

  # String#replace reads $& in a replacement String as the text that it replaces. The links must
  # hold the slug as the post stores it.
  it 'gives the Preview link and the View link the URL that the line shows' do
    @post.object.update!(slug: 'a$&b')
    visit "#{cama_root_relative_path}/admin/post_type/#{@post.post_type.id}/posts/#{@post.id}/edit"

    expect(page).to have_css('.sl-slug-edit .sl-url', exact_text: 'a$&b', wait: 10)
    permalink = find('.sl-slug-edit .sl-link').text
    expect(page.evaluate_script("$('.sl-slug-edit .btn-preview').attr('href')")).to start_with("#{permalink}?draft_id=")
    expect(page.evaluate_script("$('.sl-slug-edit .btn-view').attr('href')")).to eq(permalink)
  end
end
