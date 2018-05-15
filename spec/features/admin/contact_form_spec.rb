require "rails_helper"

# create a new form
def create_form
  visit "#{cama_root_relative_path}/admin/plugins/cama_contact_form/admin_forms"
  expect(page).to have_content('Contact Form')
  within("#new_plugins_cama_contact_form_cama_contact_form") do
    fill_in 'plugins_cama_contact_form_cama_contact_form_name', :with => 'Test form'
    fill_in 'plugins_cama_contact_form_cama_contact_form_slug', :with => 'test-form'
    first('button[type="submit"]').click
  end
end

describe "the Contact Form", js: true do
  init_site

  it "create new contact form" do
    admin_sign_in
    create_form
    expect(page).to have_css('.alert-success')

    # adding fields

    within '#contact_form_editor' do
      fill_in 'railscf_mail_to', :with => 'owenperedo@gmail.com'
      fill_in 'railscf_mail_subject', :with => 'test subject'

      within '#fields_available' do
        all('.btn-default').each do |l|
          l.click
        end
      end
      page.execute_script('$("#contact_form_editor").find(".required").val("sample value")')
      page.execute_script('$("#contact_form_editor").submit()')
    end
  end

  it "check contact submitters" do
    admin_sign_in
    create_form
    visit "#{cama_root_relative_path}/admin/plugins/cama_contact_form/admin_forms"
    within("#admin_content") do
      all("table .btn-info").last.click
    end
    expect(page).to have_css('#contact_form_answers')
  end

  # TODO test contact form in frontend

  it "delete contact form" do
    admin_sign_in
    create_form
    visit "#{cama_root_relative_path}/admin/plugins/cama_contact_form/admin_forms"
    within '#admin_content' do
      all("table .btn-danger").last.click
    end
    confirm_dialog
    expect(page).to have_css('.alert-success')
  end
end