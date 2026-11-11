# frozen_string_literal: true

# Rails 7.1 and later connect a new connection at its first statement, and reconnect a lost one there.
# They do it only while no open transaction is dirty. set_field_values marks a restartable transaction
# of the caller as dirty, so it must begin that transaction first.
# The example runs outside the transaction of the test, because that transaction connects the
# connection. Its post is not in the database, so the call deletes no stored value.
RSpec.describe CamaleonCms::CustomFieldsRelationship, type: :model do
  self.use_transactional_tests = false

  let(:post) { CamaleonCms::Post.instantiate('id' => 0) }

  # The transaction of the caller is an outermost transaction, as in each caller outside the tests.
  it 'connects a new connection, and rolls a failed set_field_values back to its own savepoint' do
    ActiveRecord::Base.connection_pool.disconnect!

    statements = sql_queries(matching: /\A(ROLLBACK TO )?SAVEPOINT/, include_transactions: true) do
      ActiveRecord::Base.transaction do
        post.set_field_values({ '0' => { 'note' => { group_number: -1, values: [] } } })
      rescue ActiveRecord::RecordInvalid
        nil
      end
    end

    expect(statements).to eq(['SAVEPOINT active_record_1', 'ROLLBACK TO SAVEPOINT active_record_1'])
  end
end
