# frozen_string_literal: true

# Security (audit): cama_permitted_field_options resolved the payload with `params.require` and then
# called `#keys`/`#permit` on it, so a non-hash `field_options` (a scalar `field_options=foo`, or an
# array) raised NoMethodError -> 500. Every set_field_values caller shares the helper, so the same
# malformed-request crash was reachable through each of them; the category save stands in for them.
# The helper treats a non-hash payload as empty and the save proceeds. The post save and the draft
# save are the exception: they refuse a malformed `field_options` up front, like `meta` and `options`
# (see meta_container_refusal_spec.rb).
RSpec.describe 'Security: non-hash field_options is ignored, not a 500', type: :request do
  init_site

  let(:current_site) { Cama::Site.first.decorate }
  let(:admin) { create(:user, role: 'admin', site: current_site) }
  let(:post_type) { current_site.post_types.where(slug: 'post').first }

  before do
    allow_any_instance_of(CamaleonCms::AdminController).to receive(:current_site).and_return(current_site)
    # A registered field makes the allow-list non-blank, so the helper reaches the #keys/#permit path
    # the scalar param used to crash on (an empty allow-list short-circuits to {} before that line).
    group = CamaleonCms::CustomFieldGroup.create!(name: 'Category fields', slug: 'category-fields',
                                                  object_class: 'PostType_Category', objectid: post_type.id,
                                                  site: current_site)
    group.add_manual_field({ 'name' => 'Subtitle', 'slug' => 'subtitle' }, { 'field_key' => 'text_box' })
    sign_in_as(admin, site: current_site)
  end

  it 'saves the category and writes no field values when field_options is a scalar' do
    post "/admin/post_type/#{post_type.id}/categories", params: {
      category: { name: 'Scalar fields', slug: 'scalar-fields' },
      field_options: 'foo'
    }

    expect(response).to have_http_status(:found)
    category = post_type.categories.find_by(slug: 'scalar-fields')
    expect(category).to be_present
    expect(category.custom_field_values).to be_empty
  end

  it 'saves the category when field_options is an array' do
    post "/admin/post_type/#{post_type.id}/categories", params: {
      category: { name: 'Array fields', slug: 'array-fields' },
      field_options: %w[a b]
    }

    expect(response).to have_http_status(:found)
    expect(post_type.categories.find_by(slug: 'array-fields')).to be_present
  end

  # A group or a slug entry given as a list of hashes passes the permit as an Array, which has no slug
  # or [:id] to read.
  { 'a slug entry' => { '0' => { 'subtitle' => [{ 'id' => '1', 'values' => { '0' => 'x' } }] } },
    'a group' => { '0' => [{ 'subtitle' => { 'id' => '1', 'values' => { '0' => 'x' } } }] } }.each do |shape, payload|
    it "saves the category and writes no field values when #{shape} is a list" do
      post "/admin/post_type/#{post_type.id}/categories", params: {
        category: { name: 'Listed field', slug: 'listed-field' }, field_options: payload
      }

      expect(response).to have_http_status(:found)
      category = post_type.categories.find_by(slug: 'listed-field')
      expect(category).to be_present
      expect(category.custom_field_values).to be_empty
    end
  end

  # Rails reads a group that holds a numeric key as nested attributes, so the entry under that key
  # passes the permit. The key names no field.
  it 'saves the category and keeps its field values when a group holds its fields under a numeric key' do
    category = post_type.categories.create!(name: 'Nested field', slug: 'nested-field')
    category.set_field_value('subtitle', 'kept')

    patch "/admin/post_type/#{post_type.id}/categories/#{category.id}", params: {
      category: { name: 'Renamed field', slug: 'nested-field' },
      field_options: { '0' => { '0' => { 'subtitle' => { 'id' => '1', 'values' => { '0' => 'x' } } } } }
    }

    expect(response).to have_http_status(:found)
    category.reload
    expect(category.name).to eq('Renamed field')
    expect(category.get_field_values('subtitle')).to eq(['kept'])
  end

  # Before, set_field_values took the group number from the request and only changed a negative
  # number to 0. A number above 2147483647 raised ActiveModel::RangeError at the save, and a JSON
  # boolean raised NoMethodError. Each one was a 500. Now a custom-field value with such a group number
  # is not valid, and the admin gets the error of the group number in a flash message.
  #
  # Before, the permit helper kept a group number only when it was a scalar. Rails dropped a list or a
  # hash, and set_field_values stored the value in group 0 with no error. Now the permit helper keeps
  # a list or a hash, with its content removed, so the admin gets the same error.
  describe 'a group number that is not an integer from 0 to 2147483647' do
    let(:category) { post_type.categories.create!(name: 'Grouped field', slug: 'grouped-field') }
    let(:refusal) do
      I18n.t('camaleon_cms.admin.custom_field.message.group_number_invalid', slug: 'subtitle', max: 2_147_483_647)
    end

    before { category.set_field_value('subtitle', 'kept') }

    def expect_refusal
      expect(response).to have_http_status(:found)
      expect(flash[:error]).to include(refusal)
      expect(category.reload.get_field_values('subtitle')).to eq(['kept'])
    end

    def update_category(group_number, **options)
      patch "/admin/post_type/#{post_type.id}/categories/#{category.id}", params: {
        category: { name: 'Grouped field' },
        field_options: { '0' => { 'subtitle' => { 'group_number' => group_number, 'values' => { '0' => 'x' } } } }
      }, **options
    end

    { 'above the range of each database' => '99999999999999999999',
      'above the range of a 4-byte column' => '2147483648',
      'negative' => '-1',
      'not a number' => 'abc',
      'a number with text after it' => '0abc',
      'a text of 17 digits' => '00000000000000000',
      'a list' => ['5'],
      'a hash' => { 'a' => '5' },
      'a hash of hashes with a numeric key' => { '0' => { 'a' => '5' } },
      'a list of hashes' => [{ 'a' => '5' }] }.each do |kind, group_number|
      it "refuses a group number that is #{kind} and keeps the stored value" do
        update_category(group_number)

        expect_refusal
      end
    end

    { 'true' => true, 'false' => false, 'a list of lists' => [['5']],
      'an empty list' => [] }.each do |kind, group_number|
      it "refuses a JSON group number of #{kind} and keeps the stored value" do
        update_category(group_number, as: :json)

        expect_refusal
      end
    end

    it 'refuses a group number that the request sends as a file and keeps the stored value' do
      update_category(Rack::Test::UploadedFile.new(StringIO.new('1'), 'text/plain', original_filename: 'n.txt'))

      expect_refusal
    end

    # The post save stores the post and its custom-field values in one transaction. So a group number
    # that is not valid also rolls back the new attributes of the post.
    it 'stores no attribute of a post when the save of the post sends a group number that is not valid' do
      group = CamaleonCms::CustomFieldGroup.create!(name: 'Post fields', slug: 'post-fields',
                                                    object_class: 'PostType_Post', objectid: post_type.id,
                                                    site: current_site)
      group.add_manual_field({ 'name' => 'Note', 'slug' => 'note' }, { 'field_key' => 'text_box' })
      record = create(:post, post_type: post_type, owner: admin, title: 'Kept title')

      patch "/admin/post_type/#{post_type.id}/posts/#{record.id}", params: {
        post: { title: 'New title', content: '<p>plain</p>', status: 'published' },
        field_options: { '0' => { 'note' => { 'group_number' => '-1', 'values' => { '0' => 'x' } } } }
      }

      expect(response).to have_http_status(:found)
      expect(flash[:error]).to include("The group number of the 'note' field")
      expect(record.reload.title).to eq('Kept title')
    end

    # set_field_values builds no row for an entry with no values. It still checks the group number of
    # that entry.
    it 'refuses the group number of an entry with no values and keeps the stored value' do
      patch "/admin/post_type/#{post_type.id}/categories/#{category.id}", params: {
        category: { name: 'Grouped field' },
        field_options: { '0' => { 'subtitle' => { 'group_number' => 'abc' } } }
      }

      expect_refusal
    end

    it 'stores the value under the largest group number' do
      update_category('2147483647')

      expect(flash[:error]).to be_nil
      expect(category.reload.get_field_values('subtitle', 2_147_483_647)).to eq(['x'])
    end

    it 'stores the value in group 0 when the group number is empty' do
      update_category('')

      expect(flash[:error]).to be_nil
      expect(category.reload.get_field_values('subtitle')).to eq(['x'])
    end
  end

  it 'refuses a draft save whose field_options is a scalar, storing nothing' do
    parent_post = create(:post, post_type: post_type, owner: admin, slug: 'container-parent', status: 'published')

    post "/admin/post_type/#{post_type.id}/drafts", params: {
      post_id: parent_post.id,
      post: { title: 'Draft with scalar field_options' },
      field_options: 'foo'
    }

    expect(JSON.parse(response.body)['error'])
      .to include(I18n.t('camaleon_cms.admin.post.message.malformed_group', group: 'field_options'))
    expect(post_type.posts.drafts.where(post_parent: parent_post.id)).to be_empty
  end
end
