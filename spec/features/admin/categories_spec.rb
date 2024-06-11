# frozen_string_literal: true

require 'rails_helper'

describe 'the signin process', :js do
  init_site

  it 'create new category' do
    admin_sign_in
    post_type_id = @site.post_types.where(slug: :page).pick(:id)
    visit "#{cama_root_relative_path}/admin/post_type/#{post_type_id}/categories"
    within('#form-category') do
      fill_in 'category_name', with: 'Test cat'
      fill_in 'category_slug', with: 'test-cat'
    end
    click_button 'Submit'

    expect(page).to have_css('.alert-success')
  end

  it 'create edit category' do
    admin_sign_in
    post_type = @site.post_types.find_by(slug: :post)
    category_id = post_type.categories.pick(:id)
    visit "#{cama_root_relative_path}/admin/post_type/#{post_type.id}/categories/#{category_id}/edit"
    within('#form-category') do
      fill_in 'category_name', with: 'Test cat update'
    end
    click_button 'Submit'

    expect(page).to have_css('.alert-success')
  end
end
