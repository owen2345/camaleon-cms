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

  # A column that holds a wider integer can hold a number above the range of the type. An update with
  # an SQL text skips the type.
  def store_wide_group_number(row)
    skip 'The column holds a 4-byte integer' unless described_class.connection.adapter_name.match?(/sqlite/i)

    described_class.where(id: row.id).update_all('group_number = 2147483648') # rubocop:disable Rails/SkipsModelValidations
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

    # A call with an empty list builds no row, so no row refuses the group number. The writer refuses
    # the number before its delete.
    ['1abc', true, 1.5, -1, [1], "1\xFF"].each do |group_number|
      it "refuses the group number #{group_number.inspect} with an empty list and keeps the stored value" do
        expect { post.set_field_value('note', [], group_number: group_number) }
          .to raise_error(ActiveRecord::RecordInvalid, /group number of the 'note' field/)
        expect(post.get_field_values('note', 1)).to eq(['kept'])
      end
    end

    it 'refuses a group number with an empty list when the call does not clear the stored values' do
      expect { post.set_field_value('note', [], group_number: '1abc', clear: false) }
        .to raise_error(ActiveRecord::RecordInvalid, /group number of the 'note' field/)
    end

    it 'removes the stored values of a group with an empty list' do
      post.set_field_value('note', [], group_number: 1)

      expect(post.get_field_values('note', 1)).to eq([])
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

  # The check of the writer reads the group number of the row, not the errors that the row holds.
  describe 'refuse_invalid_group_number!' do
    let(:row) { described_class.new(custom_field_slug: 'note', group_number: -1) }

    before { row.valid? }

    it 'passes a valid group number on a row that holds an earlier refusal' do
      row.group_number = 1

      expect { row.refuse_invalid_group_number! }.not_to raise_error
    end

    it 'adds no second refusal to a row that holds the refusal' do
      expect { row.refuse_invalid_group_number! }.to raise_error(ActiveRecord::RecordInvalid)
      expect(row.errors[:base]).to eq([row.group_number_refusal])
    end
  end

  # The integer cast of Rails cannot read a text with a broken encoding, or in an encoding that is not
  # ASCII-compatible. The row keeps that text from the cast and refuses it.
  describe 'a group number text that the integer cast cannot read' do
    let(:field_id) { post.get_field_object('note').id }

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

      it "gets the refusal of a direct create! for a text #{kind}" do
        attrs = { custom_field_id: field_id, custom_field_slug: 'note', value: 'new', group_number: group_number }

        expect { post.custom_field_values.create!(attrs) }
          .to raise_error(ActiveRecord::RecordInvalid, /group number of the 'note' field/)
        expect(post.reload.get_field_values('note', 1)).to eq(['kept'])
      end

      it "gets the refusal of a stored row for a text #{kind}, and the stored number stays" do
        row = post.custom_field_values.first

        expect(row.update(group_number: group_number)).to be(false)
        expect(row.errors[:base]).to include(row.group_number_refusal)
        expect(row.reload.group_number).to eq(1)
      end

      it "stops a save that skips the validation for a text #{kind}, and the stored number stays" do
        row = post.custom_field_values.first

        expect(row.update_attribute(:group_number, group_number)).to be(false) # rubocop:disable Rails/SkipsModelValidations
        expect(row.errors[:base]).to eq([row.group_number_refusal])
        expect(row.reload.group_number).to eq(1)
      end

      it "gets the refusal of a stored row for a text #{kind} written with []=, and the stored number stays" do
        row = post.custom_field_values.first
        row[:group_number] = group_number

        expect(row.save).to be(false)
        expect(row.errors[:base]).to eq([row.group_number_refusal])
        expect(row.reload.group_number).to eq(1)
      end

      it "gets the refusal of a new row for a text #{kind} written with write_attribute" do
        row = post.custom_field_values.new(custom_field_id: field_id, custom_field_slug: 'note', value: 'new')
        row.write_attribute(:group_number, group_number)

        expect(row.save).to be(false)
        expect(row.errors[:base]).to eq([row.group_number_refusal])
        expect(post.custom_field_values.reload.pluck(:value)).to eq(['kept'])
      end

      it "gets the refusal of find_or_create_by! for a text #{kind}, and the stored value stays" do
        attrs = { custom_field_id: field_id, custom_field_slug: 'note', value: 'new', group_number: group_number }

        expect { post.custom_field_values.find_or_create_by!(attrs) }
          .to raise_error(ActiveRecord::RecordInvalid, /group number of the 'note' field/)
        expect(post.reload.get_field_values('note', 1)).to eq(['kept'])
      end

      it "finds no row in a lookup for a text #{kind}" do
        post.set_field_value('note', 'unset', group_number: nil)

        expect(post.custom_field_values.where(group_number: group_number)).to be_empty
        expect(post.get_field_values('note', group_number)).to eq([])
      end
    end

    it 'stops the save of a new row that skips the validation for a text with a broken encoding' do
      row = post.custom_field_values.new(custom_field_id: field_id, custom_field_slug: 'note', value: 'new',
                                         group_number: "1\xFF")

      expect(row.save(validate: false)).to be(false)
      expect { row.save!(validate: false) }
        .to raise_error(ActiveRecord::RecordInvalid, /group number of the 'note' field/)
      expect(row.errors[:base]).to eq([row.group_number_refusal])
      expect(post.custom_field_values.reload.pluck(:value)).to eq(['kept'])
    end

    it 'gets the refusal of a stored row with no group number for a text with a broken encoding' do
      post.set_field_value('note', 'unset', group_number: nil)
      row = post.custom_field_values.find_by(group_number: nil)

      expect(row.update(group_number: "1\xFF")).to be(false)
      expect(row.errors[:base]).to include(row.group_number_refusal)
    end
  end

  # A copy takes the cast value of each attribute, and the cast hides a group number that the row
  # refuses. The copy keeps the group number as the caller gave it.
  describe 'a copy of a row' do
    let(:field_id) { post.get_field_object('note').id }

    before { post.set_field_value('note', 'kept', group_number: 3) }

    { 'a text that is not digits' => 'abc',
      'a boolean' => true,
      'a text with a broken encoding' => "1\xFF",
      'a text in UTF-16' => '1'.encode('UTF-16LE') }.each do |kind, group_number|
      it "refuses the group number of the original row when it is #{kind}" do
        row = post.custom_field_values.new(custom_field_id: field_id, custom_field_slug: 'note', value: 'copy',
                                           group_number: group_number)
        copy = row.dup

        expect(copy.save).to be(false)
        expect(copy.errors[:base]).to eq([copy.group_number_refusal])
        expect(post.custom_field_values.reload.pluck(:value)).to eq(['kept'])
      end
    end

    it 'stores the group number of a stored row' do
      copy = post.custom_field_values.first.dup

      expect(copy.save).to be(true)
      expect(copy.reload.group_number).to eq(3)
    end

    it 'stores no group number for a row that a query read without its group number' do
      copy = described_class.select(:id, :custom_field_id, :custom_field_slug, :value).first.dup

      expect(copy.save).to be(true)
      expect(copy.reload.group_number).to be_nil
    end

    # A copy is a new row, so the row checks its group number. A stored row can hold a number that a
    # new row refuses.
    it 'refuses the copy of a stored row that holds a negative group number' do
      row = post.custom_field_values.first
      row.update_column(:group_number, -1) # rubocop:disable Rails/SkipsModelValidations
      copy = row.reload.dup

      expect(copy.save).to be(false)
      expect(copy.errors[:base]).to eq([copy.group_number_refusal])
    end

    it 'refuses the copy of a stored row that holds a group number above the range in a wider column' do
      row = post.custom_field_values.first
      store_wide_group_number(row)
      copy = row.reload.dup

      expect(copy.save).to be(false)
      expect(copy.errors[:base]).to eq([copy.group_number_refusal])
    end
  end

  # The type of the group number has the 4-byte range on each database, also where the column holds
  # a wider integer.
  describe 'a group number above the range of the type' do
    let(:row) { post.custom_field_values.first }

    before { post.set_field_value('note', 'kept', group_number: 1) }

    it 'raises ActiveModel::RangeError in a write that skips the validation and the callbacks' do
      attrs = { custom_field_id: row.custom_field_id, custom_field_slug: 'note', value: 'bulk',
                group_number: 2_147_483_648 }

      expect { row.update_column(:group_number, 2_147_483_648) } # rubocop:disable Rails/SkipsModelValidations
        .to raise_error(ActiveModel::RangeError)
      expect { described_class.where(id: row.id).update_all(group_number: 2_147_483_648) } # rubocop:disable Rails/SkipsModelValidations
        .to raise_error(ActiveModel::RangeError)
      expect { described_class.insert_all([attrs]) } # rubocop:disable Rails/SkipsModelValidations
        .to raise_error(ActiveModel::RangeError)
      expect(row.reload.group_number).to eq(1)
      expect(described_class.where(value: 'bulk')).to be_empty
    end

    context 'with a stored row that holds the number in a wider column' do
      before { store_wide_group_number(row) }

      it 'finds no row in a lookup' do
        expect(post.custom_field_values.where(group_number: 2_147_483_648)).to be_empty
        expect(post.get_field_values('note', 2_147_483_648)).to eq([])
      end

      it 'reads the stored number and updates the value of the row' do
        expect(row.reload.group_number).to eq(2_147_483_648)
        expect(row.update(value: 'new')).to be(true)
      end
    end
  end

  # A caller can hold a transaction of its own and rescue the refusal inside it. Each writer opens a
  # savepoint there, so the refusal also rolls back the delete of the stored values.
  describe 'a refusal inside a transaction of the caller' do
    before { post.set_field_value('note', 'kept', group_number: 1) }

    it 'keeps the stored value when the caller rescues the refusal of set_field_value' do
      ActiveRecord::Base.transaction do
        post.set_field_value('note', 'new', group_number: '1abc')
      rescue ActiveRecord::RecordInvalid
        nil
      end

      expect(post.reload.get_field_values('note', 1)).to eq(['kept'])
    end

    it 'keeps the stored values when the caller rescues the refusal of set_field_values' do
      ActiveRecord::Base.transaction do
        post.set_field_values({ '0' => { 'note' => { group_number: -1, values: ['new'] } } })
      rescue ActiveRecord::RecordInvalid
        nil
      end

      expect(post.reload.get_field_values('note', 1)).to eq(['kept'])
    end
  end

  # The rollback of a failed write leaves the rows of the call in the association of the record. Each
  # writer resets the association, so the record reads the stored values and its next save stores no
  # row of the call.
  describe 'the record after a failed write' do
    before { post.set_field_value('note', 'kept', group_number: 1) }

    it 'reads the stored values and saves after a refusal of set_field_values' do
      payload = { '0' => { 'note' => { group_number: 0, values: ['fresh'] } },
                  '1' => { 'note' => { group_number: -1, values: ['new'] } } }

      expect { post.set_field_values(payload) }.to raise_error(ActiveRecord::RecordInvalid)

      expect(post.get_field_values('note', 1)).to eq(['kept'])
      expect(post.get_field_values('note', 0)).to eq([])
      expect(post.update(title: 'Saved')).to be(true)
      expect(described_class.where(custom_field_slug: 'note').pluck(:value)).to eq(['kept'])
    end

    it 'reads the stored values after an error of set_field_values that is not a refusal' do
      payload = { '0' => { 'note' => { values: ['fresh'] }, 'unknown' => { id: 2**64, values: ['x'] } } }

      expect { post.set_field_values(payload) }.to raise_error(ActiveModel::RangeError)

      expect(post.get_field_values('note', 1)).to eq(['kept'])
      expect(post.get_field_values('note', 0)).to eq([])
    end

    # The reset drops each unsaved row of the association. The writer puts back the rows that the
    # caller built before the call, so the next save of the record stores them.
    context 'with a row that the caller built before the call' do
      let(:stored_values) { described_class.where(custom_field_slug: 'note').pluck(:value) }

      before do
        post.custom_field_values.build(custom_field_id: post.get_field_object('note').id,
                                       custom_field_slug: 'note', value: 'built', group_number: 5)
      end

      it 'keeps that row after an error of set_field_value' do
        expect { post.set_field_value('note', 'new', order: 2**64) }.to raise_error(ActiveModel::RangeError)

        expect(post.save).to be(true)
        expect(stored_values).to contain_exactly('kept', 'built')
      end

      it 'keeps that row after a refusal of set_field_value' do
        expect { post.set_field_value('note', 'new', group_number: -1) }.to raise_error(ActiveRecord::RecordInvalid)

        expect(post.save).to be(true)
        expect(stored_values).to contain_exactly('kept', 'built')
      end

      it 'keeps that row after a refusal of set_field_values' do
        payload = { '0' => { 'note' => { group_number: -1, values: ['new'] } } }

        expect { post.set_field_values(payload) }.to raise_error(ActiveRecord::RecordInvalid)

        expect(post.save).to be(true)
        expect(stored_values).to contain_exactly('kept', 'built')
      end
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
