# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Frontend custom field translations (non-browser)', type: :request do
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
                   .add_post(title: 'RCE Request Post', slug: 'rce-request-post', content: 'request content')

    @secure_post.add_field(
      { 'name' => 'Secure Checkbox', 'slug' => field_slug }, { 'field_key' => 'checkbox', 'translate' => false }
    )
    @secure_post.set_field_value(field_slug, 'checked')
  end

  def rendered_label
    Nokogiri::HTML(response.body).at_css('.field-box strong').text
  end

  def fetch_post
    get @secure_post.the_url(as_path: true), headers: { 'HTTP_HOST' => @site.slug }
  end

  it 'renders translated labels for safe t(...) values' do
    @secure_post.get_field_object(field_slug).update!(name: 't(admin.my_text)')

    fetch_post

    expect(response).to have_http_status(:ok)
    expect(rendered_label).to eq('My Text')
  end

  it 'renders full malicious payload literally and does not execute Ruby code' do
    payload = "t(Kernel.system('echo pwned'))"
    @secure_post.get_field_object(field_slug).update!(name: payload)

    expect(Kernel).not_to receive(:system)

    fetch_post

    expect(response).to have_http_status(:ok)
    expect(rendered_label).to eq(payload)
  end
end
