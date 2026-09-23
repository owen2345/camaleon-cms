# frozen_string_literal: true

# A record's options live in one meta row (`_default`) holding a JSON object. A row that holds anything
# else -- legacy data, a corrupt import -- made every reader and writer raise (`get_option` called
# `key?` on a String, `set_option` called `with_indifferent_access`), so the record's pages 500 and
# nothing could repair it. The options of such a row read as empty and a write starts from empty,
# replacing the row; the row itself is left alone until then.
RSpec.describe CamaleonCms::Metas, type: :model do
  let(:post_type) { installed_post_type }
  let(:record) { create(:post, post_type: post_type) }

  describe 'an options row that is not a JSON object' do
    %w[corrupt [] 42].each do |stored|
      it "reads as empty when the row holds #{stored}" do
        record.set_meta('_default', stored)
        expect(record.options).to eq({})
        stored_record = record.reload

        expect(stored_record.options).to eq({})
        expect(stored_record.get_option('status_default', 'fallback')).to eq('fallback')
        expect(stored_record.get_option('status_default')).to be_nil
      end
    end

    # A JSON string is not an object even when its text is one: the options read as empty rather than
    # parsed a second time, as no writer stores them encoded twice.
    it 'reads as empty when the row holds a JSON string whose text is an object' do
      record.set_meta('_default', { 'status_default' => 'published' }.to_json.to_json)
      stored_record = CamaleonCms::Post.find(record.id)

      expect([record.options, stored_record.options]).to all(eq({}))
      expect(stored_record.get_option('status_default', 'fallback')).to eq('fallback')
    end

    it 'takes a written option, starting from empty' do
      record.set_meta('_default', 'corrupt')
      stored_record = record.reload

      stored_record.set_option('status_default', 'published')

      expect(record.reload.get_option('status_default')).to eq('published')
      expect(record.reload.options.keys).to eq(['status_default'])
    end

    it 'leaves the row as it is until an option is written' do
      record.set_meta('_default', 'corrupt')

      record.reload.options

      expect(record.reload.get_meta('_default')).to eq('corrupt')
    end
  end

  describe 'an option write that raises' do
    # The writers change the options the record holds before storing them; a write that fails puts them
    # back, so the record keeps reading what is stored.
    it 'leaves the options the record holds as they were stored' do
      record.set_option('status_default', 'published')
      allow(record).to receive(:meta_row).and_raise(ActiveRecord::StatementInvalid, 'write failed')

      expect { record.set_option('status_default', 'draft') }.to raise_error(ActiveRecord::StatementInvalid)
      expect { record.set_options(color: 'red') }.to raise_error(ActiveRecord::StatementInvalid)
      expect { record.delete_option('status_default') }.to raise_error(ActiveRecord::StatementInvalid)

      expect(record.options).to eq(CamaleonCms::Post.find(record.id).options)
      expect([record.get_option('status_default'), record.options.key?('color')]).to eq(['published', false])
    end

    # The writers set or delete whole options on a copy, so a write that raises leaves a nested value as it was
    # stored, the hash taken before the write included.
    it 'leaves a nested value as it was stored' do
      record.set_option('layout', { 'columns' => 2 })
      nested = record.options[:layout]
      allow(record).to receive(:meta_row).and_raise(ActiveRecord::StatementInvalid, 'write failed')

      expect { record.set_option('layout', { 'columns' => 3 }) }.to raise_error(ActiveRecord::StatementInvalid)

      expect([record.get_option('layout'), nested]).to eq([{ 'columns' => 2 }, { 'columns' => 2 }])
    end
  end

  # An option write copied the options down to every value they hold, though the writers only set or delete
  # whole options: the values a write leaves alone are shared with the copy, not copied again on every write.
  it 'copies the options an option write changes, not the values they hold' do
    record.set_option('layout', { 'columns' => 2 })
    nested = record.options[:layout]
    expect(nested).not_to receive(:deep_dup)

    record.set_option('status_default', 'published')

    expect(record.options[:layout]).to equal(nested)
  end

  describe 'a container that is not a set of fields' do
    it 'is refused by set_metas and writes nothing' do
      expect { record.set_metas([%w[planted v]]) }.to raise_error(CamaleonCms::Metas::InvalidContainer)
      expect(record.reload.get_meta('planted')).to be_nil
    end

    it 'is refused by set_options and writes nothing' do
      expect { record.set_options(%w[status_default]) }.to raise_error(CamaleonCms::Metas::InvalidContainer)
      expect { record.set_options('status_default=published') }.to raise_error(CamaleonCms::Metas::InvalidContainer)
      expect(record.reload.get_option('status_default')).to be_nil
    end

    it 'still accepts a hash, request parameters, nil and blank' do
      record.set_metas(nil)
      record.set_metas({})
      record.set_options(nil)
      record.set_options([])
      record.set_metas('a' => '1')
      record.set_options(ActionController::Parameters.new(b: '2'))

      expect(record.reload.get_meta('a')).to eq(1)
      expect(record.reload.get_option('b')).to eq(2)
    end
  end
end
