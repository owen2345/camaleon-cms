describe "the Custom Fields", js: true do
  login_success

  it "Custom fields list" do
    admin_sign_in
    visit "#{cama_root_path}/admin/settings/custom_fields"
    within '#admin_content' do
      click_link "Add Field Group"
    end

    # new custom field
    within '#new_custom_field_group' do
      fill_in "custom_field_group_name", with: 'Test name'
      fill_in "custom_field_group_description", with: 'Test name description'
      find('#select_assign_group').find("option[value='PostType_Post,2']").click
      click_link 'item-text_box'
      click_link 'item-text_area'
      wait_for_ajax
      within '#sortable-fields' do
        expect(page).to have_content('Untitled Text Box')
        expect(page).to have_content('Untitled Text Area')
      end
      click_button "Submit"
    end
    expect(page).to have_css('.alert-success')
    within '#sortable-fields' do
      expect(page).to have_content('Untitled Text Box')
      expect(page).to have_content('Untitled Text Area')
    end

    # update
    within '#edit_custom_field_group' do
      fill_in "custom_field_group_name", with: 'Test updated'
      click_button "Submit"
    end
    within '#sortable-fields' do
      expect(page).to have_content('Untitled Text Box')
    end
    expect(page).to have_css('.alert-success')
    expect(page).to have_content('Test updated')
  end

  it "delete custom field" do
    admin_sign_in
    visit "#{cama_root_path}/admin/settings/custom_fields"
    within '#admin_content' do
      all("table .btn-danger").last.click
    end
    page.driver.browser.switch_to.alert.accept
    expect(page).to have_css('.alert-success')
  end

end