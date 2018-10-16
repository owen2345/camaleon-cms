### https://github.com/thoughtbot/capybara-webkit/issues/1065#issuecomment-411116972

module Capybara
  module Helpers
    class << self

      alias_method :normalize_whitespace_with_warning, :normalize_whitespace

      def normalize_whitespace(*args)
        silence_warnings do
          normalize_whitespace_with_warning(*args)
        end
      end

    end
  end
end
