# frozen_string_literal: true
module CamaleonCms
  class ApplicationService
    def initialize(*args); end

    class << self
      # @see #initialize
      def call(*args)
        new(*args).call
      end
    end

    private

    # @param message (String)
    # @param kind (:info|:warn|:error)
    # @param backtrace (Array)
    def log(message, kind = :info, backtrace = nil)
      message = "#{self.class.name} => #{message}"
      message = ([message] + backtrace.map(&:to_s)).join($RS) if backtrace
      message = message.cama_log_style if kind == :error
      Rails.logger.send(kind, message)
    end

    def run_query(sql)
      ActiveRecord::Base.connection.exec_query(sql)
    end
  end
end
