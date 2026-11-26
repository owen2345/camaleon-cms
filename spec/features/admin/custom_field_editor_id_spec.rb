# frozen_string_literal: true

# TinyMCE finds the field of a text editor by its id. Camaleon gives each new editor field a random id,
# and that id can be the id of another element of the page.
RSpec.describe 'the id of a new text editor field of a custom field', :js do
  init_site

  let(:group) do
    @site.custom_field_groups.create!(name: 'Sections', slug: '_sections', object_class: 'Site', objectid: @site.id,
                                      is_repeat: true)
  end
  let(:fields) { "jQuery('#custom_field_group_#{group.id} textarea.input-value')" }

  before do
    group.add_manual_field({ 'name' => 'Body', 'slug' => 'section_body' }, { 'field_key' => 'editor' })
    admin_sign_in
    visit "#{cama_root_relative_path}/admin/settings/site?tab=other_config"
  end

  it 'is an id that no other element of the page has' do
    expect(page).to have_css("#custom_field_group_#{group.id} .mce-tinymce", count: 1)
    # For custom_field_editor, the first random number gives the id of the field on the page, and the
    # second one gives a free id. Other scripts of the page also take random numbers, and they get real ones.
    page.execute_script(<<~JS)
      var number = parseInt(#{fields}.first().attr('id').split('_')[1], 10);
      var numbers = window.__cama_random_numbers = [(number - 0.5) / 100000, (number % 100000 + 0.5) / 100000];
      var random = Math.random;
      Math.random = function(){
        var editor_field = new Error().stack.indexOf('custom_field_editor') !== -1;
        return editor_field && numbers.length ? numbers.shift() : random();
      };
      jQuery('#custom_field_group_#{group.id} .duplicate_cutom_group').click();
      Math.random = random;
    JS

    expect(page).to have_css("#custom_field_group_#{group.id} .mce-tinymce", count: 2)
    expect(page.evaluate_script('window.__cama_random_numbers.length')).to eq(0)
    expect(page.evaluate_script("jQuery.map(#{fields}, function(field){ return field.id; })").uniq.size).to eq(2)
    expect(page.evaluate_script(<<~JS)).to be(true)
      #{fields}.toArray().every(function(field){
        var editor = tinymce.get(field.id);
        return !!editor && editor.getElement() === field;
      })
    JS
  end
end
