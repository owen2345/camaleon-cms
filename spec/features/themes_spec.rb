require "rails_helper"
describe "the Themes", js: true do
  login_success

  it "Themes list" do
    admin_sign_in
    visit "#{cama_root_relative_path}/admin/appearances/themes"
    expect(page).to have_css('#themes_page')
    within "#themes_page" do
      first('.preview_link').click
    end
    # wait_for_ajax
    # page.within_frame '#ow_inline_modal_iframe' do
    #   page.should have_selector 'body'
    # end
  end

end