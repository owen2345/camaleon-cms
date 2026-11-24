# frozen_string_literal: true

module CamaleonCms
  # Helps code that opens a savepoint in a transaction of its caller, with
  # ActiveRecord::Base.transaction(requires_new: true).
  module CallerTransaction
    # Makes Rails open a real savepoint for the next requires_new transaction. A transaction is
    # restartable when it is joinable and no statement ran in it. In a restartable transaction of the
    # caller, Rails 7.1 and later open no savepoint: a failed block restarts that transaction. Then, on
    # SQLite with Rails 8.1, the caller can get an internal error of Rails, not the error of the block.
    #
    # So this method begins that transaction and marks it as dirty, as a statement does. Rails connects
    # a new connection, and reconnects a lost one, only while no open transaction is dirty. So the
    # method begins the transaction before dirty!. A call that runs a statement begins it anyway.
    # dirty! and materialize_transactions are internal APIs of Rails 7.1 to 8.1 (intended): the
    # alternative, a SELECT 1, costs a round trip. Rails 6.1 and 7.0 have no restartable? and always
    # open a savepoint.
    def self.force_savepoint
      ActiveRecord::Base.connection_pool.with_connection do |connection|
        transaction = connection.current_transaction
        next unless transaction.try(:restartable?)

        connection.materialize_transactions
        transaction.dirty!
      end
    end

    # Raises ActiveRecord::TransactionIsolationError when Rails permits no savepoint in the transaction of
    # the caller: the connection pool has a transaction isolation level (Rails 8.1). Rails raises that
    # error for the requires_new transaction too. But Rails then drops the connection of the caller, and
    # the transaction of the caller goes with it. After the error of this method, the caller keeps both.
    def self.require_savepoint!
      return unless ActiveRecord::Base.try(:pool_transaction_isolation_level)
      return unless ActiveRecord::Base.connection_pool.active_connection?&.transaction_open?

      raise ActiveRecord::TransactionIsolationError,
            'Camaleon CMS - Rails permits no savepoint while the connection pool has a transaction isolation level'
    end
  end
end
