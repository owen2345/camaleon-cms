# frozen_string_literal: true

# The post form shows the slug in its permalink line. The form code put the slug into the HTML of
# that line. No server code changes a slug. So an author who is not an administrator can store a
# slug with a tag through a request of their own. That tag then ran its event handler in the form of
# an admin. The permalink line must show the slug as text.
RSpec.describe 'the permalink line of the post form', :js do
  init_site

  let(:slug) { '<img src=q onerror="return">' }

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

  # The form code built the links with the replace method of JavaScript. That method reads the
  # characters $& in a replacement String as the text that it replaces. The links must hold such a
  # slug as it is.
  it 'gives the Preview link and the View link the URL that the line shows' do
    @post.object.update!(slug: 'a$&b')
    visit "#{cama_root_relative_path}/admin/post_type/#{@post.post_type.id}/posts/#{@post.id}/edit"

    expect(page).to have_css('.sl-slug-edit .sl-url', exact_text: 'a$&b', wait: 10)
    permalink = find('.sl-slug-edit .sl-link').text
    expect(page.evaluate_script("$('.sl-slug-edit .btn-preview').attr('href')")).to start_with("#{permalink}?draft_id=")
    expect(page.evaluate_script("$('.sl-slug-edit .btn-view').attr('href')")).to eq(permalink)
  end

  # A slug with ? or # ended the path of a link, so the link went to another URL and lost its draft
  # id. The links must hold the slug as one segment of the path.
  it 'gives the Preview link and the View link a slug with ? and # as one segment of the path' do
    @post.object.update!(slug: 'a?b#c d')
    visit "#{cama_root_relative_path}/admin/post_type/#{@post.post_type.id}/posts/#{@post.id}/edit"

    expect(page).to have_css('.sl-slug-edit .sl-url', exact_text: 'a?b#c d', wait: 10)
    link = find('.sl-slug-edit .sl-link').text.sub('a?b#c d', 'a%3Fb%23c%20d')
    expect(page.evaluate_script("$('.sl-slug-edit .btn-preview').attr('href')")).to start_with("#{link}?draft_id=")
    expect(page.evaluate_script("$('.sl-slug-edit .btn-view').attr('href')")).to eq(link)
  end

  # Rails writes these characters as they are in a segment of a path. The links must do the same.
  it 'keeps the characters that a segment of a path can hold in the Preview link and the View link' do
    @post.object.update!(slug: 'a+b,c;d=e:f@g')
    visit "#{cama_root_relative_path}/admin/post_type/#{@post.post_type.id}/posts/#{@post.id}/edit"

    expect(page).to have_css('.sl-slug-edit .sl-url', exact_text: 'a+b,c;d=e:f@g', wait: 10)
    link = find('.sl-slug-edit .sl-link').text
    expect(page.evaluate_script("$('.sl-slug-edit .btn-preview').attr('href')")).to start_with("#{link}?draft_id=")
    expect(page.evaluate_script("$('.sl-slug-edit .btn-view').attr('href')")).to eq(link)
  end

  # A draft save writes the id of the draft into the draft_id param of the Preview link. The slug
  # comes before that param in the link, and a stored slug can hold the same text.
  it 'keeps a slug with the text &draft_id= in the Preview link after a draft save' do
    @post.object.update!(slug: 'x&draft_id=5')
    visit "#{cama_root_relative_path}/admin/post_type/#{@post.post_type.id}/posts/#{@post.id}/edit"

    expect(page).to have_css('.sl-slug-edit .sl-url', exact_text: 'x&draft_id=5', wait: 10)
    permalink = find('.sl-slug-edit .sl-link').text
    page.execute_script("App_post.save_draft_ajax(function () { $('body').attr('data-draft-saved', 'yes'); }, false)")
    expect(page).to have_css('body[data-draft-saved]', wait: 10)

    expect(page.evaluate_script("$('.sl-slug-edit .btn-preview').attr('href')"))
      .to match(/\A#{Regexp.escape(permalink)}\?draft_id=\d+\z/)
  end

  # Plugin code can add a param to the Preview link. A draft save must change only the draft id.
  it 'keeps a param after the draft id of the Preview link after a draft save' do
    visit "#{cama_root_relative_path}/admin/post_type/#{@post.post_type.id}/posts/#{@post.id}/edit"

    expect(page).to have_css('.sl-slug-edit .sl-url', exact_text: @post.slug, wait: 10)
    permalink = find('.sl-slug-edit .sl-link').text
    page.execute_script(<<~JS)
      var link = $('.sl-slug-edit .btn-preview');
      link.attr('href', link.attr('href') + '&lang=es');
      App_post.save_draft_ajax(function () { $('body').attr('data-draft-saved', 'yes'); }, false);
    JS
    expect(page).to have_css('body[data-draft-saved]', wait: 10)

    expect(page.evaluate_script("$('.sl-slug-edit .btn-preview').attr('href')"))
      .to match(/\A#{Regexp.escape(permalink)}\?draft_id=\d+&lang=es\z/)
  end

  # Each change of the slug writes the permalink line again. The line must then hold one URL.
  it 'shows one URL with the new slug after the admin edits the slug' do
    visit "#{cama_root_relative_path}/admin/post_type/#{@post.post_type.id}/posts/#{@post.id}/edit"

    expect(page).to have_css('.sl-slug-edit .sl-url', exact_text: @post.slug, wait: 10)
    permalink = find('.sl-slug-edit .sl-link').text
    find('.sl-slug-edit .btn-edit').click
    find('.sl-slug-edit .sl-link input').set('Other Slug')
    find('.sl-slug-edit .btn-cancel').click
    expect(page).to have_css('.sl-slug-edit .sl-link', exact_text: permalink)

    find('.sl-slug-edit .btn-edit').click
    find('.sl-slug-edit .sl-link input').set('New Slug')
    find('.sl-slug-edit .btn-edit').click

    expect(page).to have_css('.sl-slug-edit .sl-link', exact_text: permalink.sub(@post.slug, 'new-slug'))
    expect(page).to have_css('.sl-slug-edit .sl-url', exact_text: 'new-slug', count: 1)
  end

  # A decorator of a host app can give a URL with no place for the slug. The form joined the slug to
  # the end of that URL. The line and the links must hold the URL as it is.
  context 'when the URL of the post has no placeholder for the slug' do
    let(:url) { 'http://www.example.com/fixed' }

    before do
      allow_any_instance_of(CamaleonCms::PostDecorator)
        .to receive(:the_urls).and_return(@site.get_languages.index_with { |_language| url })
    end

    # The line shows no slug for such a URL, so the Edit link has no slug to open.
    it 'shows the URL as it is with no Edit link, and gives it to the Preview link and the View link' do
      visit "#{cama_root_relative_path}/admin/post_type/#{@post.post_type.id}/posts/#{@post.id}/edit"

      expect(page).to have_css('.sl-slug-edit .sl-link', exact_text: url, wait: 10)
      expect(page).to have_no_css('.sl-slug-edit .btn-edit', visible: :all)
      expect(page.evaluate_script("$('.sl-slug-edit .btn-preview').attr('href')")).to start_with("#{url}?draft_id=")
      expect(page.evaluate_script("$('.sl-slug-edit .btn-view').attr('href')")).to eq(url)
    end
  end

  # With no URL for the language of the form, the code that starts the form threw. The editor of the
  # content then did not start. The line has no URL for a link, so it shows the slug alone.
  context 'when the post has no URL for the language of the form' do
    before { allow_any_instance_of(CamaleonCms::PostDecorator).to receive(:the_urls).and_return({}) }

    it 'starts the form and shows the slug alone, with no Preview link and no View link' do
      visit "#{cama_root_relative_path}/admin/post_type/#{@post.post_type.id}/posts/#{@post.id}/edit"

      expect(page).to have_css('.sl-slug-edit .btn-edit', wait: 10)
      expect(page).to have_css('.sl-slug-edit .sl-link', exact_text: @post.slug)
      expect(page).to have_no_css('.sl-slug-edit .btn-preview, .sl-slug-edit .btn-view', visible: :all)
    end
  end
end
