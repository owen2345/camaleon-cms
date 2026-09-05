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

  it 'renders the fields after a radio whose option value holds a quote' do
    # The radio render callback splices its stored value into a jQuery selector; a quote used to
    # throw a selector syntax error and abort every field after it - the same cascade the
    # colorpicker fix closed, through another door.
    @post.add_field({ 'name' => 'Pick', 'slug' => 'pick' },
                    { 'field_key' => 'radio', 'multiple_options' => [{ 'title' => 'Bobs', 'value' => "Bob's pick" }] })
    @post.set_field_value('pick', "Bob's pick")
    @post.add_field({ 'name' => 'Tail', 'slug' => 'tail' }, { 'field_key' => 'text_box' })
    @post.set_field_value('tail', 'after the radio')
    visit_post_edit

    expect(page).to have_css('.my-colorpicker', count: 1)
    expect(page.evaluate_script("jQuery('[data-field-key=tail] .input-value').val()")).to eq('after the radio')
    # and the stored option is actually selected, not merely tolerated
    expect(page.evaluate_script(%(jQuery("[data-field-key=pick] input:checked").val()))).to eq("Bob's pick")
  end

  it 'checks a checkboxes option whose value holds a quote' do
    @post.add_field({ 'name' => 'Tags', 'slug' => 'tags' },
                    { 'field_key' => 'checkboxes',
                      'multiple_options' => [{ 'title' => 'Bobs', 'value' => "Bob's tag" },
                                             { 'title' => 'Plain', 'value' => 'plain' }] })
    @post.set_field_value('tags', "Bob's tag")
    visit_post_edit

    expect(page.evaluate_script(%(jQuery("[data-field-key=tags] input:checked").val()))).to eq("Bob's tag")
  end

  it 'falls back to hex when the colour format is unrecognised' do
    # data-color-format rides the same coercing data() read; an unknown format left this.format
    # undefined - surviving init (previewColor rescues) but throwing on the first close, so the
    # picked colour was never written back.
    visit_post_edit

    result = page.evaluate_script(<<~JS)
      (function(){
        var f = jQuery('<div><div class="input-group color my-colorpicker" data-color="#fff" data-color-format="123">' +
                       '<input type="text"><span class="input-group-addon"><i></i></span></div></div>');
        custom_field_colorpicker_val(f, '#00ff00');
        var picker = f.find('.my-colorpicker').data('colorpicker');
        try {
          picker.setValue('#0000ff');
          picker.hide();
        } catch(e){ return 'threw: ' + e; }
        return f.find('input').val();
      })()
    JS
    expect(result).to eq('#0000ff')
  end

  it 'renders a disabled field readonly' do
    # The render partial emits the flag as is_disabled; the JS tested field_data.disabled, so
    # the readonly branch never ran and a locked field was fully editable.
    @post.add_field({ 'name' => 'Locked', 'slug' => 'locked' }, { 'field_key' => 'text_box', 'disabled' => 'true' })
    @post.set_field_value('locked', 'frozen')
    visit_post_edit

    expect(page.evaluate_script("jQuery('[data-field-key=locked] .input-value').prop('readonly')")).to be(true)
  end

  it 'warns when a render callback breaks instead of dying silently' do
    visit_post_edit

    warned = page.evaluate_script(<<~JS)
      (function(){
        var warns = [];
        var original = console.warn;
        console.warn = function(){ warns.push(String(arguments[0])); };
        window.cama_broken_callback = function(){ throw new Error('boom'); };
        var panel = jQuery('<div><div class="group-input-fields-content" data-callback-render="cama_broken_callback">' +
                           '<input class="input-value" name="x[values][]"></div></div>');
        try {
          cama_build_custom_field(panel, { kind: 'text_box', default_value: '' }, ['v']);
        } catch(e){ console.warn = original; return 'threw: ' + e; }
        console.warn = original;
        return warns.length > 0;
      })()
    JS
    expect(warned).to be(true)
  end

  it 'tolerates coercible or missing data-color through the plain initialiser too' do
    # custom_field_colorpicker is a public global themes can name in data-callback-render; it
    # crashed on the same coercion, and harder - markup without data-color gave undefined.
    visit_post_edit

    initialised = page.evaluate_script(<<~JS)
      (function(){
        function widget(attrs){
          return jQuery('<div><div class="input-group color my-colorpicker"' + attrs +
                        '><input type="text"><span class="input-group-addon"><i></i></span></div></div>');
        }
        var no_attr = widget('');
        var coercible = widget(' data-color="2"');
        try {
          custom_field_colorpicker(no_attr);
          custom_field_colorpicker(coercible);
        } catch(e){ return String(e); }
        return !!no_attr.find('.my-colorpicker').data('colorpicker') &&
               !!coercible.find('.my-colorpicker').data('colorpicker');
      })()
    JS
    expect(initialised).to be(true)
  end

  it 'keeps the markup default white when the field has no stored value' do
    # An empty value used to overwrite the template's data-color="#fff", and the widget's
    # no-match default is red - every unset field showed a red swatch.
    visit_post_edit

    expect(page).to have_css('.my-colorpicker', count: 1)
    expect(initialised_picker_count).to eq(1)
    expect(page.evaluate_script("jQuery('.my-colorpicker i')[0].style.backgroundColor")).to eq('rgb(255, 255, 255)')
  end

  it 'preserves a falsy-but-real value like a numeric 0 default' do
    visit_post_edit

    preserved = page.evaluate_script(<<~JS)
      (function(){
        var f = jQuery('<div><div class="input-group color my-colorpicker" data-color="#fff">' +
                       '<input type="text"><span class="input-group-addon"><i></i></span></div></div>');
        custom_field_colorpicker_val(f, 0);
        return f.find('.my-colorpicker').data('color');
      })()
    JS
    expect(preserved).to eq('0')
  end

  it 'does not overwrite the stored value when the picker is opened and closed untouched' do
    # hide() used to write the picker's formatted colour into the input unconditionally, so just
    # looking at the picker turned a stored non-colour value (or a blank) into #ff0000.
    @post.set_field_value('tint', '2')
    visit_post_edit
    expect(page).to have_css('.my-colorpicker', count: 1)

    page.find('.my-colorpicker .input-group-addon').click
    page.execute_script('jQuery(document).trigger("mousedown")')

    expect(page.find('.my-colorpicker input').value).to eq('2')
  end

  it 'still writes the colour back when one was actually picked' do
    @post.set_field_value('tint', '2')
    visit_post_edit
    expect(page).to have_css('.my-colorpicker', count: 1)

    page.execute_script(%(jQuery('.my-colorpicker').data('colorpicker').setValue('#00ff00');))
    page.find('.my-colorpicker .input-group-addon').click
    page.execute_script('jQuery(document).trigger("mousedown")')

    expect(page.find('.my-colorpicker input').value).to eq('#00ff00')
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
