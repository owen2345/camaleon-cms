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
    selects = []
    subscription = ActiveSupport::Notifications.subscribe('sql.active_record') do |*, payload|
      selects << payload[:sql] if payload[:sql].start_with?('SELECT') && payload[:sql].include?('"metas"')
    end

    loaded.set_meta('probe', 'written')

    ActiveSupport::Notifications.unsubscribe(subscription)
    expect(selects).to be_empty
    expect(CamaleonCms::PostType.find(post_type.id).get_meta('probe')).to eq('written')
  end

  it 'reads the same row from eager-loaded metas as from the database' do
    expect(CamaleonCms::PostType.includes(:metas).find(post_type.id).get_meta('probe'))
      .to eq(CamaleonCms::PostType.find(post_type.id).get_meta('probe'))
  end
end
