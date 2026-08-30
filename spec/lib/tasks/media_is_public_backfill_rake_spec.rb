# frozen_string_literal: true

require 'rake'

RSpec.describe 'media_is_public_backfill Rake task', type: :task do
  init_site

  before(:all) do # rubocop:disable RSpec/BeforeAfterAll
    # Another rake spec's load_tasks may already have registered this task; clear it first so this
    # file's load registers its action exactly once (invoking twice would double the flip).
    task_name = 'camaleon_cms:backfill_media_is_public'
    Rake::Task[task_name].clear if Rake::Task.task_defined?(task_name)
    Rails.application.load_tasks
  end

  after(:all) do # rubocop:disable RSpec/BeforeAfterAll
    Rake::Task['camaleon_cms:backfill_media_is_public'].clear
  end

  describe 'camaleon_cms:backfill_media_is_public' do
    let(:task) { Rake::Task['camaleon_cms:backfill_media_is_public'] }
    let(:site) { Cama::Site.first }
    let!(:public_row) { site.public_media.create!(name: 'logo.png', folder_path: '/', is_folder: false) }
    let!(:private_row) { site.private_media.create!(name: 'secret.pdf', folder_path: '/', is_folder: false) }
    let!(:null_row) do
      row = site.public_media.create!(name: 'legacy.txt', folder_path: '/', is_folder: false)
      row.update_columns(is_public: nil) # rubocop:disable Rails/SkipsModelValidations -- simulate pre-validation data
      row
    end

    before do
      # Deterministic count: start from only the three rows this example seeds.
      CamaleonCms::Media.where.not(id: [public_row.id, private_row.id, null_row.id]).delete_all
      task.reenable
    end

    it 'inverts is_public on every non-NULL media row' do
      expect { task.invoke }.to output(/inverted is_public on 2 media row/).to_stdout

      expect(public_row.reload.is_public).to be false
      expect(private_row.reload.is_public).to be true
    end

    it 'leaves a NULL is_public row untouched' do
      task.invoke

      expect(null_row.reload.is_public).to be_nil
    end

    it 'is a no-op on a second run (does not re-invert)' do
      task.invoke
      task.reenable

      expect { task.invoke }.to output(/already completed/).to_stdout

      # Still the once-flipped values, not flipped back to their originals.
      expect(public_row.reload.is_public).to be false
      expect(private_row.reload.is_public).to be true
    end
  end
end
