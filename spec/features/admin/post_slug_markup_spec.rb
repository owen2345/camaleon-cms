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
end
