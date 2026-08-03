# frozen_string_literal: true

namespace :camaleon_cms do
  desc 'Reassign comments whose user no longer exists to the owning site\'s anonymous user'
  task reassign_orphaned_comments: :environment do
    user_table = CamaManager.get_user_class_name.constantize.table_name
    comment_table = CamaleonCms::PostComment.table_name

    orphans = CamaleonCms::PostComment
              .where("#{comment_table}.user_id IS NULL OR #{comment_table}.user_id NOT IN " \
                     "(SELECT id FROM #{user_table})")
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

    Rails.logger.info(
      "camaleon_cms:reassign_orphaned_comments reassigned #{reassigned} comment(s)" \
      "#{skipped > 0 ? ", skipped #{skipped} without a resolvable site" : ''}"
    )
  end
end
