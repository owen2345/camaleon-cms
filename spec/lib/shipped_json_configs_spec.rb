# frozen_string_literal: true

# The JSON configs the gem ships, generates and tests with stay plain JSON, with no comments and no
# repeated keys, so every JSON parser reads them the same way. The config loaders still accept both in
# the files hosts and third-party gems provide.
RSpec.describe CamaleonCms::Engine do
  describe 'shipped JSON configs' do
    root = File.expand_path('../..', __dir__)
    configs = Dir.glob(%w[config/system.json app/apps/**/config/config.json lib/generators/**/*.json
                          spec/dummy/app/apps/**/config/config.json], base: root).sort

    it 'covers the system configs and the generator templates' do
      expect(configs).to include('config/system.json', 'lib/generators/camaleon_cms/install_template/system.json',
                                 'lib/generators/camaleon_cms/theme_template/config/config.json')
    end

    configs.each do |config|
      it "parses #{config} with comments and repeated keys rejected" do
        source = File.read(File.join(root, config))

        expect { JSON.parse(source, allow_comments: false, allow_duplicate_key: false) }.not_to raise_error
      end
    end
  end
end
