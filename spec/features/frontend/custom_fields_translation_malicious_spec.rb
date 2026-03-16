# frozen_string_literal: true

require 'rails_helper'

describe 'Custom field translation (malicious payloads)', :js do
  init_site

  let(:field_slug) { 'secure_checkbox' }
  let(:post_type_slug) { 'rce_secure_fields' }

  before do
    secure_post_type = @site.post_types.create!(
      name: 'RCE Secure Fields',
      slug: post_type_slug,
      description: 'Isolated post type for i18n rendering regression checks'
    )
    @secure_post = secure_post_type
                   .add_post(title: 'RCE Payload Post', slug: 'rce-payload-post', content: 'malicious content')

    @secure_post.add_field(
      { 'name' => 'Secure Checkbox', 'slug' => field_slug },
      { 'field_key' => 'checkbox', 'translate' => false }
    )
    @secure_post.set_field_value(field_slug, 'checked')
  end

  it 'renders full malicious payload literally and does not execute Ruby code' do
    payload = "t(Kernel.system('echo pwned'))"
    @secure_post.get_field_object(field_slug).update!(name: payload)

    expect(Kernel).not_to receive(:system)

    visit @secure_post.the_url(as_path: true)

    expect(find('.field-box strong').text).to eq(payload)
  end

  it 'renders full malformed payload literally' do
    payload = "t(admin.my_text, default: 'fallback')"
    @secure_post.get_field_object(field_slug).update!(name: payload)

    visit @secure_post.the_url(as_path: true)

    expect(find('.field-box strong').text).to eq(payload)
  end
end
