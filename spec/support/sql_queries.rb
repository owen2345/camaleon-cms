# frozen_string_literal: true

# Collect the SQL a block issues, optionally only the statements matching `matching`: a pattern, or a list of
# patterns a statement must all match. Skips SCHEMA/TRANSACTION noise. Shared by specs that assert query
# shape or N+1 behaviour.
module SqlQueriesHelper
  # What precedes a statement's opening: whitespace, or a comment such as a query log tag
  STATEMENT_LEAD = %r{\A\s*(?:/\*.*?\*/\s*)*}m
  # The metas table, whatever the table name prefix and quoting, ending at a word boundary so a table whose
  # name only starts with metas is not the metas table
  METAS_TABLE = /["'`]?\w*metas\b/i
  # A SELECT against the metas table: its opening and the table it reads. Two patterns, each a quick scan,
  # where one bridging them with .* ran back over the whole statement, a long eager-loading IN list included.
  METAS_SELECT = [/#{STATEMENT_LEAD}SELECT\b/i, /\bFROM\s+#{METAS_TABLE}/i].freeze
  # An UPDATE of the metas table, which it names right after its opening
  METAS_UPDATE = /#{STATEMENT_LEAD}UPDATE\s+#{METAS_TABLE}/i

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

  # The UPDATEs a block issues against the metas table: the writes that store a meta row again
  def metas_updates(&block)
    sql_queries(matching: METAS_UPDATE, &block)
  end
end

RSpec.configure { |config| config.include SqlQueriesHelper }
