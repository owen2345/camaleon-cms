describe "the Contact Form", js: true do
  login_success

  it "create new contact form" do
    admin_sign_in
    visit "#{cama_root_path}/admin/plugins/contact_form/admin_forms"
    expect(page).to have_content('Contact Form')
    within("#new_plugins_contact_form_models_contact_form") do
      fill_in 'plugins_contact_form_models_contact_form_name', :with => 'Test form'
      fill_in 'plugins_contact_form_models_contact_form_slug', :with => 'test-form'
      click_button 'Submit'
    end

    # adding fields
    expect(page).to have_css('.alert-success')
    within '#contact_form_editor' do
      fill_in 'railscf_mail_to', :with => 'owenperedo@gmail.com'
      fill_in 'railscf_mail_subject', :with => 'test subject'
    end

    within '#addField' do
      all('.btn-default').first.click
    end

    within '.fb-response-fields' do
      expect(page).to have_content('Untitled')
    end
    click_button 'Submit'
  end

  it "check contact submitters" do
    admin_sign_in
    visit "#{cama_root_path}/admin/plugins/contact_form/admin_forms"
    within("#admin_content") do
      all("table .btn-info").last.click
    end
    expect(page).to have_css('#contact_form_answers')
  end

  # TODO test contact form in frontend

  it "delete content type" do
    admin_sign_in
    visit "#{cama_root_path}/admin/plugins/contact_form/admin_forms"
    within '#admin_content' do
      all("table .btn-danger").last.click
    end
    page.driver.browser.switch_to.alert.accept
    expect(page).to have_css('.alert-success')
  end

end