# frozen_string_literal: true

# A part of a multipart request can name a charset (Content-Type: text/plain; charset=UTF-16LE). For
# a charset that is not ASCII-compatible, the param parser of Rack raises an encoding error. Before,
# the server answered with a 500. CamaleonCms::MultipartEncodingGuard answers with a 400, and no
# controller action starts.
RSpec.describe CamaleonCms::MultipartEncodingGuard, type: :request do
  init_site

  let(:current_site) { Cama::Site.first.decorate }
  let(:admin) { create(:user, role: 'admin', site: current_site) }
  let(:post_type) { current_site.post_types.where(slug: 'post').first }
  let(:category) { post_type.categories.create!(name: 'Kept name', slug: 'kept-name') }
  let(:boundary) { 'AaB03x' }

  before do
    allow_any_instance_of(CamaleonCms::AdminController).to receive(:current_site).and_return(current_site)
    group = CamaleonCms::CustomFieldGroup.create!(name: 'Category fields', slug: 'category-fields',
                                                  object_class: 'PostType_Category', objectid: post_type.id,
                                                  site: current_site)
    group.add_manual_field({ 'name' => 'Subtitle', 'slug' => 'subtitle' }, { 'field_key' => 'text_box' })
    category.set_field_value('subtitle', 'kept')
    sign_in_as(admin, site: current_site)
  end

  # Each part is a name, a value and an optional charset.
  def multipart_body(parts)
    parts.map do |name, value, charset|
      type = charset ? "Content-Type: text/plain; charset=#{charset}\r\n" : ''
      "--#{boundary}\r\nContent-Disposition: form-data; name=\"#{name}\"\r\n#{type}\r\n#{value}\r\n".b
    end.join << "--#{boundary}--\r\n".b
  end

  def send_multipart(verb, path, parts)
    public_send(verb, path, params: multipart_body(parts),
                            headers: { 'CONTENT_TYPE' => "multipart/form-data; boundary=#{boundary}" })
  end

  def category_parts(charset)
    [['category[name]', 'New name'],
     ['field_options[0][subtitle][group_number]', '0', charset],
     ['field_options[0][subtitle][values][0]', 'new']]
  end

  def expect_bad_request
    expect(response).to have_http_status(:bad_request)
    expect(response.body).to eq('Bad Request')
    expect(category.reload.name).to eq('Kept name')
    expect(category.get_field_values('subtitle')).to eq(['kept'])
  end

  %w[UTF-16LE UTF-16BE UTF-16 UTF-32LE UTF-7].each do |charset|
    it "answers a POST that holds a part in #{charset} with a 400 and stores no category" do
      send_multipart(:post, "/admin/post_type/#{post_type.id}/categories",
                     [['category[name]', 'Made by hand'], ['category[slug]', 'made-by-hand', charset]])

      expect(response).to have_http_status(:bad_request)
      expect(post_type.categories.find_by(name: 'Made by hand')).to be_nil
    end
  end

  it 'answers a POST with _method=patch with a 400, and the stored values stay' do
    send_multipart(:post, "/admin/post_type/#{post_type.id}/categories/#{category.id}",
                   [%w[_method patch]] + category_parts('UTF-16LE'))

    expect_bad_request
  end

  it 'answers a PATCH with a 400, and the stored values stay' do
    send_multipart(:patch, "/admin/post_type/#{post_type.id}/categories/#{category.id}", category_parts('UTF-16LE'))

    expect_bad_request
  end

  # Rack converts a part in ISO-2022-JP to UTF-8, which raises an encoding error for invalid bytes.
  it 'answers a part with invalid ISO-2022-JP bytes with a 400' do
    send_multipart(:patch, "/admin/post_type/#{post_type.id}/categories/#{category.id}",
                   [['category[name]', "abc\xFF".b, 'ISO-2022-JP']])

    expect_bad_request
  end

  it 'saves a multipart request whose parts are in an ASCII-compatible charset' do
    send_multipart(:patch, "/admin/post_type/#{post_type.id}/categories/#{category.id}", category_parts('ISO-8859-1'))

    expect(response).to have_http_status(:found)
    expect(category.reload.name).to eq('New name')
    expect(category.get_field_values('subtitle')).to eq(['new'])
  end

  # The guard must come before Rack::MethodOverride, which parses the params of a POST. Camaleon
  # inserts it after ActionDispatch::Executor, because an API-only host has no Rack::MethodOverride.
  it 'sits after ActionDispatch::Executor and before Rack::MethodOverride in the middleware stack' do
    stack = Rails.application.middleware.map(&:klass)

    expect(stack.index(described_class)).to eq(stack.index(ActionDispatch::Executor) + 1)
    expect(stack.index(described_class)).to be < stack.index(Rack::MethodOverride)
  end
end
