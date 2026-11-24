# frozen_string_literal: true

# Rails 8.1 permits no savepoint while the connection pool has a transaction isolation level. So
# CamaleonCms::CallerTransaction.require_savepoint! raises an error in a transaction of the caller. With
# no open transaction, Rails opens a real transaction with that level, and the method raises no error.
RSpec.describe CamaleonCms::CallerTransaction do
  describe '.require_savepoint!' do
    let(:pool) { ActiveRecord::Base.connection_pool }

    before do
      skip 'This Rails has no pool isolation level' unless pool.respond_to?(:pool_transaction_isolation_level)
      allow(pool).to receive(:pool_transaction_isolation_level).and_return(:read_committed)
    end

    # The transaction of the example is open on the connection.
    it 'raises ActiveRecord::TransactionIsolationError in an open transaction' do
      expect { described_class.require_savepoint! }
        .to raise_error(ActiveRecord::TransactionIsolationError, /Camaleon CMS/)
    end

    it 'raises no error when no transaction is open on the connection' do
      connection = instance_double(ActiveRecord::ConnectionAdapters::AbstractAdapter, transaction_open?: false)
      allow(pool).to receive(:active_connection?).and_return(connection)

      expect { described_class.require_savepoint! }.not_to raise_error
    end

    it 'raises no error when the thread has no connection' do
      allow(pool).to receive(:active_connection?).and_return(nil)

      expect { described_class.require_savepoint! }.not_to raise_error
    end
  end
end
