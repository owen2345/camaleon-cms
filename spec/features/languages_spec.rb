describe "the Languages", js: true do
  login_success

  it "Languages list" do
    admin_sign_in
    visit "#{cama_root_path}/admin/settings/languages"
    expect(page).to have_content("Languages configuration")

    # create user role
    within '#languages_form' do
      page.execute_script('$("[name=\'lang[]\']").filter("[value=\'fr\']").click()')
      page.execute_script('$("[name=\'admin_language\']").filter("[value=\'es\']").click()')
      click_button "Submit"
    end
    expect(page).to have_css('.alert-success')
    within '#languages_form' do
      expect(page).to have_checked_field("Inglés")
      expect(page).to have_checked_field("Español")
      expect(page).to have_checked_field("Francés")
      page.execute_script('$("[name=\'lang[]\']").filter("[value=\'es\']").click()')
      page.execute_script('$("[name=\'admin_language\']").filter("[value=\'en\']").click()')
      click_button "Enviar"
    end
    expect(page).to have_css('.alert-success')
  end
end