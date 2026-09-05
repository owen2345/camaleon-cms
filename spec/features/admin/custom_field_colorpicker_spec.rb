# frozen_string_literal: true

# The colorpicker custom field re-renders its saved value by stamping it on the widget's
# data-color attribute and initialising the picker. jQuery coerces a numeric-looking attribute
# to a Number when the widget reads it back, and the picker's colour parser takes only strings -
# so a saved free-text value like "2" crashed the picker's constructor mid-render, taking the
# rest of the form's custom fields down with it.
describe 'the colorpicker custom field', :js do
  init_site

  before do
    @post.add_field({ 'name' => 'Tint', 'slug' => 'tint' }, { 'field_key' => 'colorpicker' })
    @post.set_field_value('tint', '2')
  end

  def visit_post_edit
    admin_sign_in
    visit "#{cama_root_relative_path}/admin/post_type/#{@post.post_type.id}/posts/#{@post.id}/edit"
  end

  it 'initialises the picker even when the saved value is not a colour string' do
    visit_post_edit

    expect(page).to have_css('.my-colorpicker')
    initialised = page.evaluate_script(<<~JS)
      jQuery('.my-colorpicker').toArray().every(function(el){
        return !!jQuery(el).data('colorpicker');
      })
    JS
    expect(initialised).to be(true)
  end
end
