describe "the Shortcodes", js: true do
  login_success

  it "Shortcodes list" do
    admin_sign_in
    visit '/admin/settings/shortcodes'
    expect(page).to have_content('Short Code')
  end

end