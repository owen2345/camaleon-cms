# frozen_string_literal: true

# The text editor of a post writes an empty paragraph as a line break. This rule must change only
# elements. The text of a script or a comment holds markup as text, and that text must come back
# unchanged. The text editors of Camaleon remove scripts. This spec adds the script element to the
# valid elements, as the camaleon_editor plugin does.
RSpec.describe 'Empty paragraphs in the text editor of a post', :js do
  let(:post_type_id) { CamaleonCms::Site.first.post_types.where(slug: :post).pick(:id) }

  def wait_until(seconds = 10)
    Timeout.timeout(seconds) { sleep(0.1) until yield }
  end

  def wait_for_content_editor
    wait_until { page.evaluate_script(<<~JS) }
      (function () {
        var editor = window.tinymce && tinymce.get('post_content');
        return !!(editor && editor.initialized);
      })()
    JS
  end

  # Creates the content editor again, with the script element in its valid elements.
  def open_editor_that_keeps_scripts
    admin_sign_in
    visit "#{cama_root_relative_path}/admin/post_type/#{post_type_id}/posts/new"
    wait_for_content_editor
    page.execute_script(<<~JS)
      tinymce.get('post_content').remove();
      var settings = cama_get_tinymce_settings({ selector: '#post_content' });
      settings.extended_valid_elements += ',script[*]';
      tinymce.init(settings);
    JS
    wait_for_content_editor
  end

  def round_trip(html)
    page.evaluate_script(<<~JS)
      (function () {
        var editor = tinymce.get('post_content');
        editor.setContent(#{html.to_json});
        return editor.getContent();
      })()
    JS
  end

  def selected_content(html)
    page.evaluate_script(<<~JS)
      (function () {
        var editor = tinymce.get('post_content');
        editor.setContent(#{html.to_json});
        editor.selection.select(editor.getBody(), true);
        return editor.selection.getContent();
      })()
    JS
  end

  it 'keeps empty paragraph markup in the text of a script' do
    open_editor_that_keeps_scripts

    expect(round_trip("<script>el.innerHTML = '<p></p>';</script>")).to eq("<script>el.innerHTML = '<p></p>';</script>")
    expect(round_trip("<script>el.innerHTML = '<P></P>';</script>")).to eq("<script>el.innerHTML = '<P></P>';</script>")
    expect(selected_content("<script>el.innerHTML = '<p></p>';</script><p></p>"))
      .to eq("<script>el.innerHTML = '<p></p>';</script>\n<br />")
  end

  it 'keeps empty paragraph markup in the text of a comment' do
    open_editor_that_keeps_scripts

    expect(round_trip('<!--<p></p>-->')).to eq('<!--<p></p>-->')
  end

  it 'keeps empty paragraph markup in the content of a noscript element' do
    open_editor_that_keeps_scripts

    expect(round_trip('<p>a</p><noscript><p></p><P></P></noscript>'))
      .to eq("<p>a</p>\n<noscript><p></p><P></P></noscript>")
  end

  # The media plugin writes the content of a media element again, so the case of a tag can change.
  it 'keeps an empty paragraph in the content of a media element' do
    open_editor_that_keeps_scripts

    expect(round_trip('<p>a</p><video controls><p></p></video>'))
      .to eq("<p>a</p>\n<p><video controls=\"controls\" width=\"300\" height=\"150\"><p></p></video></p>")
  end

  it 'writes an empty paragraph with no attributes as a line break' do
    open_editor_that_keeps_scripts

    expect(round_trip('<p>a</p><p></p><p>b</p>')).to eq("<p>a</p>\n<br />\n<p>b</p>")
    expect(round_trip('<p>a</p><p><br></p><p> </p><p><strong></strong></p>'))
      .to eq("<p>a</p>\n<br />\n<br />\n<br />")
    expect(round_trip('<ul><li><p></p></li></ul>')).to eq("<ul>\n<li>\n<br />\n</li>\n</ul>")
    expect(round_trip('<div><p></p></div>')).to eq("<div>\n<br />\n</div>")
  end

  # The editor removes some attributes and elements after it parses the content. A paragraph that
  # this makes empty, with no attributes, is also a line break.
  it 'writes a paragraph that the editor empties as a line break' do
    open_editor_that_keeps_scripts

    expect(round_trip('<p>a</p><p class="mce-item-x"></p><p data-mce-selected="1"></p>'))
      .to eq("<p>a</p>\n<br />\n<br />")
    expect(round_trip('<p>a</p><p><span data-mce-type="bookmark">&#xFEFF;</span></p>')).to eq("<p>a</p>\n<br />")
  end

  it 'keeps an empty paragraph that has attributes or content' do
    open_editor_that_keeps_scripts

    expect(round_trip('<p>a</p><p class="x"></p>')).to eq("<p>a</p>\n<p class=\"x\"></p>")
    expect(round_trip('<p>a</p><p>&nbsp;</p><p><br><br></p><p><span></span></p>'))
      .to eq("<p>a</p>\n<p>&nbsp;</p>\n<p><br /><br /></p>\n<p><span></span></p>")
  end

  # The rule marks each paragraph with a data-cama-paragraph attribute. A paragraph of the content
  # that has this attribute keeps its own value.
  it 'keeps a data-cama-paragraph attribute of the content' do
    open_editor_that_keeps_scripts

    expect(round_trip('<p>a</p><p data-cama-paragraph="x"></p>'))
      .to eq("<p>a</p>\n<p data-cama-paragraph=\"x\"></p>")
  end

  # Without the PostProcess event, nothing removes a mark, so the rule sets none.
  it 'leaves no mark in content that is read without events or as a tree' do
    open_editor_that_keeps_scripts

    contents = page.evaluate_script(<<~JS)
      (function () {
        var editor = tinymce.get('post_content');
        editor.setContent('<p>a</p><p></p>');
        var tree = editor.getContent({ format: 'tree' });
        return [editor.getContent({ no_events: true }), new tinymce.html.Serializer({}, editor.schema).serialize(tree)];
      })()
    JS
    expect(contents.size).to eq(2)
    contents.each do |content|
      expect(content).to include('<p>a</p>')
      expect(content).not_to include('data-cama-paragraph')
    end
  end
end
