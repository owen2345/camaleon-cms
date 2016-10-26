require "rails_helper"
describe "the Languages", js: true do
  login_success

  it "Languages list" do
    admin_sign_in
    visit "#{cama_root_relative_path}/admin/settings/languages"
    expect(page).to have_content("Languages configuration")

    within '#languages_form' do
      page.execute_script('$("#languages_form [name=\'lang[]\']").filter("[value=\'fr\']").click()')
      page.execute_script('$("#languages_form [name=\'admin_language\']").filter("[value=\'es\']").click()')
      click_button "Submit"
    end

    expect(page).to have_css('.alert-success')
    within '#languages_form' do
      expect(page).to have_checked_field("Inglés")
      expect(page).to have_checked_field("Español")
      expect(page).to have_checked_field("Francés")
      page.execute_script('$("#languages_form [name=\'lang[]\']").filter("[value=\'es\']").click()')
      page.execute_script('$("#languages_form [name=\'admin_language\']").filter("[value=\'en\']").click()')
      click_button "Enviar"
    end
    page.execute_script('$("#languages_form [name=\'admin_language\']").filter("[value=\'es\']").click()')
    expect(page).to have_css('.alert-success')

    # Revert to single language and english backend
    within '#languages_form' do
      page.execute_script('$("#languages_form [name=\'lang[]\']").filter("[value=\'fr\']").prop("checked", false)')
      page.execute_script('$("#languages_form [name=\'lang[]\']").filter("[value=\'es\']").prop("checked", false)')
      page.execute_script('$("#languages_form [name=\'admin_language\']").filter("[value=\'en\']").click()')
      click_button "Submit"
    end
    expect(page).to have_css('.alert-success')
  end
end