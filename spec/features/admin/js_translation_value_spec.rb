# frozen_string_literal: true

# The I18n function of the admin JavaScript puts the values of its third argument into a
# translation. It gave each value to the replace method of JavaScript as a replacement String, where
# a pattern such as $& has a meaning. It also replaced one placeholder after the other, so a value
# that holds the text of a later placeholder changed too. The function must read a value as text.
RSpec.describe 'the values of a translation in the admin JavaScript', :js do
  init_site

  before do
    admin_sign_in
    visit "#{cama_root_relative_path}/admin/dashboard"
  end

  # A placeholder has the form of a percent sign and a name in braces.
  def placeholder(name)
    "%{#{name}}"
  end

  def translation(template, data)
    page.evaluate_script("I18n('no.such.key', #{template.to_json}, #{data.to_json})")
  end

  it 'keeps a replacement pattern of a value as it is' do
    expect(translation("a #{placeholder(:x)} b", { x: "$& $' $$ $`" })).to eq("a $& $' $$ $` b")
  end

  it 'keeps a placeholder that a value holds' do
    template = "a #{placeholder(:x)} b #{placeholder(:y)}"

    expect(translation(template, { x: placeholder(:y), y: 'Y' })).to eq("a #{placeholder(:y)} b Y")
  end

  it 'keeps a placeholder with no value, and reads a number' do
    template = "#{placeholder(:width)} of #{placeholder(:total)}"

    expect(translation(template, { width: 3 })).to eq("3 of #{placeholder(:total)}")
  end

  it 'gives its value to each occurrence of a placeholder' do
    template = "#{placeholder(:x)} and #{placeholder(:x)}"

    expect(translation(template, { x: 'X' })).to eq('X and X')
  end

  it 'returns a translation or a default value that is not a String as it is' do
    page.execute_script("I18n_data.months = ['Jan', 'Feb']")

    expect(page.evaluate_script("I18n('months')")).to eq(%w[Jan Feb])
    expect(page.evaluate_script("I18n('no.such.key', 5)")).to eq(5)
  end
end
