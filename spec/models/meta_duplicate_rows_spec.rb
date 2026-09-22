# frozen_string_literal: true

# Nothing stops two meta rows from sharing a key (no unique index). set_meta must update the row that
# get_meta reads, the lowest id whether it comes from the database or from eager-loaded metas, or the
# write is lost on the next load. SQLite's reverse_unordered_selects makes a lookup without an ORDER BY
# return the other row, as PostgreSQL may.
RSpec.describe CamaleonCms::Meta, type: :model do
  let(:post_type) { create(:post_type) }

  around do |example|
    connection = ActiveRecord::Base.connection
    connection.execute('PRAGMA reverse_unordered_selects = ON')
    example.run
  ensure
    connection.execute('PRAGMA reverse_unordered_selects = OFF')
  end

  before do
    post_type.metas.create!(key: 'probe', value: 'first')
    post_type.metas.create!(key: 'probe', value: 'second')
  end

  it 'updates the row that later reads return' do
    CamaleonCms::PostType.find(post_type.id).set_meta('probe', 'written')

    expect(CamaleonCms::PostType.find(post_type.id).get_meta('probe')).to eq('written')
  end

  it 'updates the row that later reads return from eager-loaded metas, without querying for it' do
    loaded = CamaleonCms::PostType.includes(:metas).find(post_type.id)

    selects = metas_selects { loaded.set_meta('probe', 'written') }

    expect(selects).to be_empty
    expect(CamaleonCms::PostType.find(post_type.id).get_meta('probe')).to eq('written')
  end

  # A meta built on a saved record for a key it stores is a second row waiting for the next save: a write still
  # updates the stored row, which every later read takes, or it is lost once the built meta is saved beside it.
  it 'updates the stored row, not a meta built for the same key and not saved yet' do
    scopes = { 'eager-loaded' => CamaleonCms::PostType.includes(:metas), 'queried' => CamaleonCms::PostType }
    scopes.each do |name, scope|
      record = scope.find(post_type.id)
      record.metas.build(key: 'probe', value: 'built')
      record.set_meta('probe', "written on the #{name} record")
      record.save!

      expect(CamaleonCms::PostType.find(post_type.id).get_meta('probe')).to eq("written on the #{name} record")
    end
  end

  it 'reads the same row from eager-loaded metas as from the database' do
    expect(CamaleonCms::PostType.includes(:metas).find(post_type.id).get_meta('probe'))
      .to eq(CamaleonCms::PostType.find(post_type.id).get_meta('probe'))
  end
end
