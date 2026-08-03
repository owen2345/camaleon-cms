# frozen_string_literal: true

require 'rails_helper'

# Every bundled theme exists twice: once as gem content under app/apps/themes, and once as a
# copy the dummy app actually loads under spec/dummy/app/apps/themes. The asset trees diverge on
# purpose (the dummy app carries no images), but the Ruby helpers are duplicated verbatim and
# have to be edited in both places — #1225 had to patch the same camaleon_first hook twice, and
# nothing would have caught it had one copy been missed. The spec suite runs against the dummy
# copy, so a fix applied only to the gem copy ships broken while the suite stays green.
# rubocop:disable RSpec/DescribeClass -- the subject is a repository invariant across two
# directory trees, not any single class.
RSpec.describe 'Bundled theme helpers' do
  gem_root = CamaleonCms::Engine.root.join('app/apps/themes')
  dummy_root = Rails.root.join('app/apps/themes')

  helpers = Dir.glob(gem_root.join('*', '*.rb')).map { |path| Pathname.new(path).relative_path_from(gem_root).to_s }

  it 'finds the bundled helpers to compare' do
    expect(helpers).not_to be_empty
  end

  helpers.each do |relative|
    it "keeps #{relative} identical between the gem and the dummy app" do
      dummy_copy = dummy_root.join(relative)

      expect(dummy_copy).to exist, "#{relative} exists in the gem but not in spec/dummy"
      expect(dummy_copy.read).to eq(gem_root.join(relative).read),
                                 "#{relative} has drifted; edit both copies or the suite tests the stale one"
    end
  end
end

# rubocop:enable RSpec/DescribeClass
