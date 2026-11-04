# frozen_string_literal: true

# set_field_values deletes every stored value of the record, then stores the values of the payload. It
# reads each entry by Symbol keys (values, group_number, id), so a plain Hash with String keys, for
# example a JSON.parse result, gave it no values: the call deleted the stored values and stored
# nothing. Now the method reads a plain Hash by String keys and by Symbol keys.
RSpec.describe CamaleonCms::CustomFieldsRelationship, type: :model do
  let(:post_type) { installed_post_type }
  let(:post) { create(:post, post_type: post_type) }
  let(:field_id) { post.get_field_object('note').id }

  before do
    group = CamaleonCms::CustomFieldGroup.create!(name: 'Fields', slug: 'fields',
                                                  object_class: 'PostType_Post', objectid: post_type.id,
                                                  site: post_type.site)
    group.add_manual_field({ name: 'Note', slug: 'note' }, { field_key: 'text_box' })
    post.set_field_value('note', 'kept')
  end

  describe 'set_field_values with a plain Hash with String keys' do
    it 'stores the values of an entry whose values are a hash keyed by index' do
      post.set_field_values({ '0' => { 'note' => { 'id' => field_id.to_s, 'values' => { '0' => 'new' } } } })

      expect(post.reload.get_field_values('note')).to eq(['new'])
    end

    it 'stores the values of a JSON.parse result' do
      payload = JSON.parse({ 0 => { note: { id: field_id, group_number: 1, values: %w[one two] } } }.to_json)

      post.set_field_values(payload)

      expect(post.reload.get_field_values('note', 1)).to eq(%w[one two])
    end

    it 'reads the group number of the entry' do
      post.set_field_values({ '0' => { 'note' => { 'group_number' => '2', 'values' => { '0' => 'second' } } } })

      expect(post.reload.custom_field_values.pluck(:value, :group_number)).to eq([['second', 2]])
    end

    it 'refuses an invalid group number of the entry, and the stored value stays' do
      expect { post.set_field_values({ '0' => { 'note' => { 'group_number' => '-1', 'values' => ['new'] } } }) }
        .to raise_error(ActiveRecord::RecordInvalid, /group number of the 'note' field/)
      expect(post.reload.get_field_values('note')).to eq(['kept'])
    end

    it 'stores the values of an entry with Symbol keys beside an entry with String keys' do
      payload = { '0' => { 'note' => { values: ['first'] } },
                  '1' => { 'note' => { 'group_number' => 1, 'values' => ['second'] } } }

      post.set_field_values(payload)

      expect(post.reload.custom_field_values.order(:group_number).pluck(:value, :group_number))
        .to eq([['first', 0], ['second', 1]])
    end

    it 'refuses a slug as a String and as a Symbol, and the stored value stays' do
      payload = { '0' => { note: { values: ['first'] }, 'note' => { values: ['second'] } } }

      expect { post.set_field_values(payload) }
        .to raise_error(ArgumentError, /key :note as a String and as a Symbol/)
      expect(post.reload.get_field_values('note')).to eq(['kept'])
    end

    it 'refuses a twin key in a value of an entry' do
      payload = { '0' => { 'note' => { 'values' => [{ size: 1, 'size' => 2 }] } } }

      expect { post.set_field_values(payload) }
        .to raise_error(ArgumentError, /key :size as a String and as a Symbol/)
      expect(post.reload.get_field_values('note')).to eq(['kept'])
    end

    it 'keeps the keys of the Hash of the caller' do
      payload = { '0' => { 'note' => { 'values' => { '0' => 'new' } } } }

      post.set_field_values(payload)

      expect(payload).to eq({ '0' => { 'note' => { 'values' => { '0' => 'new' } } } })
      expect(payload['0']['note']).to be_an_instance_of(Hash)
    end
  end

  # The payload of an admin save has indifferent access, and a theme can pass the request parameters.
  describe 'set_field_values with request parameters' do
    it 'stores the values of unpermitted request parameters' do
      params = ActionController::Parameters.new('0' => { 'note' => { 'values' => { '0' => 'new' } } })

      post.set_field_values(params)

      expect(post.reload.get_field_values('note')).to eq(['new'])
    end
  end
end
