# frozen_string_literal: true

require 'rake'

RSpec.describe 'media_visibility_repair Rake task', type: :task do
  before(:all) do # rubocop:disable RSpec/BeforeAfterAll
    # Another rake spec's load_tasks may already have registered this task; clear it first so this
    # file's load registers its action exactly once (invoking twice would double the sweep).
    task_name = 'camaleon_cms:repair_media_visibility'
    Rake::Task[task_name].clear if Rake::Task.task_defined?(task_name)
    Rails.application.load_tasks
  end

  after(:all) do # rubocop:disable RSpec/BeforeAfterAll
    Rake::Task['camaleon_cms:repair_media_visibility'].clear
  end

  describe 'camaleon_cms:repair_media_visibility' do
    let(:task) { Rake::Task['camaleon_cms:repair_media_visibility'] }
    let(:site) { CamaleonCms::Site.first }
    let(:media_root) { site.upload_directory }

    before do
      task.reenable
      FileUtils.mkdir_p(File.join(media_root, 'docs'))
      File.write(File.join(media_root, 'logo.txt'), 'x')
      File.write(File.join(media_root, 'docs', 'b.txt'), 'y')
    end

    after { FileUtils.rm_rf(media_root) }

    it 'purges wrongly-flagged and phantom cache rows and rebuilds flags from storage' do
      # A public file cached under the pre-fix inverted mapping (stored is_public: false)...
      site.private_media.create!(name: 'logo.txt', folder_path: '/', is_folder: false)
      # ...and a phantom row for a file that no longer exists in storage.
      site.public_media.create!(name: 'phantom.txt', folder_path: '/', is_folder: false)

      expect { task.invoke }.to output(/purged 2 cached media row/).to_stdout

      expect(site.public_media.where(name: 'logo.txt', folder_path: '/')).to exist
      expect(site.public_media.where(name: 'b.txt', folder_path: '/docs')).to exist
      expect(site.private_media.count).to eq(0)
      expect(CamaleonCms::Media.where(name: 'phantom.txt')).not_to exist
    end

    it 'is convergent: a repeat run reproduces the same correct state with no duplicates' do
      task.invoke
      first_state = CamaleonCms::Media.order(:name).pluck(:name, :folder_path, :is_public)

      task.reenable
      expect { task.invoke }.not_to raise_error

      expect(CamaleonCms::Media.order(:name).pluck(:name, :folder_path, :is_public)).to eq(first_state)
      expect(site.public_media.where(name: 'logo.txt').count).to eq(1)
    end

    it 'purges a cloud-storage site without touching its bucket (cache rebuilds on browse)' do
      site.set_option('filesystem_type', 'aws')
      site.public_media.create!(name: 'stale.txt', folder_path: '/', is_folder: false)

      expect { task.invoke }.to output(/1 cloud-storage site/).to_stdout

      expect(CamaleonCms::Media.count).to eq(0)
    end
  end
end
