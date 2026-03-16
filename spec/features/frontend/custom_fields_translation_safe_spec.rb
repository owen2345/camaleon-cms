# frozen_string_literal: true

require 'rails_helper'

describe 'Custom field translation (safe)', :js do
  init_site

  let(:field_slug) { 'secure_checkbox' }
  let(:post_type_slug) { 'rce_secure_fields' }

  before do
    I18n.backend.store_translations(:en, admin: { my_text: 'My Text' })

    secure_post_type = @site.post_types.create!(
      name: 'RCE Secure Fields',
      slug: post_type_slug,
      description: 'Isolated post type for i18n rendering regression checks'
    )
    @secure_post = secure_post_type
      .add_post(title: 'RCE Safe Translation Post', slug: 'rce-safe-translation-post', content: 'safe content')

    @secure_post.add_field(
      { 'name' => 'Secure Checkbox', 'slug' => field_slug },
      { 'field_key' => 'checkbox', 'translate' => false }
    )
    @secure_post.set_field_value(field_slug, 'checked')
  end

  it 'renders translated labels for safe t(...) values via browser visit' do
    @secure_post.get_field_object(field_slug).update!(name: 't(admin.my_text)')

    visit @secure_post.the_url(as_path: true)

    expect(find('.field-box strong').text).to eq('My Text')
  end
end
