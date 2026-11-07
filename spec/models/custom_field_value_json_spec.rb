# frozen_string_literal: true

# A hash custom-field value is stored as JSON with one entry per key, however each key was written:
# json 3 refuses to generate a duplicate key and json 2 stored both.
RSpec.describe CamaleonCms::CustomFieldsRelationship, type: :model do
  let(:post_type) { create(:post_type) }
  let(:post) { create(:post, post_type: post_type) }

  before do
    group = CamaleonCms::CustomFieldGroup.create!(name: 'Fields', slug: 'fields',
                                                  object_class: 'PostType_Post', objectid: post_type.id,
                                                  site: post_type.site)
    group.add_manual_field({ name: 'Note', slug: 'note' }, { field_key: 'text_box' })
  end

  it 'stores a hash value with one entry per key however each key was written' do
    post.set_field_value('note', { a: 1 }.merge('a' => 2))

    expect(post.custom_field_values.find_by!(custom_field_slug: 'note').value).to eq('{"a":2}')
  end

  # set_meta stores a one-letter 't' or 'f' as its JSON string, which the metas read unquotes; a custom-field
  # value is read as the column holds it, so it is stored as the letter
  it 'reads back a one-letter t or f as the letter, however it is written' do
    post.set_field_value('note', 't')
    expect(post.get_field_value('note')).to eq('t')

    post.save_field_value('note', [:f])
    expect(post.get_field_values('note')).to eq(['f'])

    post.set_field_values({ '0' => { 'note' => { values: { '0' => 't', '1' => 'f' } } } })
    expect(post.get_field_values('note')).to eq(%w[t f])
  end

  # update_field_value stores a value in the form that set_field_value gives one value
  describe 'update_field_value' do
    before { post.set_field_value('note', 'old') }

    def stored_note
      post.custom_field_values.find_by!(custom_field_slug: 'note').value
    end

    it 'stores a Hash as JSON, which the_json_field reads' do
      post.update_field_value('note', { a: [1], 'b' => 2 })

      expect(stored_note).to eq('{"a":[1],"b":2}')
      # the_json_field gives each value as a String
      expect(post.decorate.the_json_field('note')).to eq('a' => '[1]', 'b' => '2')
    end

    it 'stores an Array as JSON in one row' do
      post.update_field_value('note', [1, 'x'])

      expect(stored_note).to eq('[1,"x"]')
      expect(post.reload.get_field_values('note')).to eq(['[1,"x"]'])
    end

    it 'stores ActionController::Parameters as JSON' do
      post.update_field_value('note', ActionController::Parameters.new(a: '1'))

      expect(stored_note).to eq('{"a":"1"}')
    end

    it 'stores true and false as the Strings true and false' do
      post.update_field_value('note', true)
      expect(stored_note).to eq('true')

      post.update_field_value('note', false)
      expect(stored_note).to eq('false')
    end

    it 'stores a String and an Integer as before' do
      post.update_field_value('note', '007 text')
      expect(stored_note).to eq('007 text')

      post.update_field_value('note', 42)
      expect(stored_note).to eq('42')
    end
  end
end
