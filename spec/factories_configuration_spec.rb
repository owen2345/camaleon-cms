# frozen_string_literal: true

# The engine must not feed its spec/factories into the loading application: that auto-append
# (engine.rb, removed) aborted the boot of any path-gem host that defines a same-named factory
# (FactoryBot::DuplicateDefinitionError on :site), while released-gem hosts got a dangling path —
# spec/ is not shipped in the packaged gem. This suite (whose Rails.root is spec/dummy) configures
# the factory path itself in rails_helper instead.
RSpec.describe 'Factory definition paths' do # rubocop:disable RSpec/DescribeClass
  it 'contain only the path this suite configures, and the factories are loaded from it' do
    expect(FactoryBot.definition_file_paths).to eq([File.expand_path('factories', __dir__)])
    expect(FactoryBot.factories.registered?(:site)).to be true
    expect(FactoryBot.factories.registered?(:user)).to be true
  end
end
