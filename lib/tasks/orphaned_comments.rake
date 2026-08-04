# frozen_string_literal: true

namespace :camaleon_cms do
  desc 'Reassign comments whose user no longer exists to the owning site\'s anonymous user'
  task reassign_orphaned_comments: :environment do
    user_table = CamaManager.get_user_class_name.constantize.table_name
    comment_table = CamaleonCms::PostComment.table_name

    # `user_id IS NULL` on its own does not mean "orphaned": guest comments are a first-class
    # shape — user_id is nullable and the row carries author/author_email/author_url instead —
    # and they have always had a null user_id. The regression nulled the user_id of *registered*
    # users' comments, and those never carry an author string, which is exactly why
    # PostCommentDecorator#the_author_name falls back to the user's name. Requiring a blank
    # author therefore separates the rows this task exists to repair from the ones it must not
    # touch. Rows with a dangling (non-null, non-existent) user_id are repaired regardless.
    orphans = CamaleonCms::PostComment
              .where("(#{comment_table}.user_id IS NULL AND " \
                     "(#{comment_table}.author IS NULL OR #{comment_table}.author = '')) " \
                     "OR (#{comment_table}.user_id IS NOT NULL AND #{comment_table}.user_id NOT IN " \
                     "(SELECT id FROM #{user_table}))")
    reassigned = 0
    skipped = 0

    orphans.find_each do |comment|
      site = comment.post&.post_type&.site
      if site.nil?
        skipped += 1
        next
      end

      comment.update_column(:user_id, site.get_anonymous_user.id) # rubocop:disable Rails/SkipsModelValidations
      reassigned += 1
    end

    summary = "camaleon_cms:reassign_orphaned_comments reassigned #{reassigned} comment(s)" \
              "#{skipped > 0 ? ", skipped #{skipped} without a resolvable site" : ''}"
    Rails.logger.info(summary)
    # An operator runs this from a terminal, where Rails.logger writes to a file they are not
    # watching. Without this the task looks like it did nothing.
    puts summary
  end
end
