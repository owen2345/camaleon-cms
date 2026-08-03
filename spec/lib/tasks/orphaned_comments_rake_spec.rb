# frozen_string_literal: true

require 'rails_helper'
require 'rake'

RSpec.describe 'orphaned_comments Rake task', type: :task do
  before(:all) do # rubocop:disable RSpec/BeforeAfterAll
    Rails.application.load_tasks
  end

  after(:all) do # rubocop:disable RSpec/BeforeAfterAll
    Rake::Task['camaleon_cms:reassign_orphaned_comments'].clear
  end

  describe 'camaleon_cms:reassign_orphaned_comments' do
    let(:task) { Rake::Task['camaleon_cms:reassign_orphaned_comments'] }
    let(:site) { CamaleonCms::Site.first }
    let(:post_type) { site.post_types.find_by(slug: 'post') }
    let(:author) { create(:user) }
    let(:post_record) do
      post_type.add_post(title: 'Orphan fixture', slug: 'orphan-fixture-post', content: 'body',
                         user_id: author.id)
    end

    before { task.reenable }

    it 'reassigns comments with a missing user to the anonymous user' do
      orphan = post_record.comments.create!(user_id: author.id, content: 'orphaned', approved: 'approved')
      orphan.update_column(:user_id, nil) # rubocop:disable Rails/SkipsModelValidations

      task.invoke

      expect(orphan.reload.user_id).to eq(site.get_anonymous_user.id)
    end

    it 'leaves comments with an existing user untouched' do
      kept = post_record.comments.create!(user_id: author.id, content: 'kept', approved: 'approved')

      task.invoke

      expect(kept.reload.user_id).to eq(author.id)
    end
  end
end
