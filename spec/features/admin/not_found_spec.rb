require "rails_helper"
describe "no found", js: true do
  init_site

  it "404s" do
    admin_sign_in
    visit "#{cama_root_relative_path}/admin/nothing-here"
    expect(page).to have_content('Invalid route')
  end
end
