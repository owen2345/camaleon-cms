# frozen_string_literal: true

# Collect the SQL a block issues, optionally only the statements matching `matching`: a pattern, or a list of
# patterns a statement must all match. Skips SCHEMA/TRANSACTION noise. Shared by specs that assert query
# shape or N+1 behaviour.
module SqlQueriesHelper
  # A SELECT against the metas table: its opening, after whatever whitespace or comment, such as a query log
  # tag, precedes it, and the table it reads, whatever the table name prefix, ending at a word boundary so a
  # table whose name only starts with metas is not the metas table. Two patterns, each a quick scan, where
  # one bridging them with .* ran back over the whole statement, a long eager-loading IN list included.
  METAS_SELECT = [%r{\A\s*(?:/\*.*?\*/\s*)*SELECT\b}im, /\bFROM\s+["'`]?\w*metas\b/i].freeze

  def sql_queries(matching: nil)
    patterns = Array(matching)
    queries = []
    sub = ActiveSupport::Notifications.subscribe('sql.active_record') do |*args|
      payload = args.last
      next if payload[:name].to_s.match?(/SCHEMA|TRANSACTION/i)

      queries << payload[:sql] if patterns.all? { |pattern| payload[:sql].match?(pattern) }
    end
    yield
    queries
  ensure
    ActiveSupport::Notifications.unsubscribe(sub)
  end

  # The SELECTs a block issues against the metas table: the shape every spec that pins how often a record's
  # metas are read counts.
  def metas_selects(&block)
    sql_queries(matching: METAS_SELECT, &block)
  end
end

RSpec.configure { |config| config.include SqlQueriesHelper }
