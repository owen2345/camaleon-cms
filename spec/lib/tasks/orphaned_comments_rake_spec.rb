# frozen_string_literal: true
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

    # A guest comment has always had a null user_id and carries an author string instead, so it
    # is indistinguishable from a regression orphan by user_id alone. It is not this task's to
    # rewrite: the rows the regression produced belonged to registered users, which never carry
    # an author string.
    it 'leaves a guest comment untouched' do
      guest = post_record.comments.create!(content: 'from a visitor', approved: 'approved',
                                           author: 'A Visitor', author_email: 'visitor@example.com')

      task.invoke

      expect(guest.reload.user_id).to be_nil
      expect(guest.author).to eq('A Visitor')
    end

    it 'repairs a comment whose user_id points at a user that no longer exists' do
      dangling = post_record.comments.create!(user_id: author.id, content: 'dangling', approved: 'approved')
      dangling.update_column(:user_id, CamaleonCms::User.maximum(:id).to_i + 1000) # rubocop:disable Rails/SkipsModelValidations

      task.invoke

      expect(dangling.reload.user_id).to eq(site.get_anonymous_user.id)
    end

    it 'reports what it did on stdout, where the operator running it can see it' do
      expect { task.invoke }.to output(/reassigned \d+ comment\(s\)/).to_stdout
    end
  end
end
