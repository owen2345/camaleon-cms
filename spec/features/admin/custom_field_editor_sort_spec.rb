# frozen_string_literal: true

# A text editor does not survive a move of its panel in the page. For this reason, a sortable of the
# custom fields removes the text editors of the dragged item, and sets them up again at the drop. A
# plugin can put its own element between the panel of a text editor and the field. An example is a
# plugin that adds its own editor for the field.
RSpec.describe 'the text editors of custom fields that the admin sorts', :js do
  init_site

  let(:group) do
    @site.custom_field_groups.create!(name: 'Sections', slug: '_sections', object_class: 'Site', objectid: @site.id,
                                      is_repeat: true)
  end
  let(:field_options) { { 'field_key' => 'editor' } }
  # The scripts of the first editor field of the group and of its text editor.
  let(:field) { "jQuery('#custom_field_group_#{group.id} textarea.input-value').first()" }
  let(:text_editor) { "tinymce.get(#{field}.attr('id'))" }

  before do
    group.add_manual_field({ 'name' => 'Body', 'slug' => 'section_body' }, field_options)
    admin_sign_in
    visit "#{cama_root_relative_path}/admin/settings/site?tab=other_config"
    wait_for_the_text_editors
    page.execute_script(<<~JS)
      var editor = window.__cama_first_editor = #{text_editor};
      editor.setContent('<p>written before the drag</p>');
    JS
  end

  def wait_for_the_text_editors
    expect(page).to have_css("#custom_field_group_#{group.id} .mce-tinymce")
    Timeout.timeout(Capybara.default_max_wait_time) do
      sleep 0.05 until page.evaluate_script(<<~JS)
        !!#{text_editor} && jQuery.grep(tinymce.editors, function(editor){
          return !editor.initialized;
        }).length === 0
      JS
    end
  end

  def text_editor_ids
    page.evaluate_script('jQuery.map(tinymce.editors, function(editor){ return editor.id; })')
  end

  def put_a_plugin_element_before_the_field
    page.execute_script("jQuery('<div id=\"plugin_panel\">a plugin</div>').insertBefore(#{field});")
  end

  # Runs the events of the sortable for a drag of its first item, because a mouse drag in the browser
  # of the spec is not reliable. Between the two events, it moves the item to the end of the sortable,
  # as a drop does. `sortable` is the selector of the sortable, and `items` is the selector of its items.
  def drag_and_drop_the_first_item(sortable, items)
    page.execute_script(<<~JS, sortable, items)
      var sortable = jQuery(arguments[0]);
      var ui = {item: sortable.children(arguments[1]).first()};
      sortable.sortable('option', 'start').call(sortable[0], {}, ui);
      ui.item.appendTo(sortable);
      sortable.sortable('option', 'stop').call(sortable[0], {}, ui);
    JS
    wait_for_the_text_editors
  end

  # A move loads the frame of a text editor again. The text editor works only when its document is the
  # document of its frame.
  def expect_the_text_editor_set_up_again(editors)
    expect(text_editor_ids).to match_array(editors)
    expect(page.evaluate_script("#{text_editor} !== window.__cama_first_editor")).to be(true)
    expect(page.evaluate_script("#{text_editor}.getDoc() === #{text_editor}.iframeElement.contentDocument"))
      .to be(true)
    expect(page.evaluate_script("#{text_editor}.getContent()")).to eq('<p>written before the drag</p>')
  end

  context 'with a repeatable group' do
    let(:sortable) { "#custom_field_group_#{group.id} > .panel-body" }

    it 'sets up the text editor of a dragged instance again, with its content' do
      editors = text_editor_ids
      drag_and_drop_the_first_item(sortable, '.custom_sortable_grouped')

      expect_the_text_editor_set_up_again(editors)
    end

    it 'finds the field of a text editor when a plugin element is between the panel and the field' do
      put_a_plugin_element_before_the_field
      editors = text_editor_ids
      drag_and_drop_the_first_item(sortable, '.custom_sortable_grouped')

      expect_the_text_editor_set_up_again(editors)
    end
  end

  context 'with a field that takes more than one value' do
    let(:field_options) { { 'field_key' => 'editor', 'multiple' => true } }
    let(:sortable) { "#custom_field_group_#{group.id} .cama_w_custom_fields" }

    it 'sets up the text editor of a dragged value again, with its content' do
      editors = text_editor_ids
      drag_and_drop_the_first_item(sortable, '.editor-custom-fields')

      expect_the_text_editor_set_up_again(editors)
    end

    it 'finds the field of a text editor when a plugin element is between the panel and the field' do
      put_a_plugin_element_before_the_field
      editors = text_editor_ids
      drag_and_drop_the_first_item(sortable, '.editor-custom-fields')

      expect_the_text_editor_set_up_again(editors)
    end

    # TinyMCE keeps the settings of the last tinymce.init for the page. On the post page, that is the
    # init of the post content editor, which comes after the custom fields.
    it 'sets up the text editor of a dragged value again with its own settings' do
      page.execute_script(<<~JS)
        jQuery('<textarea id="later_editor"></textarea>').appendTo('body');
        tinymce.init(cama_get_tinymce_settings({ selector: '#later_editor', height: '480px' }));
      JS
      wait_for_the_text_editors
      editors = text_editor_ids
      drag_and_drop_the_first_item(sortable, '.editor-custom-fields')

      expect_the_text_editor_set_up_again(editors)
      expect(page.evaluate_script("String(#{text_editor}.settings.height)")).to eq('120')
    end
  end
end
