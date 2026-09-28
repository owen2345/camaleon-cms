# frozen_string_literal: true

# Security: the scan-and-reject gate picks a custom-field value's check from the field definition the
# stored row points at. set_field_values resolves that definition from the slug through the record's
# get_field_groups, and falls back to the request's field id when that misses. For a user, a widget
# assignment and a post type the form renders groups get_field_groups does not return, so every
# permitted slug fell back to the request's id: naming a text box's id stored an editor field's markup
# unscanned. The permitted payload now carries the id of the slug's field in the groups the form
# renders, whatever id the request names.
RSpec.describe 'Security: a forged field id cannot skip the custom-field value gate', type: :request do
  init_site

  let(:current_site) { Cama::Site.first.decorate }
  let(:script) { '<p>keep</p><script>alert(1)</script>' }
  let(:text_box) do
    current_site.custom_field_groups.create!(name: 'Plain', slug: '_plain', object_class: 'Site',
                                             objectid: current_site.id)
                .add_manual_field({ 'name' => 'Plain', 'slug' => 'plain' }, { 'field_key' => 'text_box' })
  end

  before do
    allow_any_instance_of(CamaleonCms::AdminController).to receive(:current_site).and_return(current_site)
  end

  def forged_payload(field)
    { '0' => { field.slug => { 'id' => text_box.id.to_s, 'values' => { '0' => script } } } }
  end

  it "refuses an editor value on a user's own profile saved under a text box's id" do
    member = create(:user, role: 'client', site: current_site, password: 'longenough1',
                           password_confirmation: 'longenough1')
    bio = current_site.custom_field_groups.create!(name: 'User', slug: '_user', object_class: 'User',
                                                   objectid: current_site.id)
                      .add_manual_field({ 'name' => 'Bio', 'slug' => 'bio' }, { 'field_key' => 'editor' })
    sign_in_as(member, site: current_site)

    patch "/admin/users/#{member.id}", params: {
      user: { username: member.username, email: member.email }, field_options: forged_payload(bio)
    }

    # The save reached the gate and was refused, not skipped.
    expect(flash[:error]).to include("The 'bio' field contains HTML that is not allowed")
    expect(member.reload.custom_field_values.where(custom_field_slug: 'bio')).not_to exist
  end

  it 'stores the user field under its own id, not the one the request names' do
    admin = create(:user, role: 'admin', site: current_site)
    bio = current_site.custom_field_groups.create!(name: 'User', slug: '_user', object_class: 'User',
                                                   objectid: current_site.id)
                      .add_manual_field({ 'name' => 'Bio', 'slug' => 'bio' }, { 'field_key' => 'editor' })
    sign_in_as(admin, site: current_site)

    patch "/admin/users/#{admin.id}", params: {
      user: { username: admin.username, email: admin.email }, field_options: forged_payload(bio)
    }

    expect(admin.reload.custom_field_values.where(custom_field_slug: 'bio').pluck(:custom_field_id)).to eq([bio.id])
  end
end
