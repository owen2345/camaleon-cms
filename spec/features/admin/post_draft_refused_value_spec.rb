# frozen_string_literal: true

# The draft save of the post editor sends an XHR. A refused custom-field value answers it with the
# refusal as text and a 422. The script read that answer as a failed save and showed only "The draft
# could not be saved". This example drives the real editor as an author who is not an administrator:
# the alert shows the refusal, the post stays on the form, and the buffer stores no value.
RSpec.describe 'Post editor draft save with a refused custom-field value', :js do
  init_site

  let(:post_type) { @site.post_types.where(slug: :post).first }
  let(:new_post_path) { "#{cama_root_relative_path}/admin/post_type/#{post_type.id}/posts/new" }
  let(:refusal) { I18n.t('camaleon_cms.admin.custom_field.message.value_rejected_html', slug: 'draft_attr') }

  before do
    group = @site.custom_field_groups.create!(name: 'Draft fields', slug: '_draft-refused-fields',
                                              object_class: 'PostType_Post', objectid: post_type.id)
    group.add_manual_field({ 'name' => 'Attribute', 'slug' => 'draft_attr' }, { 'field_key' => 'field_attrs' })
    @site.user_roles.find_by(slug: 'editor')
         .set_meta("_post_type_#{@site.id}", edit: [post_type.id], create: [post_type.id])
    create(:user, role: 'editor', site: @site, username: 'draft_editor')
    admin_sign_in('draft_editor', '12345678')
  end

  it 'shows the refusal and keeps the post on the form' do
    visit new_post_path
    expect(page).to have_css('#form-post .sl-slug-edit', visible: :all)
    fill_in 'post_title', with: 'Refused draft value'
    find('.input-attr').set('data-note')
    find('.input-value').set('<script>alert(1)</script>')

    page.execute_script('App_post.save_draft_ajax(null, false)')

    expect(page).to have_css('#cama_alert_modal', text: refusal)
    expect(page).to have_no_css('#cama_custom_loading')
    expect(page).to have_current_path(new_post_path, ignore_query: true)
    buffer = CamaleonCms::Post.where(status: 'draft_child', post_parent: nil).order(:id).last
    expect(buffer).to be_present
    expect(buffer.get_field_value('draft_attr')).to be_blank
  end

  # A 422 that is not a refusal: production answers a CSRF failure of the JSON request with a JSON
  # body. The editor shows the failed save, not that body.
  it 'shows a failed save for a 422 that is not a refusal' do
    visit new_post_path
    expect(page).to have_css('#form-post .sl-slug-edit', visible: :all)
    fill_in 'post_title', with: 'Forged draft'
    allow_any_instance_of(CamaleonCms::Admin::Posts::DraftsController)
      .to receive(:post_params_refusals).and_raise(ActionController::InvalidAuthenticityToken)

    with_production_error_pages do
      page.execute_script('App_post.save_draft_ajax(null, false)')

      expect(page).to have_css('#cama_alert_modal', text: 'The draft could not be saved')
    end
    expect(page).to have_no_css('#cama_alert_modal', text: 'Unprocessable')
  end
end
