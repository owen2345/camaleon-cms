# frozen_string_literal: true

# A group number is an index from 0, and PostgreSQL and MySQL store it in a 4-byte integer column. A
# number above that range raised ActiveModel::RangeError at the save. The value row refuses a group
# number that is not an integer from 0 to 2147483647.
RSpec.describe CamaleonCms::CustomFieldsRelationship, type: :model do
  let(:post_type) { create(:post_type) }
  let(:post) { create(:post, post_type: post_type) }

  before do
    group = CamaleonCms::CustomFieldGroup.create!(name: 'Fields', slug: 'fields',
                                                  object_class: 'PostType_Post', objectid: post_type.id,
                                                  site: post_type.site)
    group.add_manual_field({ name: 'Note', slug: 'note' }, { field_key: 'text_box' })
  end

  describe 'set_field_value' do
    before { post.set_field_value('note', 'kept', group_number: 1) }

    [2_147_483_648, -1, true, 1.5, '1abc', [1], :'5'].each do |group_number|
      it "refuses the group number #{group_number.inspect} and keeps the stored value" do
        expect { post.set_field_value('note', 'new', group_number: group_number) }
          .to raise_error(ActiveRecord::RecordInvalid, /group number/)
        expect(post.get_field_values('note', 1)).to eq(['kept'])
      end
    end

    it 'stores a value under the largest group number' do
      post.set_field_value('note', 'last', group_number: 2_147_483_647)

      expect(post.get_field_values('note', 2_147_483_647)).to eq(['last'])
    end

    it 'stores a value under a group number given as a text of digits' do
      post.set_field_value('note', 'second', group_number: '2')

      expect(post.get_field_values('note', 2)).to eq(['second'])
    end

    it 'stores a value with no group number' do
      post.set_field_value('note', 'unset', group_number: nil)

      expect(post.custom_field_values.where(group_number: nil).pluck(:value)).to eq(['unset'])
    end
  end

  # The row cannot read a text with a broken encoding, or a text in an encoding that is not
  # ASCII-compatible: the integer cast of Rails, or the lookup of the writer, raises its own error.
  # The two writers refuse that text before they build the row.
  describe 'a group number text that the row cannot read' do
    before { post.set_field_value('note', 'kept', group_number: 1) }

    { 'with a broken encoding' => "1\xFF",
      'in UTF-16' => '1'.encode('UTF-16LE'),
      'in UTF-7' => (+'1').force_encoding('UTF-7') }.each do |kind, group_number|
      it "gets the refusal of set_field_value for a text #{kind}, and the stored value stays" do
        expect { post.set_field_value('note', 'new', group_number: group_number) }
          .to raise_error(ActiveRecord::RecordInvalid, /group number of the 'note' field/)
        expect(post.reload.get_field_values('note', 1)).to eq(['kept'])
      end

      it "gets the refusal of set_field_values for a text #{kind}, and the stored value stays" do
        expect { post.set_field_values({ '0' => { 'note' => { group_number: group_number, values: ['new'] } } }) }
          .to raise_error(ActiveRecord::RecordInvalid, /group number of the 'note' field/)
        expect(post.reload.get_field_values('note', 1)).to eq(['kept'])
      end
    end

    it 'gets the refusal of a new row for a text in UTF-16' do
      row = post.custom_field_values.new(custom_field_slug: 'note', group_number: '1'.encode('UTF-16LE'))

      expect(row).not_to be_valid
      expect(row.errors[:base]).to include(row.group_number_refusal)
    end
  end

  it 'gives the refusal in each language of the admin' do
    files = Dir[CamaleonCms::Engine.root.join('config/locales/camaleon_cms/admin/*.yml')]
    locales = files.map { |file| YAML.load_file(file).keys.first }
    expect(locales).to include('en', 'es', 'zh-CN')
    english = I18n.t('camaleon_cms.admin.custom_field.message.group_number_invalid',
                     locale: :en, slug: 'note', max: described_class::MAX_GROUP_NUMBER)

    locales.each do |locale|
      row = post.custom_field_values.new(custom_field_slug: 'note', group_number: -1)
      I18n.with_locale(locale) { row.valid? }

      expect(row.errors[:base].first).to include("'note'", '2147483647'), locale
      expect(row.errors[:base].first).not_to eq(english), locale unless locale == 'en'
    end
  end

  it 'updates the value of a stored row that holds a negative group number' do
    post.set_field_value('note', 'old')
    row = post.custom_field_values.first
    row.update_column(:group_number, -1) # rubocop:disable Rails/SkipsModelValidations

    expect(row.reload.update(value: 'new')).to be(true)
  end

  it 'refuses a negative group number written to a stored row' do
    post.set_field_value('note', 'old')
    row = post.custom_field_values.first

    expect(row.update(group_number: -1)).to be(false)
    expect(row.reload.group_number).to eq(0)
  end
end
