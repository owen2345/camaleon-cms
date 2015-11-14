describe "the Media", js: true do
  login_success

  it "list media" do
    admin_sign_in
    visit "#{cama_root_path}/admin/media"

    expect(page).to have_css('.filemanager')
  end
end