# frozen_string_literal: true

require 'rails_helper'

describe 'Posts workflows for Admin', js: true do
  let(:post) { site.the_post('sample-post').decorate }
  let(:post_type_id) { site.post_types.where(slug: :post).pick(:id) }
  let!(:site) { create(:site).decorate }

  it 'Creates a new post' do
    admin_sign_in
    visit "#{cama_root_relative_path}/admin/post_type/#{post_type_id}/posts/new"
    wait(2)

    within('#form-post') do
      fill_in 'post_title', with: 'Test Title'
      page.execute_script('$("#form-post .tinymce_textarea").tinymce().setContent("Pants are pretty sweet.")')
      page.execute_script('$("#form-post input[name=\'categories[]\']:first").prop("checked", true)')
      wait(2)

      fill_in 'post_summary', with: 'test summary'
      page.execute_script('$(\'#form-post input[name="tags"]\').val(\'owen,dota\')')
    end
    click_button 'Create'
    expect(page).to have_css('.alert-success')

    created_post = CamaleonCms::Post.last.decorate

    # visit page in frontend
    visit created_post.the_url
    expect(page).to have_content('Pants are pretty sweet.')
  end

  it 'Can edit and update a post' do
    admin_sign_in
    visit "#{cama_root_relative_path}/admin/post_type/#{post_type_id}/posts/#{post.id}/edit"
    wait(2)

    within('#form-post') do
      fill_in 'post_title', with: 'Test Title changed'
      page.execute_script('$("#form-post .tinymce_textarea").tinymce().setContent("Pants are pretty sweet. chaged")')
      fill_in 'post_summary', with: 'test summary changed'
    end
    click_button 'Update'
    expect(page).to have_css('.alert-success')

    # visit page in frontend
    visit post.the_url(as_path: true)
    expect(page).to have_content('Test Title changed')
  end

  describe 'when visibility post plugin is enabled' do
    it 'correctly fetches the assets' do
      plugin_install('visibility_post')
      admin_sign_in
      visit "#{cama_root_relative_path}/admin/post_type/#{post_type_id}/posts/new"
      wait(2)

      within('#form-post') do
        within('#published_from') do
          find('span.glyphicon.glyphicon-calendar')
        end

        expect(webfont_icon_fetch_status('glyphicon glyphicon-calendar', 'glyphicons-halflings', 'woff2')).to be(200)
      end
    end
  end
end
