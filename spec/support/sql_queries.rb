# frozen_string_literal: true

# Collect the SQL a block issues, optionally only statements matching `matching`.
# Skips SCHEMA/TRANSACTION noise. Shared by specs that assert query shape or N+1 behaviour.
module SqlQueriesHelper
  def sql_queries(matching: nil)
    queries = []
    sub = ActiveSupport::Notifications.subscribe('sql.active_record') do |*args|
      payload = args.last
      next if payload[:name].to_s.match?(/SCHEMA|TRANSACTION/i)

      queries << payload[:sql] if matching.nil? || payload[:sql].match?(matching)
    end
    yield
    queries
  ensure
    ActiveSupport::Notifications.unsubscribe(sub)
  end

  # The SELECTs a block issues against the metas table, whatever the table name prefix and whatever
  # whitespace or comment, such as a query log tag, precedes them: the shape every spec that pins how often
  # a record's metas are read counts. A table whose name only starts with metas is not the metas table.
  def metas_selects(&block)
    sql_queries(matching: %r{\A\s*(?:/\*.*?\*/\s*)*SELECT\b.*\bFROM\s+["'`]?\w*metas\b}im, &block)
  end
end

RSpec.configure { |config| config.include SqlQueriesHelper }
