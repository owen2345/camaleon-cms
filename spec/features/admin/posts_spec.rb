# frozen_string_literal: true

require 'rails_helper'

describe 'Posts workflows for Admin', :js do
  let(:post) { site.the_post('sample-post').decorate }
  let(:post_type_id) { site.post_types.where(slug: :post).pick(:id) }
  let!(:site) { CamaleonCms::Site.first.decorate }

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
    visit created_post.the_url(as_path: true)
    expect(page).to have_text('Pants are pretty sweet.')
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
    expect(page).to have_text('Test Title changed')
  end

  # Regression: on a cold server, opening the edit form in a throttled background tab could bring up
  # TinyMCE empty even though the server rendered the post content -- the field's live value was
  # blanked before TinyMCE read it (surfaced by the PluginRoutes reload changes in #1163). The init
  # guard in cama_get_tinymce_settings restores the server value (textarea.defaultValue) when the
  # editor comes up empty. The throttling race is not reproducible headlessly, so this drives the
  # exact state it produces -- empty live value, server value still in defaultValue -- and asserts
  # the guard refills the editor. Without the guard the editor stays empty and this fails.
  it 'restores the server-rendered content when the editor initializes empty' do
    admin_sign_in
    visit "#{cama_root_relative_path}/admin/post_type/#{post_type_id}/posts/#{post.id}/edit"
    wait(2)

    page.execute_script(<<~JS)
      tinymce.get('post_content').remove();
      var ta = document.getElementById('post_content');
      ta.defaultValue = '<p>Cold-boot guard body</p>';
      ta.value = '';
      tinymce.init(cama_get_tinymce_settings({ selector: '#post_content' }));
    JS
    wait(2)

    within_frame('post_content_ifr') do
      expect(page).to have_text('Cold-boot guard body')
    end
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
