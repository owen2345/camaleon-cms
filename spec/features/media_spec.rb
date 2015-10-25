describe "the Media", js: true do
  login_success

  it "list media" do
    admin_sign_in
    visit '/admin/media'

    expect(page).to have_css('#elfinder')
  end
end