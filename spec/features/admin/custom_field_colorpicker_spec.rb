# frozen_string_literal: true

# The colorpicker custom field re-renders its saved value by stamping it on the widget's
# data-color attribute and initialising the picker. jQuery coerces a numeric-looking attribute
# to a Number when the widget reads it back, and the picker's colour parser takes only strings -
# so a saved free-text value like "2" crashed the picker's constructor mid-render, taking the
# rest of the form's custom fields down with it. The examples pin the picker, its value, the
# fields rendered after it, and the whole class of values jQuery coerces.
describe 'the colorpicker custom field', :js do
  init_site

  # The text field after the colorpicker pins the blast radius: the old crash aborted the
  # rendering of every custom field after the broken one.
  before do
    @post.add_field({ 'name' => 'Tint', 'slug' => 'tint' }, { 'field_key' => 'colorpicker' })
    @post.add_field({ 'name' => 'Caption', 'slug' => 'caption' }, { 'field_key' => 'text_box' })
    @post.set_field_value('caption', 'after the picker')
  end

  def visit_post_edit
    admin_sign_in
    visit "#{cama_root_relative_path}/admin/post_type/#{@post.post_type.id}/posts/#{@post.id}/edit"
  end

  def initialised_picker_count
    page.evaluate_script(<<~JS)
      jQuery('.my-colorpicker').filter(function(){ return !!jQuery(this).data('colorpicker'); }).length
    JS
  end

  def caption_field_value
    page.evaluate_script("jQuery('.c-field-text_box .input-value').val()")
  end

  it 'renders the picker, its value and the fields after it despite a non-colour value' do
    @post.set_field_value('tint', '2')
    visit_post_edit

    expect(page).to have_css('.my-colorpicker', count: 1)
    expect(initialised_picker_count).to eq(1)
    expect(page.find('.my-colorpicker input').value).to eq('2')
    expect(caption_field_value).to eq('after the picker')
  end

  it 'renders a valid stored colour on the swatch' do
    @post.set_field_value('tint', '#00ff00')
    visit_post_edit

    expect(page).to have_css('.my-colorpicker', count: 1)
    expect(initialised_picker_count).to eq(1)
    expect(page.find('.my-colorpicker input').value).to eq('#00ff00')
    expect(page.evaluate_script("jQuery('.my-colorpicker i')[0].style.backgroundColor")).to eq('rgb(0, 255, 0)')
  end

  # Everything jQuery's data() coerces to a non-string crashed identically: numbers, booleans,
  # null, and JSON objects/arrays.
  ['true', 'null', '{"a":1}'].each do |stored|
    it "still initialises when the stored value is #{stored.inspect}" do
      @post.set_field_value('tint', stored)
      visit_post_edit

      expect(page).to have_css('.my-colorpicker', count: 1)
      expect(initialised_picker_count).to eq(1)
      expect(caption_field_value).to eq('after the picker')
    end
  end
end
