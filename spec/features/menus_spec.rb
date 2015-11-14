describe "the Menus", js: true do
  login_success

  it "Menus list" do
    admin_sign_in
    visit "#{cama_root_path}/admin/appearances/nav_menus/menu"
    expect(page).to have_css('#menu_content')
    wait(1)
    within "#menu_items" do
      # post menus
      check("Sample Post")
      page.execute_script('$("#acc-post .nav-tabs li").eq(1).find("a").click()')
      check("Uncategorized")
      click_button "Add to Menu"

      # custom links
      all(".panel-collapse").last.click
      wait(1)
      within ".form-custom-link" do
        fill_in "external_label", with: "name link"
        fill_in "external_url", with: "http://mytest.com"
        click_button "Add to Menu"
      end
    end

    # verificarion
    within '#menu_form' do
      expect(page).to have_content("Sample Post")
      expect(page).to have_content("Uncategorized")
      expect(page).to have_content("name link")
      click_button "Update Menu"
    end
    wait_for_ajax
    expect(page).to have_css('.alert-success')

    # verification after refresh
    # page.driver.navigate.refresh
    visit(current_path)
    within '#menu_form' do
      expect(page).to have_content("Sample Post")
      expect(page).to have_content("Uncategorized")
      expect(page).to have_content("name link")
    end
  end

  it "Menus Create and Delete" do
    admin_sign_in
    visit "#{cama_root_path}/admin/appearances/nav_menus/menu"
    within "#menu_items" do
      click_link "create a new menu"
    end
    expect(page).to have_css('#menu_form')
    within '#menu_form' do
      fill_in "nav_menu_name", with: "Test nav"
      fill_in "nav_menu_slug", with: "test-nav"
      click_button "Create Menu"
    end

    expect(page).to have_css(".alert-success")
    within '#menu_form' do
      click_link "Delete"
    end
    page.driver.browser.switch_to.alert.accept
    expect(page).to have_css('.alert-success')
  end

end