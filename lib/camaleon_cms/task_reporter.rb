# frozen_string_literal: true

module CamaleonCms
  # Output seam for operator-run repair tasks: logs for the record AND prints to
  # stdout, because an operator runs these from a terminal, where Rails.logger
  # writes to a file they are not watching — a logger-only task looks like a
  # no-op. Shared so the reporting rule cannot drift between the repair tasks.
  module TaskReporter
    def self.call(msg)
      Rails.logger.info(msg)
      puts msg # rubocop:disable Rails/Output -- terminal output for the operator is the point
    end
  end
end
