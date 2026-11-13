# frozen_string_literal: true

# The Front Cache settings page gives the name of each post type to bootstrap-select as the label of
# an option group. The library put each label into HTML. A role with the settings permission can
# store the name of a post type. A name with markup then ran its event handler in the session of the
# admin who opened the page. The list must show a label as text.
RSpec.describe 'the post lists of the Front Cache settings page', :js do
  init_site

  let(:name) { '<img src=q onerror="return">' }

  before do
    @post.post_type.update!(name: name)
    admin_sign_in
    visit "#{cama_root_relative_path}/admin/plugins/front_cache/settings"
  end

  it 'shows the name of a post type as text in the label of its option group' do
    expect(page).to have_css('.bootstrap-select .dropdown-header .text', exact_text: name, visible: :all)
    expect(page).to have_no_css('.bootstrap-select img', visible: :all)
  end
end
