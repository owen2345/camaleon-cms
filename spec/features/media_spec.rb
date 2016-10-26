require "rails_helper"
describe "the Media", js: true do
  login_success

  it "list media" do
    admin_sign_in
    visit "#{cama_root_relative_path}/admin/media"
    within '#cama_media_gallery' do
      execute_script("$('#cama_search_form .dropdown-toggle.btn').click()")
      find('.add_folder').click
    end

    within '#add_folder_form' do
      fill_in "folder", with: "test_folder_created_by_testing"
      find('button[type="submit"]').click
      wait_for_ajax
    end
    expect(page).to have_content('test_folder_created_by_testing')

    within '#cama_media_gallery' do
      # access into inner folder
      page.execute_script("$('#cama_media_gallery .folder_item[data-key=\"test_folder_created_by_testing\"]').click()")
      wait_for_ajax
      # attach_file('cama-upload-files', Rails.root.join('config', 'system.json').to_s)

      within '#cama_media_external' do
        fill_in "remote_file", with: "http://camaleon.tuzitio.com/media/132/slider/slider-camaleon.jpg"
        find('button[type="submit"]').click
        wait_for_ajax
      end
    end

    # expect(page).to have_content('slider-camaleon.jpg')

    # delete uploaded file
    page.execute_script("$('#cama_media_gallery .file_item[data-key=\"slider_camaleon.jpg\"] .del_item').click()")
    confirm_dialog
    wait_for_ajax

    # back to root
    page.execute_script("$('#cama_media_gallery .media_folder_breadcrumb a:first').click()")
    wait_for_ajax

    # delete folder
    page.execute_script("$('#cama_media_gallery .folder_item[data-key=\"test_folder_created_by_testing\"] .del_folder').click()")
    confirm_dialog
    wait_for_ajax

  end
end