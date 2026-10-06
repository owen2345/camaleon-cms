# frozen_string_literal: true

# An author can add a repeatable field group to a post several times. The group number of a
# custom-field value is the index of the copy that the value belongs to, from 0. It is valid when it
# is nil, an Integer from 0 to 2147483647, or a String of 1 to 16 digits with such a number. For each
# other group number, the save raises ActiveRecord::RecordInvalid.
RSpec.describe CamaleonCms::CustomFieldsRelationship, type: :model do
  let(:post_type) { installed_post_type }
  let(:post) { create(:post, post_type: post_type) }

  before do
    group = CamaleonCms::CustomFieldGroup.create!(name: 'Fields', slug: 'fields',
                                                  object_class: 'PostType_Post', objectid: post_type.id,
                                                  site: post_type.site)
    group.add_manual_field({ name: 'Note', slug: 'note' }, { field_key: 'text_box' })
  end

  # Stores a group number outside the 4-byte range in a stored row. Only a wider column can hold it
  # (SQLite here). The update uses an SQL string, because Rails does not check the range there.
  def store_wide_group_number(row, number = 2_147_483_648)
    skip 'The column holds a 4-byte integer' unless described_class.connection.adapter_name.match?(/sqlite/i)

    described_class.where(id: row.id).update_all(['group_number = ?', number]) # rubocop:disable Rails/SkipsModelValidations
  end

  describe 'set_field_value' do
    before { post.set_field_value('note', 'kept', group_number: 1) }

    # A group number String is valid only when each character is an ASCII digit.
    [2_147_483_648, -1, true, 1.5, '1abc', '', "1\n", "\uFF11\uFF12", [1], :'5'].each do |group_number|
      it "refuses the group number #{group_number.inspect} and keeps the stored value" do
        expect { post.set_field_value('note', 'new', group_number: group_number) }
          .to raise_error(ActiveRecord::RecordInvalid, /group number/)
        expect(post.get_field_values('note', 1)).to eq(['kept'])
      end
    end

    # With an empty list of values, set_field_value creates no row that validates the group number.
    # So it validates the number itself, before it deletes the stored values.
    ['1abc', true, 1.5, -1, [1], "1\xFF"].each do |group_number|
      it "refuses the group number #{group_number.inspect} with an empty list of values, and the stored value stays" do
        expect { post.set_field_value('note', [], group_number: group_number) }
          .to raise_error(ActiveRecord::RecordInvalid, /group number of the 'note' field/)
        expect(post.get_field_values('note', 1)).to eq(['kept'])
      end
    end

    it 'refuses a group number with an empty list when the call does not clear the stored values' do
      expect { post.set_field_value('note', [], group_number: '1abc', clear: false) }
        .to raise_error(ActiveRecord::RecordInvalid, /group number of the 'note' field/)
    end

    it 'raises ArgumentError for a slug with no custom field, before it checks the group number' do
      expect { post.set_field_value('no-such', 'new', group_number: -1) }
        .to raise_error(ArgumentError, /no custom field configured/)
    end

    it 'removes the stored values of a group with an empty list' do
      post.set_field_value('note', [], group_number: 1)

      expect(post.get_field_values('note', 1)).to eq([])
    end

    it 'stores a value under the largest group number' do
      post.set_field_value('note', 'last', group_number: 2_147_483_647)

      expect(post.get_field_values('note', 2_147_483_647)).to eq(['last'])
    end

    it 'stores a value under a group number given as a String of digits' do
      post.set_field_value('note', 'second', group_number: '2')

      expect(post.get_field_values('note', 2)).to eq(['second'])
    end

    # Rails 8.1.4 casts only the first 16 bytes of a String, so a longer String is invalid.
    it 'stores a value under a group number given as a String of 16 digits' do
      post.set_field_value('note', 'padded', group_number: "#{'0' * 15}7")

      expect(post.get_field_values('note', 7)).to eq(['padded'])
    end

    it 'refuses a group number given as a String of 17 digits and keeps the stored value' do
      expect { post.set_field_value('note', 'new', group_number: "#{'0' * 16}1") }
        .to raise_error(ActiveRecord::RecordInvalid, /group number/)
      expect(post.custom_field_values.pluck(:value, :group_number)).to eq([['kept', 1]])
    end

    it 'stores a value with no group number' do
      post.set_field_value('note', 'unset', group_number: nil)

      expect(post.custom_field_values.where(group_number: nil).pluck(:value)).to eq(['unset'])
    end

    it 'returns the row that it stored' do
      row = post.set_field_value('note', 'new', group_number: 2)

      expect(row).to eq(described_class.find_by!(value: 'new'))
    end
  end

  # set_field_values creates no row for an entry with no values, so it validates the group number of
  # that entry itself.
  describe 'set_field_values with an entry that has no values' do
    before { post.set_field_value('note', 'kept', group_number: 1) }

    { "the String 'abc' and an empty hash of values" => { group_number: 'abc', values: {} },
      'a negative number and an empty list of values' => { group_number: -1, values: [] },
      'a number above the range and no values' => { group_number: 2_147_483_648 },
      'a String with a broken encoding and no values' => { group_number: "1\xFF", values: nil },
      'an empty String in UTF-16 and no values' => { group_number: ''.encode('UTF-16LE') } }.each do |kind, entry|
      it "refuses an entry with #{kind}, and the stored value stays" do
        expect { post.set_field_values({ '0' => { 'note' => entry } }) }
          .to raise_error(ActiveRecord::RecordInvalid, /group number of the 'note' field/)
        expect(post.reload.get_field_values('note', 1)).to eq(['kept'])
      end
    end

    it 'refuses such an entry after an entry that it stored, and the old stored value stays' do
      payload = { '0' => { 'note' => { group_number: 0, values: ['fresh'] } },
                  '1' => { 'note' => { group_number: 'abc' } } }

      expect { post.set_field_values(payload) }.to raise_error(ActiveRecord::RecordInvalid)
      expect(post.reload.custom_field_values.pluck(:value)).to eq(['kept'])
    end

    { 'a valid group number and an empty hash of values' => { group_number: 2, values: {} },
      'an empty group number and no values' => { group_number: '' },
      'no group number and an empty list of values' => { values: [] } }.each do |kind, entry|
      it "stores no row for an entry with #{kind}" do
        post.set_field_values({ '0' => { 'note' => entry } })

        expect(post.reload.custom_field_values).to be_empty
      end
    end
  end

  # The method validates the current group number, not the errors of an earlier validation.
  describe 'refuse_invalid_group_number!' do
    let(:row) { described_class.new(custom_field_slug: 'note', group_number: -1) }

    before { row.valid? }

    it 'raises no error for a valid group number on a row that holds an earlier group number error' do
      row.group_number = 1

      expect { row.refuse_invalid_group_number! }.not_to raise_error
    end

    it 'does not add the error message a second time to a row that holds it' do
      expect { row.refuse_invalid_group_number! }.to raise_error(ActiveRecord::RecordInvalid)
      expect(row.errors[:base]).to eq([row.group_number_refusal])
    end
  end

  # Rails raises an encoding error when it casts a String in an invalid encoding to an Integer, and
  # when it looks up a String in an encoding such as UTF-16. The group number type returns nil for
  # such a String, and the row gets the usual group number error.
  describe 'a group number String that Rails cannot cast' do
    let(:field_id) { post.get_field_object('note').id }

    before { post.set_field_value('note', 'kept', group_number: 1) }

    { 'with a broken encoding' => "1\xFF",
      'in UTF-16' => '1'.encode('UTF-16LE'),
      'in UTF-7' => (+'1').force_encoding('UTF-7') }.each do |kind, group_number|
      it "set_field_value raises the group number error for a String #{kind}, and the stored value stays" do
        expect { post.set_field_value('note', 'new', group_number: group_number) }
          .to raise_error(ActiveRecord::RecordInvalid, /group number of the 'note' field/)
        expect(post.reload.get_field_values('note', 1)).to eq(['kept'])
      end

      it "set_field_values raises the group number error for a String #{kind}, and the stored value stays" do
        expect { post.set_field_values({ '0' => { 'note' => { group_number: group_number, values: ['new'] } } }) }
          .to raise_error(ActiveRecord::RecordInvalid, /group number of the 'note' field/)
        expect(post.reload.get_field_values('note', 1)).to eq(['kept'])
      end

      it "create! on the association raises the group number error for a String #{kind}" do
        attrs = { custom_field_id: field_id, custom_field_slug: 'note', value: 'new', group_number: group_number }

        expect { post.custom_field_values.create!(attrs) }
          .to raise_error(ActiveRecord::RecordInvalid, /group number of the 'note' field/)
        expect(post.reload.get_field_values('note', 1)).to eq(['kept'])
      end

      it "the update of a stored row fails for a String #{kind}, and the stored number stays" do
        row = post.custom_field_values.first

        expect(row.update(group_number: group_number)).to be(false)
        expect(row.errors[:base]).to include(row.group_number_refusal)
        expect(row.reload.group_number).to eq(1)
      end

      it "update_attribute returns false for a String #{kind}, and the stored number stays" do
        row = post.custom_field_values.first

        expect(row.update_attribute(:group_number, group_number)).to be(false) # rubocop:disable Rails/SkipsModelValidations
        expect(row.errors[:base]).to eq([row.group_number_refusal])
        expect(row.reload.group_number).to eq(1)
      end

      it "the save of a stored row fails when []= writes a String #{kind}, and the stored number stays" do
        row = post.custom_field_values.first
        row[:group_number] = group_number

        expect(row.save).to be(false)
        expect(row.errors[:base]).to eq([row.group_number_refusal])
        expect(row.reload.group_number).to eq(1)
      end

      it "the save of a new row fails when write_attribute writes a String #{kind}" do
        row = post.custom_field_values.new(custom_field_id: field_id, custom_field_slug: 'note', value: 'new')
        row.write_attribute(:group_number, group_number)

        expect(row.save).to be(false)
        expect(row.errors[:base]).to eq([row.group_number_refusal])
        expect(post.custom_field_values.reload.pluck(:value)).to eq(['kept'])
      end

      it "find_or_create_by! raises the group number error for a String #{kind}, and the stored value stays" do
        attrs = { custom_field_id: field_id, custom_field_slug: 'note', value: 'new', group_number: group_number }

        expect { post.custom_field_values.find_or_create_by!(attrs) }
          .to raise_error(ActiveRecord::RecordInvalid, /group number of the 'note' field/)
        expect(post.reload.get_field_values('note', 1)).to eq(['kept'])
      end

      it "finds no row in a lookup for a String #{kind}" do
        post.set_field_value('note', 'unset', group_number: nil)

        expect(post.custom_field_values.where(group_number: group_number)).to be_empty
        expect(post.get_field_values('note', group_number)).to eq([])
      end

      it "update_column, update_all and insert_all store no group number for a String #{kind}" do
        row = post.custom_field_values.first
        attrs = { custom_field_id: field_id, custom_field_slug: 'note', value: 'bulk', group_number: group_number }

        row.update_column(:group_number, group_number) # rubocop:disable Rails/SkipsModelValidations
        expect(row.reload.group_number).to be_nil

        row.update_column(:group_number, 1) # rubocop:disable Rails/SkipsModelValidations
        described_class.where(id: row.id).update_all(group_number: group_number) # rubocop:disable Rails/SkipsModelValidations
        expect(row.reload.group_number).to be_nil

        described_class.insert_all([attrs]) # rubocop:disable Rails/SkipsModelValidations
        expect(described_class.find_by(value: 'bulk').group_number).to be_nil
      end
    end

    # A form sends an empty group number as '', which means group 0. An empty UTF-16 String is
    # invalid. Ruby says that the two are equal, so set_field_values also reads the encoding.
    it 'set_field_values raises the group number error for an empty String in UTF-16, and the stored value stays' do
      payload = { '0' => { 'note' => { group_number: ''.encode('UTF-16LE'), values: ['new'] } } }

      expect { post.set_field_values(payload) }
        .to raise_error(ActiveRecord::RecordInvalid, /group number of the 'note' field/)
      expect(post.reload.get_field_values('note', 1)).to eq(['kept'])
    end

    # A multipart request can send the empty group number of a form in a binary encoding. It also
    # means group 0.
    it 'stores the value in group 0 for an empty String in a binary encoding' do
      post.set_field_values({ '0' => { 'note' => { group_number: ''.b, values: ['new'] } } })

      expect(post.reload.get_field_values('note', 0)).to eq(['new'])
    end

    it 'save(validate: false) stores no new row for a String with a broken encoding' do
      row = post.custom_field_values.new(custom_field_id: field_id, custom_field_slug: 'note', value: 'new',
                                         group_number: "1\xFF")

      expect(row.save(validate: false)).to be(false)
      expect { row.save!(validate: false) }
        .to raise_error(ActiveRecord::RecordInvalid, /group number of the 'note' field/)
      expect(row.errors[:base]).to eq([row.group_number_refusal])
      expect(post.custom_field_values.reload.pluck(:value)).to eq(['kept'])
    end

    it 'the update of a stored row with no group number fails for a String with a broken encoding' do
      post.set_field_value('note', 'unset', group_number: nil)
      row = post.custom_field_values.find_by(group_number: nil)

      expect(row.update(group_number: "1\xFF")).to be(false)
      expect(row.errors[:base]).to include(row.group_number_refusal)
      expect(row.valid?).to be(false)
    end
  end

  # update_attribute and save(validate: false) skip the validation. A before_save callback stops
  # them only for a String that the type cannot cast. They store each other invalid group number as
  # Rails casts it.
  describe 'a save that skips the validation, with an invalid group number' do
    let(:row) { post.custom_field_values.first }

    before { post.set_field_value('note', 'kept', group_number: 3) }

    it 'stores the number that the Rails cast returns' do
      expect(row.update_attribute(:group_number, -1)).to be(true) # rubocop:disable Rails/SkipsModelValidations
      expect(row.reload.group_number).to eq(-1)

      row.group_number = 'abc'
      expect(row.save(validate: false)).to be(true)
      expect(row.reload.group_number).to eq(0)
    end

    # Camaleon adds Array#to_i (lib/ext/array.rb), so Rails casts a list to a list, which the type
    # cannot store. The error class depends on the Rails version.
    it 'raises an error for a list of numbers' do
      expect { row.update_attribute(:group_number, [1]) }.to raise_error(StandardError) # rubocop:disable Rails/SkipsModelValidations
      expect(row.reload.group_number).to eq(3)
    end
  end

  # dup copies each attribute after the type cast, and the cast changes 'abc' to a valid 0. The copy
  # must keep the group number as given, so the copy of an invalid row is invalid too.
  describe 'a copy of a row (dup)' do
    let(:field_id) { post.get_field_object('note').id }

    before { post.set_field_value('note', 'kept', group_number: 3) }

    { 'a String that is not digits' => 'abc',
      'a boolean' => true,
      'a String with a broken encoding' => "1\xFF",
      'a String in UTF-16' => '1'.encode('UTF-16LE') }.each do |kind, group_number|
      it "the save of the copy fails when the group number of the original row is #{kind}" do
        row = post.custom_field_values.new(custom_field_id: field_id, custom_field_slug: 'note', value: 'copy',
                                           group_number: group_number)
        copy = row.dup

        expect(copy.save).to be(false)
        expect(copy.errors[:base]).to eq([copy.group_number_refusal])
        expect(post.custom_field_values.reload.pluck(:value)).to eq(['kept'])
      end
    end

    it 'stores the copy of a stored row with the same group number' do
      copy = post.custom_field_values.first.dup

      expect(copy.save).to be(true)
      expect(copy.reload.group_number).to eq(3)
    end

    it 'stores no group number for a row that a query read without its group number' do
      copy = post.custom_field_values.select(:id, :custom_field_id, :custom_field_slug, :value).first.dup

      expect(copy.save).to be(true)
      expect(copy.reload.group_number).to be_nil
    end

    # A copy is a new row, and a new row is always validated. A stored row can hold a group number
    # that is invalid for a new row, such as a negative number from an earlier release.
    it 'the save of the copy fails for a stored row that holds a negative group number' do
      row = post.custom_field_values.first
      row.update_column(:group_number, -1) # rubocop:disable Rails/SkipsModelValidations
      copy = row.reload.dup

      expect(copy.save).to be(false)
      expect(copy.errors[:base]).to eq([copy.group_number_refusal])
    end

    it 'the save of the copy fails for a stored row that holds a group number above 2147483647' do
      row = post.custom_field_values.first
      store_wide_group_number(row)
      copy = row.reload.dup

      expect(copy.save).to be(false)
      expect(copy.errors[:base]).to eq([copy.group_number_refusal])
    end
  end

  # The group number type has a 4-byte range on each database. SQLite and a bigint column can hold a
  # larger number. The examples show what Rails does with such a number.
  describe 'a group number outside the range of the type' do
    let(:row) { post.custom_field_values.first }

    before { post.set_field_value('note', 'kept', group_number: 1) }

    [2_147_483_648, -2_147_483_649].each do |number|
      it "update_column, update_all and insert_all raise ActiveModel::RangeError for #{number}" do
        attrs = { custom_field_id: row.custom_field_id, custom_field_slug: 'note', value: 'bulk', group_number: number }

        expect { row.update_column(:group_number, number) } # rubocop:disable Rails/SkipsModelValidations
          .to raise_error(ActiveModel::RangeError)
        expect { described_class.where(id: row.id).update_all(group_number: number) } # rubocop:disable Rails/SkipsModelValidations
          .to raise_error(ActiveModel::RangeError)
        expect { described_class.insert_all([attrs]) } # rubocop:disable Rails/SkipsModelValidations
          .to raise_error(ActiveModel::RangeError)
        expect(row.reload.group_number).to eq(1)
        expect(described_class.where(value: 'bulk')).to be_empty
      end

      it "update_attribute and save(validate: false) raise ActiveModel::RangeError for #{number}" do
        expect { row.update_attribute(:group_number, number) } # rubocop:disable Rails/SkipsModelValidations
          .to raise_error(ActiveModel::RangeError)
        row.reload.group_number = number
        expect { row.save(validate: false) }.to raise_error(ActiveModel::RangeError)
        expect(row.reload.group_number).to eq(1)
      end

      context "with a stored row that holds #{number}" do
        before { store_wide_group_number(row, number) }

        it 'finds no row with where, find_by or get_field_values' do
          expect(post.custom_field_values.where(group_number: number)).to be_empty
          expect(post.custom_field_values.find_by(group_number: number)).to be_nil
          expect(post.get_field_values('note', number)).to eq([])
        end

        it 'finds the row with an SQL string, and where.not excludes no row' do
          expect(post.custom_field_values.where('group_number = ?', number)).to eq([row])
          expect(post.custom_field_values.where.not(group_number: number)).to eq([row])
        end

        it 'reads the value of the row through a loaded association' do
          post.custom_field_values.load

          expect(post.get_field_values('note', number)).to eq(['kept'])
        end

        it 'reads the stored number and updates the value of the row' do
          expect(row.reload.group_number).to eq(number)
          expect(row.update(value: 'new')).to be(true)
        end
      end
    end
  end

  # A caller can run the two methods inside its own transaction, rescue their error and commit. The
  # stored values must stay.
  # - set_field_values deletes the stored values before a row fails its validation. A savepoint
  #   rolls that delete back.
  # - set_field_value validates the group number before its delete, so it runs no DELETE.
  # custom_field_value_rejection_spec.rb covers a set_field_value call that fails after its delete.
  describe 'a failed call inside a transaction of the caller' do
    before { post.set_field_value('note', 'kept', group_number: 1) }

    it 'set_field_value runs no DELETE, and the stored value stays, when the caller rescues its error' do
      deletes = sql_queries(matching: /\A\s*DELETE\b/i) do
        ActiveRecord::Base.transaction do
          post.set_field_value('note', 'new', group_number: '1abc')
        rescue ActiveRecord::RecordInvalid
          nil
        end
      end

      expect(deletes).to be_empty
      expect(post.reload.get_field_values('note', 1)).to eq(['kept'])
    end

    it 'set_field_values keeps the stored values when the caller rescues its error' do
      ActiveRecord::Base.transaction do
        post.set_field_values({ '0' => { 'note' => { group_number: -1, values: ['new'] } } })
      rescue ActiveRecord::RecordInvalid
        nil
      end

      expect(post.reload.get_field_values('note', 1)).to eq(['kept'])
    end

    # Rails 7.2 and later open no savepoint before the first statement in the transaction of the
    # caller. So the two methods run SELECT 1 first (see _cama_run_statement_in_caller_transaction).
    context 'when no statement ran in the transaction of the caller' do
      let(:field_id) { post.get_field_object('note').id }

      before { field_id }

      # Opens a transaction of the caller and runs the block as its first code. Returns the
      # SAVEPOINT and ROLLBACK TO SAVEPOINT statements that the block ran.
      def savepoint_statements_in_a_new_caller_transaction
        sql_queries(matching: /\A(ROLLBACK TO )?SAVEPOINT/, include_transactions: true) do
          ActiveRecord::Base.transaction do
            yield
          rescue ActiveRecord::RecordInvalid, ActiveModel::RangeError
            nil
          end
        end
      end

      def expect_a_rollback_to_a_savepoint_of_the_writer(statements)
        savepoints = statements.grep(/\ASAVEPOINT/)

        expect(savepoints.size).to eq(2)
        expect(statements.last).to eq("ROLLBACK TO #{savepoints.last}")
        expect(post.reload.get_field_values('note', 1)).to eq(['kept'])
      end

      it 'rolls a failed set_field_value back to its own savepoint' do
        statements = savepoint_statements_in_a_new_caller_transaction do
          post.set_field_value('note', %w[first second], field_id: field_id, group_number: 1, order: 2**64)
        end

        expect_a_rollback_to_a_savepoint_of_the_writer(statements)
      end

      # A SELECT 1 that the query cache answers does not reach the database, and Rails then opens no
      # savepoint. So SELECT 1 runs with the cache off.
      it 'rolls a failed call back to its own savepoint when the query cache holds SELECT 1' do
        statements = ActiveRecord::Base.cache do
          ActiveRecord::Base.connection.select_value('SELECT 1')
          savepoint_statements_in_a_new_caller_transaction do
            post.set_field_value('note', %w[first second], field_id: field_id, group_number: 1, order: 2**64)
          end
        end

        expect_a_rollback_to_a_savepoint_of_the_writer(statements)
      end

      it 'rolls a failed set_field_values back to its own savepoint' do
        statements = savepoint_statements_in_a_new_caller_transaction do
          post.set_field_values({ '0' => { 'note' => { group_number: -1, values: ['new'] } } })
        end

        expect_a_rollback_to_a_savepoint_of_the_writer(statements)
      end
    end

    # Rails 8.1 can give the connection pool a transaction isolation level. Rails then raises an
    # error for a savepoint, so the two methods ask for none and run in the transaction of the
    # caller.
    #
    # The examples stub pool_transaction_isolation_level (intended). The real API,
    # ActiveRecord.with_transaction_isolation_level, raises an error inside the transaction of an
    # example.
    context 'when the pool has an isolation level' do
      before do
        base = ActiveRecord::Base
        skip 'This Rails has no pool isolation level' unless base.respond_to?(:pool_transaction_isolation_level)

        allow(base).to receive(:pool_transaction_isolation_level).and_return(:read_committed)
      end

      # Returns the SAVEPOINT statements that the block runs inside a transaction of the caller. The
      # caller runs a query first (post.reload), which opens that transaction as a savepoint inside
      # the transaction of the example. The collector starts after it.
      def savepoints_inside_a_caller_transaction(&block)
        ActiveRecord::Base.transaction do
          post.reload
          sql_queries(matching: /SAVEPOINT/, include_transactions: true, &block)
        end
      end

      it 'loses the old values and keeps the new rows before the error, when the caller rescues the error' do
        payload = { '0' => { 'note' => { group_number: 0, values: ['fresh'] } },
                    '1' => { 'note' => { group_number: -1, values: ['new'] } } }

        ActiveRecord::Base.transaction do
          post.set_field_values(payload)
        rescue ActiveRecord::RecordInvalid
          nil
        end

        expect(post.reload.get_field_values('note', 1)).to eq([])
        expect(post.get_field_values('note', 0)).to eq(['fresh'])
      end

      # With no savepoint, a rescued error does not roll back a delete of the call. The delete reads
      # '1abc' as group 1. So the value of group 1 stays only because set_field_value validates the
      # group number before the delete.
      it 'set_field_value keeps the stored value when the caller rescues its group number error' do
        ActiveRecord::Base.transaction do
          post.set_field_value('note', 'new', group_number: '1abc')
        rescue ActiveRecord::RecordInvalid
          nil
        end

        expect(post.reload.get_field_values('note', 1)).to eq(['kept'])
      end

      # The failed call left an unsaved row in the association of the post. set_field_values removes
      # it, so the next save of the post stores no row of the failed call.
      it 'saves the record after an error that the caller rescues' do
        ActiveRecord::Base.transaction do
          post.set_field_values({ '0' => { 'note' => { group_number: -1, values: ['new'] } } })
        rescue ActiveRecord::RecordInvalid
          nil
        end

        expect(post.update(title: 'Saved')).to be(true)
        expect(described_class.where(custom_field_slug: 'note')).to be_empty
      end

      # The post save of the admin is such a caller. It does not rescue the error, so its whole
      # transaction rolls back.
      it 'keeps the stored values when the caller does not rescue the error' do
        expect do
          ActiveRecord::Base.transaction do
            post.set_field_values({ '0' => { 'note' => { group_number: -1, values: ['new'] } } })
          end
        end.to raise_error(ActiveRecord::RecordInvalid)

        expect(post.reload.get_field_values('note', 1)).to eq(['kept'])
      end

      it 'rolls back its delete after an error when the caller has no transaction' do
        expect { post.set_field_values({ '0' => { 'note' => { group_number: -1, values: ['new'] } } }) }
          .to raise_error(ActiveRecord::RecordInvalid)

        expect(post.reload.get_field_values('note', 1)).to eq(['kept'])
      end

      it 'opens no savepoint in set_field_value, and the call stores its value' do
        statements = savepoints_inside_a_caller_transaction { post.set_field_value('note', 'new', group_number: 2) }

        expect(statements).to be_empty
        expect(post.reload.get_field_values('note', 2)).to eq(['new'])
      end

      # The two methods run SELECT 1 before their transaction only when they ask for a savepoint.
      it 'runs no SELECT 1 before the transaction of set_field_value' do
        probes = sql_queries(matching: /\ASELECT 1\z/) do
          ActiveRecord::Base.transaction { post.set_field_value('note', 'new', group_number: 2) }
        end

        expect(probes).to be_empty
      end

      it 'opens no savepoint in set_field_values, and the call stores its values' do
        statements = savepoints_inside_a_caller_transaction do
          post.set_field_values({ '0' => { 'note' => { group_number: 2, values: ['new'] } } })
        end

        expect(statements).to be_empty
        expect(post.reload.get_field_values('note', 2)).to eq(['new'])
      end
    end
  end

  # The rollback of a failed call restores the database, but the custom_field_values association
  # still holds the unsaved rows of the call. The two methods reset the association. The record then
  # reads the stored values, and its next save stores no row of the failed call.
  describe 'the record after a failed call' do
    let(:stored_values) { described_class.where(custom_field_slug: 'note').pluck(:value) }

    before { post.set_field_value('note', 'kept', group_number: 1) }

    it 'reads the stored values and saves after a group number error of set_field_values' do
      payload = { '0' => { 'note' => { group_number: 0, values: ['fresh'] } },
                  '1' => { 'note' => { group_number: -1, values: ['new'] } } }

      expect { post.set_field_values(payload) }.to raise_error(ActiveRecord::RecordInvalid)

      expect(post.get_field_values('note', 1)).to eq(['kept'])
      expect(post.get_field_values('note', 0)).to eq([])
      expect(post.update(title: 'Saved')).to be(true)
      expect(stored_values).to eq(['kept'])
    end

    it 'reads the stored values after an ActiveModel::RangeError of set_field_values' do
      payload = { '0' => { 'note' => { values: ['fresh'] }, 'unknown' => { id: 2**64, values: ['x'] } } }

      expect { post.set_field_values(payload) }.to raise_error(ActiveModel::RangeError)

      expect(post.get_field_values('note', 1)).to eq(['kept'])
      expect(post.get_field_values('note', 0)).to eq([])
    end

    # A timeout of the caller can raise an exception that is not a StandardError.
    # NotImplementedError is the example of such an exception here.
    it 'stores no row of the call after an exception of set_field_value that is not a StandardError' do
      values = ['first']
      values.define_singleton_method(:each) do |&block|
        super(&block)
        raise NotImplementedError
      end

      expect { post.set_field_value('note', values, group_number: 2) }.to raise_error(NotImplementedError)

      expect(post.save).to be(true)
      expect(stored_values).to eq(['kept'])
    end

    # For ActiveRecord::Rollback, Rails rolls the transaction back and raises no error.
    # set_field_value then returns nil.
    it 'stores no row of the call when the call rolls back with ActiveRecord::Rollback' do
      values = ['first']
      values.define_singleton_method(:each) do |&block|
        super(&block)
        raise ActiveRecord::Rollback
      end

      expect(post.set_field_value('note', values, group_number: 2)).to be_nil

      expect(post.save).to be(true)
      expect(stored_values).to eq(['kept'])
    end

    # A before_commit callback runs after the block of set_field_value. When it raises
    # ActiveRecord::Rollback, Rails rolls the transaction back, and set_field_value returns nil.
    it 'stores no row of the call when the commit of the call rolls back' do
      allow_any_instance_of(described_class).to receive(:before_committed!).and_raise(ActiveRecord::Rollback)

      expect(post.set_field_value('note', 'new', group_number: 2)).to be_nil

      # Remove the stub before the save of the post. With the stub, that save rolls back too, and the
      # example cannot see whether it stores a row of the failed call.
      allow_any_instance_of(described_class).to receive(:before_committed!).and_call_original
      expect(post.save).to be(true)
      expect(stored_values).to eq(['kept'])
    end

    # After a throw, Rails can commit the work that the call did before the throw. So the example
    # checks only that the next save of the post stores no new row.
    it 'stores no row of the call after a throw out of set_field_values' do
      allow_any_instance_of(described_class).to receive(:save!).and_throw(:stop)

      expect { post.set_field_values({ '0' => { 'note' => { group_number: 2, values: ['new'] } } }) }
        .to throw_symbol(:stop)

      expect { post.save }.not_to change(described_class, :count)
    end

    # The reset of the association also removes the unsaved rows that the caller built before the
    # call. The two methods put them back, so the next save of the record stores them.
    context 'with a row that the caller built before the call' do
      let!(:built) do
        post.custom_field_values.build(custom_field_id: post.get_field_object('note').id,
                                       custom_field_slug: 'note', value: 'built', group_number: 5)
      end

      it 'keeps that row after an error of set_field_value' do
        expect { post.set_field_value('note', 'new', order: 2**64) }.to raise_error(ActiveModel::RangeError)

        expect(post.save).to be(true)
        expect(stored_values).to contain_exactly('kept', 'built')
      end

      it 'keeps that row after a group number error of set_field_value' do
        expect { post.set_field_value('note', 'new', group_number: -1) }.to raise_error(ActiveRecord::RecordInvalid)

        expect(post.save).to be(true)
        expect(stored_values).to contain_exactly('kept', 'built')
      end

      it 'keeps that row after a group number error of set_field_values' do
        payload = { '0' => { 'note' => { group_number: -1, values: ['new'] } } }

        expect { post.set_field_values(payload) }.to raise_error(ActiveRecord::RecordInvalid)

        expect(post.save).to be(true)
        expect(stored_values).to contain_exactly('kept', 'built')
      end

      it 'keeps that row unsaved in the association, and the record does not read it' do
        expect { post.set_field_value('note', 'new', group_number: -1) }.to raise_error(ActiveRecord::RecordInvalid)

        expect(post.custom_field_values.target).to include(built)
        expect(built).to be_new_record
        expect(post.get_field_values('note', 5)).to eq([])
      end
    end
  end

  # set_field_value deletes the stored values with an SQL DELETE, which leaves the deleted rows in a
  # loaded association, where get_field_values reads them. The method removes them from a loaded
  # association, so the record no longer reads them.
  describe 'a loaded association after set_field_value' do
    let(:value_rows) { /\ASELECT\b.*custom_fields_relationships/im }

    before do
      post.set_field_value('note', 'old', group_number: 1)
      post.set_field_value('note', 'other', group_number: 2)
    end

    context 'when the association is loaded' do
      before { post.custom_field_values.load }

      it 'reads the new value and not the deleted value' do
        post.set_field_value('note', 'new', group_number: 1)

        expect(post.get_field_values('note', 1)).to eq(['new'])
        expect(post.get_field_value('note', nil, 1)).to eq('new')
      end

      it 'reads each value of a new list' do
        post.set_field_value('note', %w[first second], group_number: 1)

        expect(post.get_field_values('note', 1)).to eq(%w[first second])
      end

      it 'reads no value after a call with an empty list' do
        post.set_field_value('note', [], group_number: 1)

        expect(post.get_field_values('note', 1)).to eq([])
      end

      it 'keeps the association loaded with the rows of the other groups' do
        post.set_field_value('note', 'new', group_number: 1)

        expect(post.custom_field_values).to be_loaded
        expect(post.custom_field_values.target.map(&:value)).to eq(%w[other new])
        expect(post.custom_field_values.target).to all(be_persisted)
      end

      it 'keeps an unsaved row that the caller built, and the next save stores it' do
        built = post.custom_field_values.build(custom_field_id: post.get_field_object('note').id,
                                               custom_field_slug: 'note', value: 'built', group_number: 5)

        post.set_field_value('note', 'new', group_number: 1)

        expect(post.custom_field_values.target).to include(built)
        expect(post.save).to be(true)
        expect(described_class.where(custom_field_slug: 'note').pluck(:value)).to contain_exactly('other', 'new',
                                                                                                  'built')
      end

      it 'reads the stored and the new value after a call that does not clear the stored values' do
        post.set_field_value('note', 'new', group_number: 1, clear: false)

        expect(post.get_field_values('note', 1)).to eq(%w[old new])
      end

      # set_field_values deletes through the association, which empties a loaded association.
      it 'reads the new values only after set_field_values' do
        post.set_field_values({ '0' => { 'note' => { group_number: 1, values: ['new'] } } })

        expect(post.get_field_values('note', 1)).to eq(['new'])
        expect(post.get_field_values('note', 2)).to eq([])
      end

      it 'reads the new value after get_field_values_hash loaded the association' do
        record = CamaleonCms::Post.find(post.id)
        record.get_field_values_hash

        record.set_field_value('note', 'new', group_number: 1)

        expect(record.get_field_values('note', 1)).to eq(['new'])
      end
    end

    it 'runs no SELECT on the value rows and does not load the association when it is not loaded' do
      record = CamaleonCms::Post.find(post.id)

      selects = sql_queries(matching: value_rows) { record.set_field_value('note', 'new', group_number: 1) }

      expect(selects).to be_empty
      expect(record.custom_field_values).not_to be_loaded
      expect(record.get_field_values('note', 1)).to eq(['new'])
    end
  end

  # A callback of a row can raise ActiveRecord::Rollback before Rails stores the row. Rails then
  # stores nothing and raises no error, so set_field_value goes on (intended). The stub of valid? is
  # such a callback here.
  describe 'a callback of a value row that raises ActiveRecord::Rollback' do
    it 'raises no error, and the row stays in the association as an unsaved row' do
      allow_any_instance_of(described_class).to receive(:valid?).and_raise(ActiveRecord::Rollback)

      row = post.set_field_value('note', 'new', group_number: 2)

      expect(row).to be_new_record
      expect(post.custom_field_values.target).to include(row)
    end
  end

  # _cama_write_field_values runs the block of set_field_value and set_field_values. It resets the
  # association only after a failed call. A block that returns nil or false is not a failed call.
  describe 'a block of _cama_write_field_values that returns nil or false' do
    [nil, false].each do |value|
      it "returns #{value.inspect} and keeps the association loaded" do
        post.custom_field_values.load

        expect(post.send(:_cama_write_field_values) { value }).to be(value)
        expect(post.custom_field_values).to be_loaded
      end
    end
  end

  it 'gives the group number error in each language of the admin' do
    files = Dir[CamaleonCms::Engine.root.join('config/locales/camaleon_cms/admin/*.yml')]
    locales = files.map { |file| YAML.load_file(file).keys.first }
    expect(locales).to include('en', 'es', 'zh-CN')
    english = I18n.t('camaleon_cms.admin.custom_field.message.group_number_invalid',
                     locale: :en, slug: 'note', max: described_class::MAX_GROUP_NUMBER)

    locales.each do |locale|
      row = described_class.new(custom_field_slug: 'note', group_number: -1)
      I18n.with_locale(locale) { row.valid? }

      expect(row.errors[:base].first).to include("'note'", '2147483647'), locale
      expect(row.errors[:base].first).not_to eq(english), locale unless locale == 'en'
    end
  end

  # A plugin can pass raw request params to set_field_values, so a slug can hold the placeholder
  # syntax of I18n. A language with no message uses the English message, and the slug must show in
  # it as sent. No locale file has the locale xx.
  it 'shows a slug with the placeholder syntax of I18n in the English message of a language with no message' do
    slug = '100%{x} a%%b' # rubocop:disable Style/FormatStringToken
    row = described_class.new(custom_field_slug: slug, group_number: -1)
    refusal = "The group number of the '#{slug}' field must be a whole number from 0 to 2147483647."

    I18n.with_locale(:xx) { row.valid? }

    expect(row.errors[:base]).to eq([refusal])
  end

  it 'updates the value of a stored row that holds a negative group number' do
    post.set_field_value('note', 'old')
    row = post.custom_field_values.first
    row.update_column(:group_number, -1) # rubocop:disable Rails/SkipsModelValidations

    expect(row.reload.update(value: 'new')).to be(true)
  end

  it 'refuses a negative group number that a caller writes to a stored row' do
    post.set_field_value('note', 'old')
    row = post.custom_field_values.first

    expect(row.update(group_number: -1)).to be(false)
    expect(row.reload.group_number).to eq(0)
  end
end
