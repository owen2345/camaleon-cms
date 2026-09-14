# frozen_string_literal: true

# A record's options live in one meta row (`_default`) holding a JSON object. A row that holds anything
# else -- legacy data, a corrupt import -- made every reader and writer raise (`get_option` called
# `key?` on a String, `set_option` called `with_indifferent_access`), so the record's pages 500 and
# nothing could repair it. The options of such a row read as empty and a write starts from empty,
# replacing the row; the row itself is left alone until then.
RSpec.describe CamaleonCms::Metas, type: :model do
  let(:site) { CamaleonCms::Site.first }
  let(:post_type) { site.post_types.find_by(slug: 'post') }
  let(:record) { create(:post, post_type: post_type) }

  describe 'an options row that is not a JSON object' do
    %w[corrupt [] 42].each do |stored|
      it "reads as empty when the row holds #{stored}" do
        record.set_meta('_default', stored)
        stored_record = record.reload

        expect(stored_record.options).to eq({})
        expect(stored_record.get_option('status_default', 'fallback')).to eq('fallback')
        expect(stored_record.get_option('status_default')).to be_nil
      end
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
