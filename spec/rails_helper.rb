require 'spec_helper'

RSpec.configure do |config|
  # include support helpers
  config.include CurrentSpecHelper

  config.include FactoryBot::Syntax::Methods
  config.before do
    # clear CurrentRequest before each example to avoid leakage
    CurrentRequest.reset
  end
end
