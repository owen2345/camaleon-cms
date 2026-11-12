# frozen_string_literal: true

# The tag editor of the post form built each tag as HTML from the value of the tags input. The save
# of a post stores a tag name as sent. So an author who is not an administrator can store a name
# with markup. An element of that markup then ran its event handler in the form of an admin. The
# tags param of a GET link reached the same code. The editor must show a tag name as text.
RSpec.describe 'the tag editor of the post form', :js do
  init_site

  let(:post_type) { @post.post_type }
  let(:tag_name) { '<img src=q onerror="return">' }
  let(:tags_input) { %q{$('#form-post input[name="tags"]')} }
  let(:open_input) { "$('.tag-editor .tag-editor-tag.active input')" }

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
    quoted_name = 'a" onfocus="return'
    @post.update_tags(quoted_name)
    visit "#{posts_path}/#{@post.id}/edit"
    expect_tag_as_text(quoted_name)

    page.execute_script("$('.tag-editor .tag-editor-tag').first().trigger('click')")

    expect(find('.tag-editor .tag-editor-tag.active input').value).to eq(quoted_name)
    expect(page).to have_no_css('.tag-editor [onfocus]', visible: :all)
  end

  # The text form of a tag name must not change the normal use of the editor. The editor closes an
  # open tag on a focusout event.
  it 'renames, deletes and adds a tag, and the save stores the result' do
    @post.update_tags('News,Ruby on Rails,R&D')
    visit "#{posts_path}/#{@post.id}/edit"
    expect(page).to have_css('.tag-editor .tag-editor-tag', exact_text: 'R&D', wait: 10)

    page.execute_script("$('.tag-editor .tag-editor-tag').eq(1).trigger('click')")
    expect(find('.tag-editor .tag-editor-tag.active input').value).to eq('Ruby on Rails')
    page.execute_script("#{open_input}.val('Rails 8').trigger('focusout')")
    expect(page).to have_css('.tag-editor .tag-editor-tag', exact_text: 'Rails 8')

    page.execute_script("#{tags_input}.tagEditor('removeTag', 'News', true)")
    page.execute_script("#{tags_input}.tagEditor('addTag', 'Extra', true)")
    expect(page.evaluate_script("#{tags_input}.val()")).to eq('Rails 8,R&D,Extra')

    page.execute_script("$('#form-post').submit()")
    expect(page).to have_css('.alert-success', wait: 10)
    expect(@post.object.reload.post_tags.pluck(:name)).to contain_exactly('Rails 8', 'R&D', 'Extra')
  end

  # The addTag method puts a name into the input of a new tag and closes that tag, as the admin
  # does. A value with a delimiter gives one tag for each name.
  it 'shows a tag name with markup that the admin adds as text' do
    visit "#{posts_path}/#{@post.id}/edit"
    expect(page).to have_css('.tag-editor', wait: 10)

    page.execute_script("#{tags_input}.tagEditor('addTag', #{tag_name.to_json}, true)")
    expect_tag_as_text(tag_name)

    page.execute_script("#{tags_input}.tagEditor('addTag', #{"#{tag_name},Extra".to_json}, true)")
    expect(page).to have_css('.tag-editor .tag-editor-tag', exact_text: 'Extra')
    expect_tag_as_text(tag_name)
  end

  # A name that the admin types again replaces its tag, alone or in a list with a delimiter. After
  # each key, the editor copies the value of an open input into a hidden element of the open tag.
  # The editor must not read that copy as a tag. So the example sends a key event before the list.
  it 'keeps one tag for each name when the admin types names that exist already' do
    @post.update_tags('R&D,Q&A')
    visit "#{posts_path}/#{@post.id}/edit"
    expect(page).to have_css('.tag-editor .tag-editor-tag', exact_text: 'Q&A', wait: 10)

    page.execute_script("$('.tag-editor .tag-editor-tag').eq(1).trigger('click')")
    expect(find('.tag-editor .tag-editor-tag.active input').value).to eq('Q&A')
    page.execute_script("#{open_input}.trigger('keyup').val('Q&A,R&D').trigger('focusout')")
    expect(page.evaluate_script("#{tags_input}.val()")).to eq('Q&A,R&D')

    page.execute_script("#{open_input}.val('Q&A').trigger('focusout')")
    expect(page.evaluate_script("#{tags_input}.val()")).to eq('R&D,Q&A')
  end

  # Plugin and theme code can start a tag editor of its own. This one deletes a tag in three ways: a
  # right click, the removeTag method, and the Delete key on the selected tags.
  it 'gives a tag name as text to the beforeTagDelete callback' do
    visit "#{posts_path}/#{@post.id}/edit"
    expect(page).to have_css('.tag-editor', wait: 10)

    page.execute_script(<<~JS)
      window.deletedTags = [];
      $('<input type="text" id="plugin_tags">').appendTo('body').tagEditor({
        initialTags: ['R&D', 'Q&A', 'A<B'], forceLowercase: false, clickDelete: true, animateDelete: 0,
        beforeTagDelete: function (field, editor, tags, name) { window.deletedTags.push(name); }
      });
      $('#plugin_tags').next().find('.tag-editor-tag').first().trigger($.Event('mousedown', { which: 3 }));
      $('#plugin_tags').tagEditor('removeTag', 'Q&A', true);
    JS
    expect(page.evaluate_script("$('#plugin_tags').val()")).to eq('A<B')

    page.execute_script(<<~JS)
      var range = document.createRange();
      range.selectNodeContents($('#plugin_tags').next()[0]);
      getSelection().removeAllRanges();
      getSelection().addRange(range);
      $(document).trigger($.Event('keydown', { which: 46 }));
    JS
    expect(page.evaluate_script('window.deletedTags')).to eq(['R&D', 'Q&A', 'A<B'])
  end
end
