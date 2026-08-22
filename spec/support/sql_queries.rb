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
end

RSpec.configure { |config| config.include SqlQueriesHelper }
